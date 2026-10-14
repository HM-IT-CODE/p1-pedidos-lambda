// Clientes de AWS compartidos por todas las Lambdas.
//
// Se crean FUERA del handler a propósito: AWS reutiliza el mismo contenedor de la Lambda
// para muchas invocaciones seguidas ("warm start"). Lo que está aquí arriba se ejecuta
// UNA vez por contenedor; el handler se ejecuta una vez por petición.
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { SQSClient } from '@aws-sdk/client-sqs';

// En AWS real no hay que pasar endpoint: el SDK sabe la URL de cada servicio.
// Con LocalStack, AWS_ENDPOINT_URL=http://localhost:4566 manda todo ahí.
const config = {
  region: process.env.AWS_REGION ?? process.env.AWS_DEFAULT_REGION ?? 'us-east-1',
  ...(process.env.AWS_ENDPOINT_URL ? { endpoint: process.env.AWS_ENDPOINT_URL } : {}),
};

// DocumentClient = traductor: tú le das { qty: 2 } y él lo convierte al formato
// tipado de DynamoDB { qty: { N: "2" } } que escribiste a mano en el paso 2.11.
export const dynamo = DynamoDBDocumentClient.from(new DynamoDBClient(config));
export const sqs = new SQSClient(config);

/** Lee una variable de entorno obligatoria o revienta con un mensaje claro. */
export function env(nombre: string): string {
  const v = process.env[nombre];
  if (!v) throw new Error(`Falta la variable de entorno ${nombre}`);
  return v;
}
