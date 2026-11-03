import { cp, mkdir, rm } from 'node:fs/promises';
import { resolve, join } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const output = join(root, '_build/pages');
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
const files = [
  'index.html', 'converter.html', 'coverage.html', 'formats.html', 'style.css', 'app.js',
  'export-ui.js', 'export-page.js', 'wasm-gc.html', 'wasm-gc.js', 'wasm-gc-page.js',
  'samples', 'licenses', 'previews',
];
for (const file of files) await cp(join(root, 'demo', file), join(output, file), { recursive: true });
for (const [path, name] of [
  [['_build/js/release/build/browser/browser.js'], 'browser.js'],
  [['_build/js/release/build/render_worker/render_worker.js'], 'render_worker.js'],
  [['_build/js/release/build/native_converter_worker/native_converter_worker.js'], 'native_converter_worker.js'],
  [['_build/js/release/build/bridge/wasm/wasm.js'], 'export.js'],
  [['_build/wasm-gc/release/build/bridge/wasm/wasm.wasm'], 'wasm-gc.wasm'],
]) {
  const source = join(root, ...path);
  await cp(source, join(output, name)).catch(error => {
    if (error.code !== 'ENOENT') throw error;
    console.warn('missing ' + source);
  });
}
await cp(join(root, 'node_modules/minisearch/dist/es'), join(output, 'minisearch'), { recursive: true });
console.log(`Built ${output}`);
