// Paso 3.2 — Empaquetar cada Lambda en UN solo archivo JavaScript con esbuild.
//
// Por qué: en AWS no corre tu carpeta con node_modules. Corre un .zip que tú subes.
// esbuild sigue todos los `import` desde src/crear-pedido.ts (aws.ts, el SDK de AWS...),
// los junta en dist/crear-pedido/index.js, quita lo que no se usa ("tree shaking")
// y lo minifica. Resultado: un archivo de unos cientos de KB en vez de 40 MB de node_modules.
//
//   npm run build
import { build } from 'esbuild';
import { statSync } from 'node:fs';

const funciones = ['crear-pedido', 'procesar-pedido'];

for (const f of funciones) {
  const salida = `dist/${f}/index.js`;
  await build({
    entryPoints: [`src/${f}.ts`],
    bundle: true,        // meter las dependencias adentro
    platform: 'node',
    target: 'node20',    // el runtime nodejs20.x de Lambda
    format: 'cjs',       // CommonJS: Lambda lo carga sin sorpresas (exports.handler)
    minify: true,
    outfile: salida,
  });
  const kb = (statSync(salida).size / 1024).toFixed(0);
  console.log(`✔ ${f.padEnd(16)} → ${salida} (${kb} KB)   handler: index.handler`);
}
