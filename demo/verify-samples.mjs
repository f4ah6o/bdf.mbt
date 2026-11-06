// Checks that the demo samples are the upstream files, byte for byte.
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const samples = {
  'basic.csv': 'examples/sample-files/basic.csv',
  'basic.docx': 'examples/sample-files/basic.docx',
  'basic.md': 'examples/sample-files/basic.md',
  'basic.parquet': 'converter/parquet/testdata/basic.parquet',
  'basic.pptx': 'examples/sample-files/basic.pptx',
  'basic.xlsx': 'examples/sample-files/basic.xlsx',
  'cairo-cff.pdf': 'converter/pdf/testdata/cairo-cff.pdf',
  'cairo-type1.pdf': 'converter/pdf/testdata/cairo-type1.pdf',
  'drawing.svg': 'image/svg/testdata/drawing.svg',
  'features.xlsx': 'converter/xlsx/testdata/features.xlsx',
  'images-jpx-jbig2.pdf': 'converter/pdf/testdata/images-jpx-jbig2.pdf',
  'nested.parquet': 'converter/parquet/testdata/nested.parquet',
  'upstream-demo.pdf': 'site/demo/demo.pdf',
};
const hash = data => createHash('sha256').update(data).digest('hex');
for (const [name, upstream] of Object.entries(samples)) {
  const actual = hash(await readFile(resolve(root, 'demo/samples', name)));
  const expected = hash(await readFile(resolve(root, '.upstream', upstream)));
  if (actual !== expected) throw new Error(name + ' differs from upstream ' + upstream);
}
console.log('Demo samples: ' + Object.keys(samples).length + ' upstream files match.');
