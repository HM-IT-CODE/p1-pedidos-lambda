// ═══ Pruebas unitarias de procesar-pedido ════════════════════════════════════
// Esta Lambda recibe LOTES de SQS. Lo que más importa probar:
//   - que un mensaje malo NO tumbe a los buenos del mismo lote (batchItemFailures)
//   - que un mensaje repetido no cause daño (idempotencia)
import { mockClient } from 'aws-sdk-client-mock';
import { DynamoDBDocumentClient, GetCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { ConditionalCheckFailedException } from '@aws-sdk/client-dynamodb';
import { handler } from '../../src/procesar-pedido';
import { loteSqs, mensajeSqs } from '../ayudas/eventos';

const dynamoFalso = mockClient(DynamoDBDocumentClient);

/** "En la tabla hay estos pedidos": el GetCommand devuelve el que coincida por id. */
function tablaCon(pedidos: Record<string, { sku: string; qty: number; estado?: string }>) {
  dynamoFalso.on(GetCommand).callsFake((input: { Key: { id: string } }) => {
    const p = pedidos[input.Key.id];
    return { Item: p ? { id: input.Key.id, estado: 'PENDIENTE', ...p } : undefined };
  });
}

const msg = (id: string, pedidoId: string, intento = 1) => mensajeSqs(id, JSON.stringify({ pedidoId }), intento);

beforeEach(() => {
  dynamoFalso.reset();
  dynamoFalso.on(UpdateCommand).resolves({});
  for (const m of ['log', 'warn', 'error'] as const) jest.spyOn(console, m).mockImplementation(() => {});
});

afterEach(() => jest.restoreAllMocks());

test('un pedido PENDIENTE pasa a PROCESADO y el lote sale sin fallos', async () => {
  tablaCon({ p1: { sku: 'CONS-01', qty: 2 } });

  const r = await handler(loteSqs(msg('m1', 'p1')));

  expect(r).toEqual({ batchItemFailures: [] });
  const [llamada] = dynamoFalso.commandCalls(UpdateCommand);
  const entrada = llamada.args[0].input;
  expect(entrada.Key).toEqual({ id: 'p1' });
  expect(entrada.ExpressionAttributeValues).toMatchObject({ ':nuevo': 'PROCESADO', ':pendiente': 'PENDIENTE' });
  // La condición es la que da la idempotencia: solo se cambia si sigue PENDIENTE
  expect(entrada.ConditionExpression).toBe('estado = :pendiente');
});

test('lote mixto: solo el que falla va en batchItemFailures, los buenos se procesan', async () => {
  tablaCon({ p1: { sku: 'A', qty: 1 }, p2: { sku: 'FALLA', qty: 1 }, p3: { sku: 'B', qty: 3 } });

  const r = await handler(loteSqs(msg('m1', 'p1'), msg('m2', 'p2'), msg('m3', 'p3')));

  // SQS borrará m1 y m3; m2 vuelve a la cola (y a la 3.ª vez, a la DLQ)
  expect(r.batchItemFailures).toEqual([{ itemIdentifier: 'm2' }]);
  const actualizados = dynamoFalso.commandCalls(UpdateCommand).map((c) => c.args[0].input.Key!.id);
  expect(actualizados).toEqual(['p1', 'p3']);
});

test('mensaje repetido (el pedido ya estaba PROCESADO) NO cuenta como fallo', async () => {
  tablaCon({ p1: { sku: 'A', qty: 1, estado: 'PROCESADO' } });
  // DynamoDB rechaza el Update porque la condición estado = PENDIENTE ya no se cumple
  dynamoFalso.on(UpdateCommand).rejects(
    new ConditionalCheckFailedException({ message: 'The conditional request failed', $metadata: {} }),
  );

  const r = await handler(loteSqs(msg('m1', 'p1', 2)));

  // Si lo reportáramos como fallo, SQS lo reintentaría para siempre → terminaría en la DLQ sin razón
  expect(r.batchItemFailures).toEqual([]);
});

test('pedido que no existe en la tabla: se descarta, no se reintenta', async () => {
  tablaCon({});

  const r = await handler(loteSqs(msg('m1', 'no-existe')));

  expect(r.batchItemFailures).toEqual([]);
  expect(dynamoFalso.commandCalls(UpdateCommand)).toHaveLength(0);
});

test('body que no es JSON: va a batchItemFailures', async () => {
  const r = await handler(loteSqs(mensajeSqs('m1', 'basura{')));
  expect(r.batchItemFailures).toEqual([{ itemIdentifier: 'm1' }]);
});

test('si DynamoDB se cae, el mensaje se reporta como fallido para reintentarlo', async () => {
  dynamoFalso.on(GetCommand).rejects(new Error('timeout'));

  const r = await handler(loteSqs(msg('m1', 'p1'), msg('m2', 'p2')));

  expect(r.batchItemFailures).toEqual([{ itemIdentifier: 'm1' }, { itemIdentifier: 'm2' }]);
});

test('lote vacío: no hace nada', async () => {
  const r = await handler(loteSqs());
  expect(r).toEqual({ batchItemFailures: [] });
  expect(dynamoFalso.calls()).toHaveLength(0);
});
