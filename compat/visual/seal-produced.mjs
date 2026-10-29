import { encrypt_bdf_password, encrypt_bdf_ecdh, mount_bdf_encrypted_async } from '/_build/js/debug/build/browser/browser.js';

try {
  const input = new Uint8Array(await (await fetch('./fixture.bdf')).arrayBuffer());
  const host = document.querySelector('#host');
  if (location.pathname.endsWith('/seal-ecdh.html')) {
    const jwk = await (await fetch('./encrypted-fixture/test-private.jwk')).json();
    const { d, ...publicJwk } = jwk;
    const publicKey = await crypto.subtle.importKey('jwk', publicJwk, { name: 'ECDH', namedCurve: 'P-256' }, true, []);
    const privateKey = await crypto.subtle.importKey('jwk', jwk, { name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveKey']);
    const raw = new Uint8Array(await crypto.subtle.exportKey('raw', publicKey));
    const output = await encrypt_bdf_ecdh(input, raw);
    await mount_bdf_encrypted_async(host, output, { publicKey, privateKey }, 'single');
  } else {
    const output = await encrypt_bdf_password(input, 'pass', 1000);
    await mount_bdf_encrypted_async(host, output, 'pass', 'single');
  }
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error';
  window.bdfError = String(error?.stack ?? error);
  console.error(error);
}
