# Browser MVP

The `browser` package compiles to a JS-target foreign library exporting
`mount_bdf_async` and `mount_bdf`. It draws a BDF document into Canvas elements without the original
TypeScript renderer. The BDF parser, command decoder and page positions are MoonBit.

```sh
moon build --target js
# Find the linked browser artifact under _build/js.
```

```js
// import { mount_bdf_async, mount_bdf } from "<compiled browser JS module>";
const bytes = new Uint8Array(await (await fetch("/sample.bdf")).arrayBuffer());
const pageCount = await mount_bdf_async(document.querySelector("#preview"), bytes, "spread");
// mount_bdf is synchronous and supports documents without images or embedded fonts.
```

This intentionally supports only unencrypted, fixed/flow BDF documents
whose BOBJ parts use the implemented drawing subset. It does not try to convert
PDF/Office documents. The asynchronous entry point loads image and embedded font
parts before drawing and releases them afterward. It supports raster images, SVG,
and image patterns. A complete port needs Worker and cryptography host services.
