# Converter Worker compatibility

`client-test.mjs` compares the MoonBit client with `@bdfkit/convert` 0.2.1
using a controllable Worker. It covers readiness, concurrent responses, input
buffer copies, errors and termination.

`browser-test.mjs` builds a two-page PDF in memory and runs PDF conversion,
streamed pages and CSV conversion in real Chromium Workers. It compares all
four combinations of upstream and MoonBit client and Worker using the upstream
`@bdfkit/convert-office` 0.2.1 TinyGo Wasm runtime. The runtime and Go support
script are test dependencies only; the converter engines have not been ported
by these tests.
