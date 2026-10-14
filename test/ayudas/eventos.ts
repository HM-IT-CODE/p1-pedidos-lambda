// Fábricas de "events" falsos: la forma de lo que AWS le pasa a cada Lambda.
// Solo llenamos los campos que nuestros handlers usan; el resto es relleno.
import type { APIGatewayProxyEventV2, SQSEvent, SQSRecord } from 'aws-lambda';

/** Lo que manda API Gateway al handler de crear-pedido. */
export const eventoHttp = (body: string | undefined): APIGatewayProxyEventV2 =>
  ({ body, requestContext: { http: { method: 'POST', path: '/pedidos' } } }) as unknown as APIGatewayProxyEventV2;

/** Un mensaje de SQS dentro de un lote. `intento` = cuántas veces se ha entregado. */
export const mensajeSqs = (messageId: string, body: string, intento = 1): SQSRecord => ({
  messageId,
  receiptHandle: `rh-${messageId}`,
  body,
  attributes: {
    ApproximateReceiveCount: String(intento),
    SentTimestamp: '0',
    SenderId: 'prueba',
    ApproximateFirstReceiveTimestamp: '0',
  },
  messageAttributes: {},
  md5OfBody: '',
  eventSource: 'aws:sqs',
  eventSourceARN: 'arn:aws:sqs:us-east-1:000000000000:p1-pedidos-nuevos',
  awsRegion: 'us-east-1',
});

/** Un lote de mensajes, como lo entrega el event source mapping. */
export const loteSqs = (...records: SQSRecord[]): SQSEvent => ({ Records: records });
