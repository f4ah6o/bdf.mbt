# PDF compatibility fixtures

The fixtures are the upstream `converter/pdf/testdata` files at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`).

`cairo-type1.pdf` and `reportlab-type1.pdf` embed Type 1 `FontFile` programs.
`convert/pdf` converts their charstrings to a name-keyed CFF, then embeds the
font through the existing CFF/OpenType/WOFF2 path. The phase 8 test checks that
both pages embed a font part without fallback warnings.
