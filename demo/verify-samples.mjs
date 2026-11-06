// Expected SHA-256 of the upstream sample files used by the demo.
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const samples = {
  'basic.csv': '1ba65cc6eef6ca7888b432928fc93c953f6eca6e928dfb6ca6ba81fe090e32e8',
  'basic.docx': 'f4830cd362996f3e07b9b370a4f118de8617e98daff42c3d475efeb7b6eef335',
  'basic.md': '6c79a9aec05d29164223e76d719ea3a3ee0ed3444cfd95afd650c2503536b32e',
  'basic.parquet': '6544edd3460eba45c4caac584a4a37bacc69eb2f596181ac32457cb1da77dfb5',
  'basic.pptx': '2c471caddae2b9a32318fa1e87626e060db68f700d54a6b11250690b25dc6e56',
  'basic.xlsx': '75d6011ad3dce051b341d7829e48a399f77eec1c35e5b830f74454bddd5662a1',
  'cairo-cff.pdf': '00330c0783b7fa8f5345e5db4b58c378a6adfb89c5e8b03d2e70b5711dcbe8b5',
  'cairo-type1.pdf': '842143ad35eecb2e6b80e7df53ac7296db8b33a7166b0c18970c90a3a3f28dbb',
  'drawing.svg': '19101970b684987503a220d7bda0abe16aa300c8d8f050ba5a23d70d4987190e',
  'features.xlsx': '73ae09e23849470a47bd24b3623702827007af8ff3d8038a3e3b75dc1ecb8ad5',
  'images-jpx-jbig2.pdf': '5c9df9c1a5cbdd2688e8096ffde40e3fc2dfe1c9d645a58df67a141712d61997',
  'nested.parquet': '3b642efb30ba4c8bd1c3a87d8d096140d2cbc68e4b1cc2efa8afd5407d44c831',
  'upstream-demo.pdf': 'cfc050de090a06bfcc30640e20465c54f890000c59b922ad8ef5902a721654f2',
};
const root = resolve(import.meta.dirname, '..');
for (const [name, expected] of Object.entries(samples)) {
  const actual = createHash('sha256').update(await readFile(resolve(root, 'demo/samples', name))).digest('hex');
  if (actual !== expected) throw new Error(name + ' does not match the upstream sample');
}
console.log('Demo samples: ' + Object.keys(samples).length + ' upstream files match.');
