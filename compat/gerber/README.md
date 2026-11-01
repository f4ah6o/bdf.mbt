# Gerber compatibility fixtures

The fixture is the upstream `converter/gerber/testdata/features.gbr` at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`).

`convert/gerber` currently ports single-file RS-274X parsing: FS/MO/AD/AM,
D01/D02/D03, linear and circular interpolation, regions, standard apertures
and an approximate macro aperture. It draws a 1:1 layer page. The upstream
board page scaling, zip archives, Excellon drill files, clear polarity and
exact macro primitives are documented gaps.
