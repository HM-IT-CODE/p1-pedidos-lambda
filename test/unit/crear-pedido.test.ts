// ═══ Pruebas unitarias de crear-pedido ═══════════════════════════════════════
// Idea clave: el handler es una FUNCIÓN. Le damos un event, miramos lo que devuelve
// y QUÉ le pidió a AWS. AWS no existe aquí: aws-sdk-client-mock intercepta cada
// `.send(...)` del SDK y responde lo que le digamos.
//
//   npm test                 (todas las unitarias)
//   npx jest crear-pedido    (solo este archivo)
import { mockClient } from 'aws-sdk-client-mock';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';
import { ConditionalCheckFailedException } from '@aws-sdk/client-dynamodb';
import { handler } from '../../src/crear-pedido';
import { eventoHttp } from '../ayudas/eventos';

// mockClient reemplaza el .send() de TODAS las instancias de esa clase,
// incluida la que creó src/aws.ts. Por eso no hay que tocar el código de producción.
const dynamoFalso = mockClient(DynamoDBDocumentClient);
const sqsFalso = mockClient(SQSClient);

/** El handler devuelve el body como texto (así lo exige API Gateway); lo volvemos objeto. */
const cuerpo = (r: unknown) => JSON.parse((r as { body: string }).body);

beforeEach(() => {
  dynamoFalso.reset();
  sqsFalso.reset();
  // Respuestas por defecto: "todo salió bien"
  dynamoFalso.on(PutCommand).resolves({});
  sqsFalso.on(SendMessageCommand).resolves({ MessageId: 'msg-1' });
  // Silenciar los console.log del handler para que la salida de Jest se lea limpia
  jest.spyOn(console, 'log').mockImplementation(() => {});
});

afterEach(() => jest.restoreAllMocks());

describe('crear-pedido: camino feliz', () => {
  test('responde 201 con el pedido en estado PENDIENTE', async () => {
    const r = await handler(eventoHttp(JSON.stringify({ sku: 'CONS-01', qty: 2 })));

    expect(r).toMatchObject({ statusCode: 201 });
    const pedido = cuerpo(r);
    expect(pedido).toMatchObject({ sku: 'CONS-01', qty: 2, estado: 'PENDIENTE' });
    expect(pedido.id).toMatch(/^[0-9a-f-]{36}$/); // un UUID
    expect(Number.isNaN(Date.parse(pedido.creado))).toBe(false);
  });

  test('guarda en DynamoDB con la condición "solo si el id no existe"', async () => {
    await handler(eventoHttp(JSON.stringify({ sku: 'CONS-01', qty: 2 })));

    const llamadas = dynamoFalso.commandCalls(PutCommand);
    expect(llamadas).toHaveLength(1);
    const entrada = llamadas[0].args[0].input;
    expect(entrada.TableName).toBe('tabla-de-prueba');
    expect(entrada.ConditionExpression).toBe('attribute_not_exists(id)');
    expect(entrada.Item).toMatchObject({ sku: 'CONS-01', qty: 2, estado: 'PENDIENTE' });
  });

  test('avisa por la cola con el MISMO id que guardó', async () => {
    const r = await handler(eventoHttp(JSON.stringify({ sku: 'CONS-01', qty: 2 })));

    const llamadas = sqsFalso.commandCalls(SendMessageCommand);
    expect(llamadas).toHaveLength(1);
    const entrada = llamadas[0].args[0].input;
    expect(entrada.QueueUrl).toBe(process.env.COLA_URL);
    expect(JSON.parse(entrada.MessageBody!)).toEqual({ pedidoId: cuerpo(r).id });
  });

  test('cada pedido recibe un id distinto', async () => {
    const a = cuerpo(await handler(eventoHttp(JSON.stringify({ sku: 'A', qty: 1 }))));
    const b = cuerpo(await handler(eventoHttp(JSON.stringify({ sku: 'A', qty: 1 }))));
    expect(a.id).not.toBe(b.id);
  });
});

describe('crear-pedido: validación (400) y sin tocar AWS', () => {
  // test.each = la misma prueba con varios datos. Cada fila sale como una prueba aparte.
  test.each([
    ['body que no es JSON', 'esto no es json', 'El body no es JSON válido'],
    ['body vacío', undefined, 'Se requiere sku'],
    ['sin sku', JSON.stringify({ qty: 2 }), 'Se requiere sku'],
    ['qty = 0', JSON.stringify({ sku: 'X', qty: 0 }), 'Se requiere sku'],
    ['qty negativa', JSON.stringify({ sku: 'X', qty: -3 }), 'Se requiere sku'],
    ['qty con decimales', JSON.stringify({ sku: 'X', qty: 1.5 }), 'Se requiere sku'],
    ['qty como texto', JSON.stringify({ sku: 'X', qty: '2' }), 'Se requiere sku'],
  ])('%s → 400', async (_nombre, body, mensaje) => {
    const r = await handler(eventoHttp(body));

    expect(r).toMatchObject({ statusCode: 400 });
    expect(cuerpo(r).error).toContain(mensaje);
    // Lo importante: un pedido malo NO debe llegar ni a la tabla ni a la cola
    expect(dynamoFalso.commandCalls(PutCommand)).toHaveLength(0);
    expect(sqsFalso.commandCalls(SendMessageCommand)).toHaveLength(0);
  });
});

describe('crear-pedido: cuando AWS falla', () => {
  test('si DynamoDB falla, NO manda el mensaje a la cola', async () => {
    dynamoFalso.on(PutCommand).rejects(new Error('DynamoDB caído'));

    await expect(handler(eventoHttp(JSON.stringify({ sku: 'X', qty: 1 })))).rejects.toThrow('DynamoDB caído');
    expect(sqsFalso.commandCalls(SendMessageCommand)).toHaveLength(0);
  });

  test('si el id ya existía, la condición de DynamoDB lo frena y el error sube', async () => {
    dynamoFalso.on(PutCommand).rejects(
      new ConditionalCheckFailedException({ message: 'The conditional request failed', $metadata: {} }),
    );

    await expect(handler(eventoHttp(JSON.stringify({ sku: 'X', qty: 1 })))).rejects.toThrow('conditional request failed');
    expect(sqsFalso.commandCalls(SendMessageCommand)).toHaveLength(0);
  });

  // HALLAZGO para el repaso: si la cola falla DESPUÉS de guardar, el pedido queda en la
  // tabla como PENDIENTE para siempre (nadie lo procesará). Esta prueba DOCUMENTA el
  // comportamiento actual. Arreglarlo (patrón outbox como en el lab saga-outbox-cqrs,
  // o DynamoDB Streams) es un buen ejercicio.
  test('si SQS falla después de guardar, el pedido ya quedó en la tabla (hueco conocido)', async () => {
    sqsFalso.on(SendMessageCommand).rejects(new Error('SQS caído'));

    await expect(handler(eventoHttp(JSON.stringify({ sku: 'X', qty: 1 })))).rejects.toThrow('SQS caído');
    expect(dynamoFalso.commandCalls(PutCommand)).toHaveLength(1);
  });
});
