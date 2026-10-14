// Llama al handler como lo haría API Gateway, pero desde Node en tu terminal.
// Así se desarrolla una Lambda: el handler es una función normal, se prueba como tal,
// y solo al final se despliega al servicio Lambda.
//
//   npm run probar:crear
import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { handler } from './crear-pedido';

// Un "event" de mentira con la forma del que manda API Gateway (solo los campos que usamos).
const evento = (body: string) => ({ body, requestContext: { http: { method: 'POST', path: '/pedidos' } } }) as unknown as APIGatewayProxyEventV2;

console.log('--- 1) pedido válido');
console.log(await handler(evento(JSON.stringify({ sku: 'CONS-01', qty: 2 }))));

console.log('--- 2) qty inválida');
console.log(await handler(evento(JSON.stringify({ sku: 'CONS-01', qty: 0 }))));

console.log('--- 3) body roto');
console.log(await handler(evento('esto no es json')));
