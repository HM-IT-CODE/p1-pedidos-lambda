// ═══ Lambda "procesar-pedido" (paso 5) ═══════════════════════════════════════
// Nadie la llama por HTTP. AWS la despierta SOLO cuando llegan mensajes a la cola
// p1-pedidos-nuevos (un "event source mapping"). Es la comunicación ASÍNCRONA:
// crear-pedido responde rápido al cliente y el trabajo pesado se hace aquí, después.
//
//   crear-pedido ──SendMessage──▶ SQS ──(AWS hace polling y agrupa)──▶ procesar-pedido
//
// AWS entrega los mensajes en LOTES (event.Records). Si uno falla, se reporta SOLO ese
// en batchItemFailures: los demás se dan por buenos y se borran de la cola.
// El que falló vuelve a la cola, y a la 3.ª vez se va a la DLQ (lo viste a mano en el paso 2.13).
import type { SQSEvent, SQSBatchResponse } from 'aws-lambda';
import { GetCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { ConditionalCheckFailedException } from '@aws-sdk/client-dynamodb';
import { dynamo, env } from './aws';

const TABLA = env('TABLA_PEDIDOS');

export const handler = async (event: SQSEvent): Promise<SQSBatchResponse> => {
  console.log(`lote de ${event.Records.length} mensaje(s)`);
  const fallidos: { itemIdentifier: string }[] = [];

  for (const record of event.Records) {
    try {
      const { pedidoId } = JSON.parse(record.body) as { pedidoId: string };
      const intento = record.attributes.ApproximateReceiveCount;

      const { Item: pedido } = await dynamo.send(new GetCommand({ TableName: TABLA, Key: { id: pedidoId } }));
      if (!pedido) {
        console.warn(`pedido ${pedidoId} no existe; se descarta el mensaje`);
        continue;
      }

      // Falla simulada para ver reintentos y DLQ: un pedido con sku "FALLA" nunca se procesa.
      if (pedido.sku === 'FALLA') {
        throw new Error(`fallo simulado procesando ${pedidoId} (intento ${intento})`);
      }

      // Idempotencia: SQS garantiza "al menos una vez", así que el MISMO mensaje puede llegar
      // dos veces. La condición hace que la segunda vez no cambie nada.
      await dynamo.send(new UpdateCommand({
        TableName: TABLA,
        Key: { id: pedidoId },
        UpdateExpression: 'SET estado = :nuevo, procesado = :ahora',
        ConditionExpression: 'estado = :pendiente',
        ExpressionAttributeValues: { ':nuevo': 'PROCESADO', ':pendiente': 'PENDIENTE', ':ahora': new Date().toISOString() },
      }));
      console.log(`pedido ${pedidoId} → PROCESADO (${pedido.sku} x${pedido.qty}, intento ${intento})`);
    } catch (e) {
      if (e instanceof ConditionalCheckFailedException) {
        console.log(`mensaje repetido: el pedido ya estaba procesado, no se toca`);
        continue;
      }
      console.error(`error con el mensaje ${record.messageId}: ${(e as Error).message}`);
      fallidos.push({ itemIdentifier: record.messageId });
    }
  }
  return { batchItemFailures: fallidos };
};
