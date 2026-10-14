// Ayudas para las pruebas de INTEGRACIÓN: hablan con lo que está desplegado de verdad.
import { execFileSync } from 'node:child_process';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';
import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from '@aws-sdk/client-sqs';
import { join } from 'node:path';

/**
 * Las URLs y nombres NO se escriben a mano: se le preguntan a tofu (`tofu output -json`).
 * Así la misma prueba sirve para LocalStack, para el CI y (paso 8) para AWS real.
 */
export interface Salidas { url_pedidos: string; tabla_pedidos: string; cola_url: string; dlq_url: string }

export function leerSalidas(): Salidas {
  const json = execFileSync(process.env.TOFU_BIN ?? 'tofu', ['-chdir=' + join(__dirname, '../../infra'), 'output', '-json'], {
    encoding: 'utf8',
  });
  const crudo = JSON.parse(json) as Record<string, { value: string }>;
  const s = Object.fromEntries(Object.entries(crudo).map(([k, v]) => [k, v.value])) as unknown as Salidas;
  if (!s.url_pedidos) throw new Error('tofu no tiene outputs: ¿hiciste `tofu -chdir=infra apply`?');
  return s;
}

// En LocalStack: endpoint + claves "test". En AWS real (paso 8) se deja AWS_ENDPOINT_URL vacío.
const config = {
  region: process.env.AWS_REGION ?? process.env.AWS_DEFAULT_REGION ?? 'us-east-1',
  ...(process.env.AWS_ENDPOINT_URL ? { endpoint: process.env.AWS_ENDPOINT_URL } : {}),
};
export const dynamo = DynamoDBDocumentClient.from(new DynamoDBClient(config));
export const sqs = new SQSClient(config);

export const dormir = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * Pregunta cada `cada` ms hasta que `fn` devuelva algo distinto de undefined.
 * Es la forma de probar cosas ASÍNCRONAS: no sabemos cuándo la Lambda procesará el
 * mensaje, solo que debería pasar "pronto". Si no pasa en `limite` ms, la prueba falla.
 */
export async function esperarHasta<T>(fn: () => Promise<T | undefined>, limite: number, cada = 1000): Promise<T> {
  const fin = Date.now() + limite;
  while (Date.now() < fin) {
    const v = await fn();
    if (v !== undefined) return v;
    await dormir(cada);
  }
  throw new Error(`no se cumplió en ${limite / 1000} s`);
}

export async function leerPedido(tabla: string, id: string) {
  const { Item } = await dynamo.send(new GetCommand({ TableName: tabla, Key: { id }, ConsistentRead: true }));
  return Item;
}

/** POST /pedidos a la API desplegada. */
export async function crearPedido(url: string, body: unknown) {
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
  const texto = await r.text();
  let json: any;
  try { json = JSON.parse(texto); } catch { json = texto; }
  return { status: r.status, json };
}

/** Busca en una cola (la DLQ) un mensaje de cierto pedido; si lo encuentra lo borra y lo devuelve. */
export async function sacarDeCola(colaUrl: string, pedidoId: string) {
  const { Messages = [] } = await sqs.send(new ReceiveMessageCommand({
    QueueUrl: colaUrl, MaxNumberOfMessages: 10, WaitTimeSeconds: 1, VisibilityTimeout: 2,
  }));
  for (const m of Messages) {
    if (JSON.parse(m.Body ?? '{}').pedidoId === pedidoId) {
      await sqs.send(new DeleteMessageCommand({ QueueUrl: colaUrl, ReceiptHandle: m.ReceiptHandle! }));
      return m;
    }
  }
  return undefined;
}
