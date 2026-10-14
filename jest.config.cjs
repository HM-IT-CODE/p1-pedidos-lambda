// ═══ Paso 6: configuración de Jest ════════════════════════════════════════════
// Dos "proyectos" de pruebas con reglas distintas:
//
//   unit        → prueban los handlers SOLOS, con AWS de mentira (mocks). Corren en
//                 1-2 segundos, sin LocalStack, sin red. Son las que corres a cada rato.
//   integracion → prueban el sistema DESPLEGADO en LocalStack: HTTP real a API Gateway,
//                 Lambdas reales en mini, DynamoDB y SQS reales. Lentas (segundos/minutos).
//
// Es la "pirámide de pruebas": muchas unitarias baratas abajo, pocas de integración arriba.
//
// El .cjs es porque package.json dice "type": "module"; Jest lee su config en CommonJS.
// @swc/jest traduce TypeScript → JavaScript al vuelo (como tsx, pero para Jest).
const transform = {
  '^.+\\.ts$': ['@swc/jest', {
    jsc: { parser: { syntax: 'typescript' }, target: 'es2022' },
    module: { type: 'commonjs' },
  }],
};

module.exports = {
  projects: [
    {
      displayName: 'unit',
      testEnvironment: 'node',
      transform,
      testMatch: ['<rootDir>/test/unit/**/*.test.ts'],
      // Variables de entorno que los handlers leen al cargarse (env('TABLA_PEDIDOS')...)
      setupFiles: ['<rootDir>/test/unit/entorno.cjs'],
    },
    {
      displayName: 'integracion',
      testEnvironment: 'node',
      transform,
      testMatch: ['<rootDir>/test/integracion/**/*.test.ts'],
    },
  ],
};
