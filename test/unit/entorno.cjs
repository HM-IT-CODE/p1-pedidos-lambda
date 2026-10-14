// Se ejecuta ANTES de cada archivo de pruebas unitarias.
// Los handlers hacen env('TABLA_PEDIDOS') al importarse: si no existe, revientan.
// Aquí ponemos valores falsos; los mocks nunca hablan con AWS de verdad.
process.env.TABLA_PEDIDOS = 'tabla-de-prueba';
process.env.COLA_URL = 'http://cola-de-prueba/000000000000/p1-pedidos-nuevos';
process.env.AWS_REGION = 'us-east-1';
process.env.AWS_ACCESS_KEY_ID = 'test';
process.env.AWS_SECRET_ACCESS_KEY = 'test';
