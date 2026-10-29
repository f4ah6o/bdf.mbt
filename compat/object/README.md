# Object writer compatibility

`upstream.json` is generated with the upstream Go object and path writers at
commit `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`. It covers all resource
types, the drawing instructions used by the fixture, automatic bounds,
string deduplication, and byte-order-mark removal.

From that upstream checkout, regenerate it with:

```sh
go run /path/to/bdf.mbt/compat/object/generate.go > /path/to/bdf.mbt/compat/object/upstream.json
```

Run `moon build --target js` followed by `npm run test:object-compat` to
compare generated and round-tripped bytes with upstream.
