import { build } from 'esbuild';

// Bundle the custom element into a single ES module that yamcs-web loads via
// <script type="module">. Nothing from the Yamcs SDK is imported at runtime
// (the SDK is used for types only), so the output is tiny and has no Angular
// version coupling.
await build({
  entryPoints: ['src/external-webpage.ts'],
  bundle: true,
  format: 'esm',
  target: 'es2022',
  outfile: 'dist/external-webpage.js',
  legalComments: 'none',
  minify: true,
  sourcemap: false,
});

console.log('Built dist/external-webpage.js');
