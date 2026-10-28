import { mount_bdf_encrypted_async, mount_bdf_encrypted_split_async } from '/_build/js/debug/build/browser/browser.js';

try {
  const mode = location.pathname.split('/').pop().replace('.html', '');
  const dir = './encrypted-fixture/';
  const bytes = async file => new Uint8Array(await (await fetch(`${dir}${file}`)).arrayBuffer());
  const host = document.querySelector('#host');
  if (mode === 'encrypted-split') {
    const manifest = await bytes('password-split/manifest.json');
    const loader = async (hash, limit) => {
      const part = await bytes(`password-split/parts/${hash}`);
      if (part.length > limit) throw new Error('part exceeds limit');
      return part;
    };
    await mount_bdf_encrypted_split_async(host, manifest, loader, 'pass', 'single');
  } else if (mode === 'encrypted-ecdh' || mode === 'encrypted-ecdh-split') {
    const jwk = await (await fetch(`${dir}test-private.jwk`)).json();
    const privateKey = await crypto.subtle.importKey('jwk', jwk, { name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveKey']);
    const { d, ...publicJwk } = jwk;
    const publicKey = await crypto.subtle.importKey('jwk', publicJwk, { name: 'ECDH', namedCurve: 'P-256' }, true, []);
    const pair = { publicKey, privateKey };
    if (mode === 'encrypted-ecdh-split') {
      const manifest = await bytes('ecdh-split/manifest.json');
      await mount_bdf_encrypted_split_async(host, manifest, hash => bytes(`ecdh-split/parts/${hash}`), pair, 'single');
    } else {
      await mount_bdf_encrypted_async(host, await bytes('ecdh.bdf'), pair, 'single');
    }
  } else {
    await mount_bdf_encrypted_async(host, await bytes('password.bdf'), 'pass', 'single');
  }
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error';
  window.bdfError = String(error?.stack ?? error);
  console.error(error);
}
