# Verification scope

This file records the verification scope for the narrowed bdf.mbt port.
The converter registration, viewer and visual aggregate exclude the dropped
formats. Existing sources and fixtures remain as dormant assets.

## Retained formats

| Area | Formats |
|---|---|
| Documents | PDF, DOCX, PPTX, XLSX, CSV, Markdown, HTML, IDML, Visio VSDX, draw.io, Parquet, XDW |
| Images and vector art | PNG, JPEG, GIF, WebP, AVIF, SVG, BMP, ICO, TIFF, PSD, AI, EMF/WMF |
| Fonts | SFNT/TTC, WOFF, WOFF2, CFF, font specimens |
| Non-PCB CAD | DXF (text and binary), SXF SFC, CGM, HP-GL/2, Jw_cad |
| Audio | MP3, AAC/M4A, FLAC, Ogg Vorbis/Opus, WAV, AIFF audio cards and embedded recordings |

## Dropped formats

| Area | Formats |
|---|---|
| PCB/KiCad | KiCad PCB, Gerber, Excellon |
| Musical score | MIDI score, MML, MusicXML/MXL, music notation, TAB views |
| E-book | EPUB (reflowable and fixed-layout) |

Audio cards and audio playback remain in scope. MIDI is dropped as a musical
score format; the audio cue and embedded-recording paths stay.

## Local gates

`npm run verify:local` runs these gates through actrun in the current worktree:

| Gate | Workflow / job | Retained-format checks |
|---|---|---|
| `self-test` | — | `node --test .github/local/verify.test.mjs` |
| `workflow-lint` | — | `actrun lint` over the four verification workflows; the deployment workflow is checked structurally by `self-test` |
| `ci/test` | `.github/workflows/ci.yml` / `test` | retained-package `moon check`, `moon test` and `moon build` for `js`, `wasm-gc` and `native`, with the min-test-count assertion |
| `ci/demo` | `.github/workflows/ci.yml` / `demo` | `site/verify-samples.mjs`, `build:demo`, `test:demo`, `test:previews` |
| `parity` | `.github/workflows/parity.yml` / `parity` | retained-package JS build, `compat/parity/verify.mjs --limit=100` (PDF/DOCX/XLSX/PPTX/Markdown) |
| `visual` | `.github/workflows/visual.yml` / `compare` | XLSX picture visual via the fresh oracle runner, `npm run test:visual` (retained formats, audio playback and the dropped-format dispatch guard) |
| `site` | `.github/workflows/pages.yml` / `build` | `build:site`, `test:site`, `test:previews`, `bench:site --check`, the vlmkit checks |

The `visual` gate's exact command set is owned by `package.json`. Its aggregate
excludes the dropped score, PCB/KiCad and EPUB suites; their individual scripts
remain available for manual verification. See "Visual aggregate scope" below.
The XLSX checks require a provisioned fixed oracle and, on non-ARM64 hosts, the
approved emulator. Export the environment variables before running the local
workflow as described in [the XLSX oracle guide](../compat/xlsx/oracle/README.md).

## Visual aggregate scope

`npm run test:visual` is the required visual aggregate. It runs
`node compat/visual/aggregate-scope-test.mjs` first, then the retained checks.
The dropped-format suites are not part of it:

- `test:music-compat` is not run. It bundles `compat/music/verify.mjs` (SMF and
  score parsing) and `compat/music/player-test.mjs` (MIDI score playback), both
  dropped. The aggregate runs `node compat/music/audio-test.mjs` instead, which
  covers the retained audio transport, callbacks, errors, speed and audio cues.
- `compat/visual/compare.mjs` no longer imports or calls `verifyPiano`,
  `verifyMusicBrowser` or `verifyViewerMusic`, and no longer captures the
  `piano-baseline.html` / `piano-moon.html` fixtures. Those checks used an MML
  BDF and score/piano-roll views, which are dropped.
- `compat/visual/compare.mjs` keeps `verifyAudioBrowser`, which exercises the
  retained audio card and embedded-recording playback. It uses
  `compat/music/fixtures/ode-mml.bdf` only as a source document and replaces
  its play data with a WAV part, so it does not test score rendering.
