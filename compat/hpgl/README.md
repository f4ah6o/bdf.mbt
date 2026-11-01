# HP-GL/2 compatibility fixtures

The fixtures are the upstream `converter/hpgl/testdata` files at shibukawa/bdf
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`).

- `hpgl1.plt`: HP-GL instructions, ticks, labels, a circle and a line type.
- `shapes.plt`: HP-GL/2 line types, arcs, Bézier curves, encoded polylines,
  polygon fills, wedges, rectangles, hatch patterns, labels and clip windows.
- `job.plt`: a PJL/PCL job with HP-GL/2 and HP RTL raster images.

`convert/hpgl/hpgl_wbtest.mbt` embeds the first two fixtures for the MoonBit
unit tests. `compat/converter/phase5-test.mjs` compares the
converted pages with the upstream converter. PCL/HP RTL raster jobs are a
documented gap: the escape sequences are skipped with a warning and only the
HP-GL/2 instructions are converted.
