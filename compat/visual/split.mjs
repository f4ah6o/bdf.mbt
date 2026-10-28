import { mount_bdf_split_async } from '/_build/js/debug/build/browser/browser.js';

try {
  const base = './split-fixture/';
  const manifestBytes = new Uint8Array(await (await fetch(`${base}manifest.json`)).arrayBuffer());
  const manifest = JSON.parse(new TextDecoder().decode(manifestBytes));
  const requests = [];
  const loader = async (hash, maximum) => {
    if (requests.includes(hash)) throw new Error('part requested twice');
    requests.push(hash);
    const part = manifest.parts.find(part => part.h === hash);
    if (!part || maximum !== part.len) throw new Error('incorrect loader limit');
    const response = await fetch(`${base}parts/${hash}`);
    if (!response.ok) throw new Error('part request failed');
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.length > maximum) throw new Error('part exceeds limit');
    return bytes;
  };
  await mount_bdf_split_async(document.querySelector('#host'), manifestBytes, loader, 'single');
  const unused = manifest.parts.find(part => part.len === 25 && part.t === 'img');
  if (!unused || requests.includes(unused.h) || requests.length !== manifest.parts.length - 1) {
    throw new Error('split loader did not fetch exactly the referenced parts');
  }
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error';
  window.bdfError = String(error?.stack ?? error);
  console.error(error);
}
