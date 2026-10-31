import { cp, mkdir, rm } from 'node:fs/promises';
import { resolve, join } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const output = join(root, '_build/pages');
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
for (const file of ['index.html', 'converter.html', 'coverage.html', 'formats.html', 'style.css', 'app.js', 'samples', 'licenses', 'previews']) await cp(join(root, 'demo', file), join(output, file), { recursive: true });
for (const [pkg, name] of [['browser', 'browser.js'], ['render_worker', 'render_worker.js'], ['native_converter_worker', 'native_converter_worker.js']]) {
  await cp(join(root, '_build/js/release/build', pkg, name), join(output, name));
}
console.log(`Built ${output}`);
