# npm release: bdf.mbt

The unscoped package is `bdf.mbt`. Releases use `YYYY.MM.PATCH` CalVer in
`Asia/Tokyo`, for example `2026.11.0`. Month and patch are not zero padded, so
versions are valid npm SemVer values. PATCH increases within the month; it
is not a claim of SemVer compatibility. Review changelogs before upgrades.

## Separate checks from publication

Run required unit/PBT, installed-package and browser tests locally through
actrun, and obtain independent review for the exact source commit. Do not
include tests in the hosted release job. The workflow builds and publishes
only; a passing release build does not replace the local review evidence.

`.github/workflows/npm-release.yaml` is manual-only, restricted to this
repository's main branch. Its selected full `source_sha` must equal the main dispatch commit
(`GITHUB_SHA`), so npm provenance identifies exactly the built source. Default `publish: false` only prepares a downloadable tarball; it
neither publishes nor creates a release tag. A normal push cannot publish.

The workflow uses the pinned core `f4ah6o/calver-action` rather than its npm
reusable workflow: this repository is a MoonBit project whose root npm
manifest is a private test harness, and its public package is generated.
The core action allocates a version without creating a tag. The workflow
packs a release artifact and, only with `publish: true`, publishes it and
then creates the immutable prefixless source tag. If publication succeeds
but tag push fails, recover the tag only after checking the registry version
and artifact integrity; do not blindly publish a second version.

The build currently uses the same setup-moonbit action as the existing site
workflow. Record the actual compiler/core versions during validation and
revalidate after toolchain updates. A fresh hosted build has not yet been
executed for this workflow; only local validation is evidence so far.

## Trusted Publishing setup

See [npm's current documentation](https://docs.npmjs.com/trusted-publishers/).
Use a GitHub-hosted runner, Node 24 and npm 11 (at least 11.5.1). The job grants
`id-token: write`; it does not use a stored `NPM_TOKEN` or local login token.
The public manifest's repository URL is `https://github.com/f4ah6o/bdf.mbt`.

Configure the package's npm Trusted Publisher with:

- Provider: GitHub Actions
- Owner: `f4ah6o`
- Repository: `bdf.mbt`
- Workflow filename: `npm-release.yaml` (filename only)
- Environment: leave blank (this workflow has no environment)
- Permit direct `npm publish` for this workflow.

The workflow does not create that account-level trust configuration.
The current npm trust CLI requires an existing package and account 2FA;
local `(p)npm login` does not configure OIDC. If the package does not yet
exist, complete the first authorized bootstrap release using the maintainer's
login before configuring Trusted Publishing for later releases. Do not put
that credential into GitHub secrets or this repository. Use the real reviewed
CalVer artifact, not an empty name-reservation package.

After first publication, configure trust and validate its first successful
OIDC publish within npm's current two-day setup window. Consult npm's
website for current setup requirements before making account changes.

## Local release artifact preparation (no registry write)

After building the five JS bundles used by `library-pack.mjs`:

```sh
node plugin/tools/library-pack.mjs --release-version 2026.11.0 \
  --source-sha "$(git rev-parse HEAD)"
```

This creates `_scratch/library-pack/bdf.mbt-2026.11.0.tgz` with public
publication metadata, source SHA and exact file allowlist. It does not publish.
The ordinary command still creates `0.0.0-staging` with `private: true`.
A release identity cannot be combined with staging-name/version overrides.

Verify the actual registry state and current immutable tags before choosing a
bootstrap version. For regular releases the workflow's CalVer action allocates
it. Do not type the example version into a real release without checking.
