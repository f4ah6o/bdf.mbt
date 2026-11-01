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

`native-test.mjs` also exercises the native Worker through both clients. Its
MML fixtures compare complete upstream-generated documents, summaries, warnings,
format detection and parameter errors for actual UTF-8 and Shift_JIS files.

`phase1-test.mjs` compares the AI, TIFF, PSD and EMF/WMF converters with the
upstream `@bdfkit/convert-all` Wasm. It checks page counts, page geometry,
decoded image pixels, streamed pages, page selection and parameter errors.
JPEG-compressed TIFF pages and the documented metafile subset are covered as
explicit warnings.

`phase5-test.mjs` compares the HP-GL/2 converter with the upstream
`@bdfkit/convert-all` Wasm. It checks the format registration, page geometry,
layer roles, text indexes, streamed pages, page selection and parameter
errors for the upstream `hpgl1.plt` and `shapes.plt` fixtures. PCL/HP RTL
raster jobs are a documented subset and are not part of the fixture set yet.
