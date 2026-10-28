# Browser MVP

The `browser` package compiles to a JS-target foreign library exporting
`mount_bdf_async`, `mount_bdf_split_async`, the encrypted-document entry points, and `mount_bdf`. It draws a BDF document into Canvas elements without the original
TypeScript renderer. The BDF parser, command decoder and page positions are MoonBit.

```sh
moon build --target js
# Find the linked browser artifact under _build/js.
```

```js
// import { mount_bdf_async, mount_bdf_split_async, mount_bdf_encrypted_async, mount_bdf_encrypted_split_async, mount_bdf } from "<compiled browser JS module>";
const bytes = new Uint8Array(await (await fetch("/sample.bdf")).arrayBuffer());
const pageCount = await mount_bdf_async(document.querySelector("#preview"), bytes, "spread");
// mount_bdf is synchronous and supports documents without images or embedded fonts.
```

This currently supports fixed/flow BDF documents
whose BOBJ parts use the implemented drawing subset. It does not try to convert
PDF/Office documents. The asynchronous entry point loads image and embedded font
parts before drawing and releases them afterward. It supports raster images, SVG,
and image patterns. A complete port needs Worker transport and additional viewer features.


For a split document, supply the UTF-8 manifest bytes and a loader that
returns each stored part as a `Uint8Array`. The loader receives the validated
part hash and the maximum stored size from the manifest. It must enforce this
limit while reading or downloading, before buffering the entire response. The
library verifies the returned size and decodes the part. Only parts referenced
by the selected view are requested, at most once each.

```js
const manifest = new Uint8Array(await (await fetch('/split/manifest.json')).arrayBuffer());
const pages = await mount_bdf_split_async(host, manifest, async (hash, limit) => {
  const response = await fetch(`/split/parts/${hash}`);
  if (!response.ok || !response.body) throw new Error('part request failed');
  const reader = response.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > limit) throw new Error('part exceeds declared size');
      chunks.push(value);
    }
  } finally { await reader.cancel(); }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return bytes;
}, 'single');
```


Encrypted single-file documents can be mounted in a secure browser context
using a password or a Web Crypto P-256 `CryptoKeyPair`:

```js
await mount_bdf_encrypted_async(host, bytes, password, 'single');
// Alternatively: await mount_bdf_encrypted_async(host, bytes, keyPair, 'single');
```

For split documents, use the same bounded part loader described above:

```js
await mount_bdf_encrypted_split_async(host, manifest, loadPart, password, 'single');
```

The browser derives the wrapping key with PBKDF2 or ECDH/HKDF and opens the
content key and authenticated parts with Web Crypto. Wrong credentials,
invalid key slots, and altered ciphertext cause the promise to reject. The
password is normalized using NFKC. These entry points require Web Crypto, which
browsers expose in secure contexts such as HTTPS and localhost.