- `compat/visual/compare.mjs` keeps `verifyNativeConverter`, whose negative
  guard proves that `midi`, `mml`, `musicxml`, `epub`, `gerber` and `kicad` are
  not registered or dispatched, including by file extension.

The dropped individual scripts (`test:music-compat`, `test:midi-input`,
`test:midi-visual`, `test:mml-input`, `test:mml-document`, `test:mml-visual`,
`test:musicxml-input`, `test:music-notation`, `test:phase10-musicxml`) and their
sources, tests and fixtures stay in the tree. They are dormant assets, not
required checks.

`compat/visual/aggregate-scope-test.mjs` enforces this deterministically: it
expands `test:visual` through nested `npm run` references, rejects every
dropped entry point and script, requires the retained audio test, and checks
that `compat/visual/compare.mjs` keeps the audio and negative-guard calls while
dropping the score calls.

## Verification workflows do not run on GitHub

The four workflow files stay in `.github/workflows` because actrun uses the
workflow's directory as the workspace, and only `.github/workflows` resolves to
the repository root. They are inert on GitHub:

- the only trigger is `push` with `branches-ignore: ['**']`, which matches no
  branch, so no push can start them;
- there is no `workflow_dispatch`, `pull_request` or `schedule` trigger, so
  nobody can start them from the GitHub UI or API either;
- actrun ignores branch filters when `--ref`/`--before`/`--after` are omitted,
  so the local flow still runs them.

`self-test` asserts this: every verification workflow must declare `push` with
`branches-ignore: ['**']` and no other trigger.

## Manual deployment

Publishing is the one workflow GitHub can run:
`.github/workflows/pages-deploy.yml`. It is `workflow_dispatch` only, so it
starts only when a maintainer dispatches it, and only after the deployment is
separately authorized.

- Permissions: `contents: read` at the top level, `pages: write` and
  `id-token: write` on the `deploy` job only.
- Concurrency: `group: pages-deploy`, `cancel-in-progress: false`, so a
  deployment that is already publishing is never interrupted.
- Steps: checkout, setup Node.js, setup MoonBit, `moon update`, `npm ci`,
  `npm run build:site`, `actions/upload-pages-artifact@v3`,
  `actions/deploy-pages@v4`. No tests, no vlmkit, no benchmarks.

`self-test` asserts that exactly one workflow is dispatchable, that it is this
one, that it contains no test or quality-check command, and that no local gate
targets it. `actrun lint` skips it because actrun 0.32.0 cannot parse a
`workflow_dispatch`-only file; the self-test covers its shape instead.

The local flow never runs or dispatches it, never uploads a Pages artifact and
never publishes the site. Branch protection may still require the old check
names, so a pull request can stay blocked until those rules are updated.

## Retained-scope wiring and measurement

`compat/retained-test.mjs` enumerates retained packages per target and excludes
the dormant packages. A bare `moon test` still includes dormant packages.
The selector reports any retained packages that import dormant ones; such a
dependency would still compile the dormant code. The current integrated tree
has no direct imports of dormant packages from retained packages.
`.github/local/moon-test.mjs` records `retained-scope: retained` when the
selector is used. If it is missing, the wrapper reports `retained-scope:
pending`; a full-tree run is not evidence of retained-only coverage. The
minimum of 2700 tests is a canary against lost coverage, not an exact count.

On 2026-11-10, scope branch commit `430df07` recorded 2754 tests for `js` and
2732 each for `wasm-gc` and `native`. These are historical measurements, not
claims about a later integrated commit. Use the manifest and logs of a run for
its fixed HEAD, selected gates, commands, counts and exit codes. A successful
subset is recorded as `partial-pass`, rather than a full pass.

## Hosted-only behavior

The local flow never runs the GitHub-hosted setup steps, the Pages artifact
upload or the Pages deployment. See the "Local verification" section of the
README for the exact list and the evidence layout.
