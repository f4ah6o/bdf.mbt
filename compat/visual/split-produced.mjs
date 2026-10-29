import { mount_bdf_split_async, mount_bdf_encrypted_split_async } from '/_build/js/debug/build/browser/browser.js';
import { split_manifest, split_part } from '/_build/js/debug/build/compat/writer/writer.js';

try {
  const encrypted = location.pathname.endsWith('/encrypted-produced.html');
  const input = new Uint8Array(await (await fetch(encrypted ? './encrypted-fixture/password.bdf' : './fixture.bdf')).arrayBuffer());
  const manifestBytes = split_manifest(input);
  const manifest = JSON.parse(new TextDecoder().decode(manifestBytes));
  const stored = new Map(manifest.parts.map((part, index) => [part.h, split_part(input, index)]));
  const loader = async (hash, limit) => {
    const data = stored.get(hash);
    if (!data || data.length > limit) throw new Error('invalid part request');
    return data;
  };
  const host = document.querySelector('#host');
  if (encrypted) await mount_bdf_encrypted_split_async(host, manifestBytes, loader, 'pass', 'single');
  else await mount_bdf_split_async(host, manifestBytes, loader, 'single');
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error';
  window.bdfError = String(error?.stack ?? error);
  console.error(error);
}
