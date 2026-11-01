# KiCad compatibility fixtures

The source is the upstream `converter/kicad/testdata/demo.zip` at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`). `demo.kicad_pcb` is extracted from it.

`convert/kicad` currently ports a single `.kicad_pcb` board into a front-view
BDF page: Edge.Cuts graphics, tracks, vias, footprint pads and reference/value
text. Schematic files, projects/zip archives, back and per-layer views,
zones, 3D models and NewStroke text are documented gaps.
