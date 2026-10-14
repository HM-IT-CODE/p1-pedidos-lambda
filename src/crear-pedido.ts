// ═══ Lambda "crear-pedido" ═══════════════════════════════════════════════════
// Una Lambda es SOLO una función exportada: AWS la llama con un `event` (lo que pasó)
// y lo que devuelve es la respuesta. No hay servidor, ni app.listen(), ni puerto.
//
// Este handler lo va a invocar API Gateway con un POST /pedidos (paso 4).
// Hoy (paso 3) lo llamamos nosotros a mano desde probar-local.ts.
import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { PutCommand } from '@aws-sdk/lib-dynamodb';
import { SendMessageCommand } from '@aws-sdk/client-sqs';
import { randomUUID } from 'node:crypto';
import { dynamo, sqs, env } from './aws';

const TABLA = env('TABLA_PEDIDOS');
const COLA_URL = env('COLA_URL');

interface PedidoEntrada { sku: string; qty: number }

/** Respuesta HTTP en el formato que API Gateway entiende. */
const responder = (statusCode: number, cuerpo: unknown): APIGatewayProxyResultV2 => ({
  statusCode,
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(cuerpo),
});

export const handler = async (event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> => {
  // 1) Leer y validar el body. API Gateway lo entrega como TEXTO, hay que parsearlo.
  let entrada: PedidoEntrada;
  try {
    entrada = JSON.parse(event.body ?? '{}');
  } catch {
    return responder(400, { error: 'El body no es JSON válido' });
  }
  if (!entrada.sku || !Number.isInteger(entrada.qty) || entrada.qty < 1) {
    return responder(400, { error: 'Se requiere sku (texto) y qty (entero >= 1)' });
  }

  const pedido = {
    id: randomUUID(),
    sku: entrada.sku,
    qty: entrada.qty,
    estado: 'PENDIENTE',
    creado: new Date().toISOString(),
  };

  // 2) Guardar en DynamoDB. Es el mismo put-item del paso 2.11, pero desde código.
  //    ConditionExpression = "solo si ese id NO existe" (evita pisar un pedido por error).
  await dynamo.send(new PutCommand({
    TableName: TABLA,
    Item: pedido,
    ConditionExpression: 'attribute_not_exists(id)',
  }));

  // 3) Avisar por la cola que hay un pedido nuevo. Es el send-message del paso 2.12.
  //    Quien procese el pedido (paso 5) no necesita saber que existimos: solo lee la cola.
  await sqs.send(new SendMessageCommand({
    QueueUrl: COLA_URL,
    MessageBody: JSON.stringify({ pedidoId: pedido.id }),
  }));

  console.log(`pedido creado ${pedido.id} (${pedido.sku} x${pedido.qty})`); // en AWS esto va a CloudWatch Logs
  return responder(201, pedido);
};
