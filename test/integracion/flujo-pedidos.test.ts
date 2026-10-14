// ═══ Pruebas de INTEGRACIÓN: el sistema completo desplegado ══════════════════
// Aquí no hay mocks. Es lo mismo que hiciste a mano en los pasos 4 y 5 con curl y
// ver-pedidos.sh, pero automático:
//
//   HTTP ──▶ API Gateway ──▶ Lambda crear-pedido ──▶ DynamoDB + SQS
//                                                     └──▶ Lambda procesar-pedido ──▶ DynamoDB
//
// Requisitos: LocalStack arriba (en mini o en el CI), `npm run build` y `tofu apply` hechos.
//   npm run test:integracion            (rápidas, ~1 min con Lambdas frías)
//   PRUEBA_DLQ=1 npm run test:integracion   (+ la de la DLQ, ~2 min más)
import { leerSalidas, crearPedido, esperarHasta, leerPedido, sacarDeCola, Salidas } from '../ayudas/despliegue';

let s: Salidas;
beforeAll(() => { s = leerSalidas(); });

describe('POST /pedidos a través de API Gateway', () => {
  test('pedido válido → 201, queda en DynamoDB y la Lambda de la cola lo PROCESA', async () => {
    const r = await crearPedido(s.url_pedidos, { sku: 'IT-OK', qty: 3 });

    expect(r.status).toBe(201);
    expect(r.json).toMatchObject({ sku: 'IT-OK', qty: 3, estado: 'PENDIENTE' });

    // La parte asíncrona: no sabemos cuándo, pero procesar-pedido debe marcarlo.
    // 90 s de margen: la primera vez mini tiene que arrancar el contenedor de la Lambda.
    const pedido = await esperarHasta(async () => {
      const p = await leerPedido(s.tabla_pedidos, r.json.id);
      return p?.estado === 'PROCESADO' ? p : undefined;
    }, 90_000);

    expect(pedido.procesado).toBeDefined();
    expect(Date.parse(pedido.procesado)).toBeGreaterThanOrEqual(Date.parse(pedido.creado));
  }, 120_000);

  test.each([
    ['qty inválida', { sku: 'IT-MAL', qty: 0 }],
    ['sin sku', { qty: 1 }],
    ['body roto', 'no es json'],
  ])('%s → 400 con mensaje de error', async (_n, body) => {
    const r = await crearPedido(s.url_pedidos, body);
    expect(r.status).toBe(400);
    expect(r.json.error).toBeDefined();
  }, 60_000);

  test('varios pedidos a la vez: todos terminan PROCESADOS (lotes de SQS)', async () => {
    const respuestas = await Promise.all(
      [1, 2, 3, 4, 5].map((n) => crearPedido(s.url_pedidos, { sku: `IT-LOTE-${n}`, qty: n })),
    );
    expect(respuestas.map((r) => r.status)).toEqual([201, 201, 201, 201, 201]);

    for (const r of respuestas) {
      await esperarHasta(async () => {
        const p = await leerPedido(s.tabla_pedidos, r.json.id);
        return p?.estado === 'PROCESADO' ? p : undefined;
      }, 60_000);
    }
  }, 120_000);
});

// La prueba de la DLQ tarda: 3 entregas × 30 s de visibility timeout ≈ 1.5-2 min.
// Por eso solo corre si la pides: PRUEBA_DLQ=1
const conDlq = process.env.PRUEBA_DLQ ? test : test.skip;

conDlq('sku FALLA: 3 intentos y termina en la DLQ, sigue PENDIENTE en la tabla', async () => {
  const r = await crearPedido(s.url_pedidos, { sku: 'FALLA', qty: 1 });
  expect(r.status).toBe(201);

  const m = await esperarHasta(() => sacarDeCola(s.dlq_url, r.json.id), 180_000, 3000);
  expect(JSON.parse(m.Body!)).toEqual({ pedidoId: r.json.id });

  const p = await leerPedido(s.tabla_pedidos, r.json.id);
  expect(p?.estado).toBe('PENDIENTE');
}, 200_000);
