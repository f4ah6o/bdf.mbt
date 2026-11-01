# Photoshop compatibility fixtures

The fixtures are the upstream `converter/psd/testdata` files at shibukawa/bdf
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`): bitmap, CMYK, 16-bit grey, indexed, Lab, 32-bit
RGB, PSB, layers and artboards.

`convert/psd/fixtures_generated_wbtest.mbt` embeds them for the MoonBit unit
tests. `compat/converter/phase1-test.mjs` compares page counts, artboard
geometry and decoded pixels with the upstream converter.

The converter uses the composite image Photoshop stores beside the layers.
A file saved without "Maximize Compatibility" has no composite and fails with
an explicit error; layer compositing is a documented gap.
