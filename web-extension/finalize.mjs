import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// The Angular application builder emits multiple files (main.js + lazy/shared chunks)
// into dist/browser. Yamcs serves every .js/.css in an extension's static root and
// injects each into index.html, so we copy them all and write a manifest the plugin
// uses to know which files to extract from the jar.

const SRC = 'dist/browser';
const OUT = 'dist/bundle';

if (!existsSync(SRC)) {
  console.error(`finalize: ${SRC} not found (did 'ng build' run?)`);
  process.exit(1);
}

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });

const assets = readdirSync(SRC).filter((f) => f.endsWith('.js') || f.endsWith('.css'));
if (!assets.some((f) => f.endsWith('.js'))) {
  console.error('finalize: no .js output found');
  process.exit(1);
}

for (const file of assets) {
  cpSync(join(SRC, file), join(OUT, file));
}
writeFileSync(join(OUT, 'manifest.txt'), assets.join('\n') + '\n');

console.log(`finalize: bundled ${assets.length} file(s) -> ${OUT}`);
console.log(assets.map((f) => '  ' + f).join('\n'));
