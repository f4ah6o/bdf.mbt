The `basic*.bdf` fixtures come from `shibukawa/bdf` commit
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (`testdata/epub` and
`testdata/segments`) under the upstream MIT license. The three numbered
segments were sealed with the upstream test-only reader key. The compatibility
server rewraps their content keys for the fresh P-256 public key supplied by
each Worker request; the private key in the test is public fixture data.
