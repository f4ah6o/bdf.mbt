# Writer compatibility

`verify.mjs` opens MoonBit-written single and split documents with the
upstream JavaScript reader. It also joins upstream split fixtures, including
password- and P-256-encrypted documents, verifies part contents, and rejects
corrupted stored parts. `compat/visual/compare.mjs` renders generated split
documents and compares them with the original using vlmkit.

`verify-sealing.mjs` checks new password and P-256 encrypted output against
the upstream JavaScript reader, including NFKC passwords, invalid inputs,
wrong keys and tampered ciphertext. The visual comparison also renders both
new encrypted formats in Chromium.

The optional Go check opens a generated split directory or single file with
the upstream Go reader and writes it as a single file. For the public encrypted test
fixture, it uses the fixture's test password `pass`:

```sh
go run /path/to/bdf.mbt/compat/writer/verify-split.go /path/to/split-directory
# Add `ecdh` for a document encrypted to the public P-256 test fixture.
```
