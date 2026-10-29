# SFNT compatibility fixtures

The font fixtures are copied from `converter/font/testdata` in
[shibukawa/bdf](https://github.com/shibukawa/bdf), pinned at commit
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431`. They include STIX Two Text,
licensed under the [SIL Open Font License](fixtures/OFL.txt). The separate
`compat/visual/synthetic.ttf` fixture is generated in this repository.

`upstream.json` records face metadata, metrics, and hashes of every Unicode
mapping and horizontal advance. `synthetic.json` covers constructed and
malformed cmap subtables. `geometry.json` records grid dimensions for each
font and language scenario. `npm run test:font-compat` checks them against the
MoonBit implementation after `moon build --target js`.

To regenerate the JSON files, copy each Go generator into a directory under
an upstream checkout (its imports use upstream internal packages) and run it
with the absolute path to this repository as its argument. Redirect the output
to the corresponding JSON file. Use the pinned upstream revision above.
