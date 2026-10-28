# Browser MVP

The `browser` package compiles to a JS-target foreign library exporting
`mount_bdf`. It draws a BDF document into Canvas elements without the original
TypeScript renderer. The BDF parser, command decoder and page positions are MoonBit.

```sh
moon build --target js
# Find the linked browser artifact under _build/js.
```

```js
// import { mount_bdf } from "<compiled browser JS module>";
const bytes = new Uint8Array(await (await fetch("/sample.bdf")).arrayBuffer());
const pageCount = mount_bdf(document.querySelector("#preview"), bytes, "spread");
```

This intentionally supports only unencrypted, fixed/flow BDF documents
whose BOBJ parts use the implemented drawing subset. It does not try to convert
PDF/Office documents, decode images, or load embedded fonts.
A complete port needs Worker and cryptography host services.
