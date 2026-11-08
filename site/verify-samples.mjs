// Expected SHA-256 of the upstream sample files used by the site.
//
//   node site/verify-samples.mjs
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
  'chrome-doc.pdf': '8e538a95dc830054c968a1a059e8f4764c348888dbb8d3e5ce2a5955035dd86c',
  'chrome-masks.pdf': 'a9bd53b97fc465704465408a3b65d91420de826f37f016bd7c5514e9ddb16425',
  'chrome-slides.pdf': '15a6f265311cd66599d8696b6edaae0a00352bed0f606e7a6b970c7cc5803719',
  'cjk-cmaps.pdf': '9e293b63d9fdc83bc2d73c93b48e1f1fa104093a3adb604bd83d851298852ac5',
  'weasyprint-webfonts.pdf': '74be05c8eebc333b9f0704d6da21780b729ce488b050ca3ee9cdd2fbaf4b4ed5',
  'reportlab-master.pdf': 'dc7ae25da14ee13bbeada8c0b81bef2591778c945efa00a0fc9fd40fd5834869',
  'reportlab-mixed.pdf': '2634b25f58e77866be1843f96b4e317428e3ba346f305a256f5a714b03c9358f',
  'reportlab-type1.pdf': '69f8fa4f6e935300eb5ada89333740f02041aaf95929bcd44947ebb27c8d2f49',
  'features.pptx': 'e813bdd7cf7e896b5c4176dc5dfb53965d06197e66d3e9bfcd142826ef9cdc88',
  'upstream-report.pdf': 'dc7ae25da14ee13bbeada8c0b81bef2591778c945efa00a0fc9fd40fd5834869',
};
const root = resolve(import.meta.dirname, '..');
for (const [name, expected] of Object.entries(samples)) {
  const actual = createHash('sha256').update(await readFile(resolve(root, 'site/samples', name))).digest('hex');
  if (actual !== expected) throw new Error(name + ' does not match the upstream sample');
}
console.log('Demo samples: ' + Object.keys(samples).length + ' upstream files match.');
