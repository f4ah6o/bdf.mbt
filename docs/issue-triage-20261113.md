# Local issue triage: 2026-11-13

Reviewed main: `d13b9578c86982cb6ea0d955f678c16e2edc84e9`.

## Applied scope

This is a state/documentation reconciliation, not a runtime change.
Ten issue documents moved to `issues/done/`:

- Four native-target issues and two XDW text-index/annotation issues already
  carried `Status: done`; their directory had not followed their status.
- DOCX AlternateContent and drawing degradation are integrated by PRs #7 and #8.
- PPTX connectors and FIGURE alternative text are integrated by PRs #6 and #18.

Each moved issue records its evidence and limits. Acceptance boxes follow the verified bounded scope; original problem
descriptions are retained as historical text, with the dated disposition below them. Related document links follow the new paths.

## Counts

Before: 45 files, open-directory 43, polished-directory 1, done-directory 1.
After: 45 files, open-directory 33, polished-directory 1, done-directory 11.
Of the 33 files in open/, 32 have work or verification left; one is the
existing `superseded` XDW umbrella pointer. The repository's GitHub Issues
feature is disabled: these are repository-local Markdown records.

The 33 nonterminal records (32 open plus 1 polished) are not 33 independent bugs: broad parity milestones
overlap their child tasks. They must not be closed just to reduce the count.

## Explicitly not closed

- DOCX paragraph marks: the direct mark fix is integrated, but the issue also
  includes list-level run-property merging. Preserve the original open issue
  until that residual scope has a separately tracked disposition.
- PDF public API: implementation and structural/consumer tests are integrated,
  but the original rendered-PDF regression-image comparison is still absent.
  Preserve its polished state rather than silently dropping that test plan.

- XLSX font metrics: PR #9 covers MDW/column widths/indents, not row heights,
  auto-fit, shrink-to-fit or General-format fitting.
- XLSX fixture storage: draft PR #29 is still integrating pinned dynamic
  upstream goldens; this triage does not modify its issue or branch.
- Selection/clipboard: API and UI implementations are integrated, but the
  original cross-format/XDW investigation still needs its evidence reconciled.
- Local font display/picker: real OS/browser permissions and deployed Pages
  validation remain unchecked in the issues.
- DXF sample parity, XDW full-corpus/oracle comparison, internal PPTX slide
  links and the broader converter parity milestones remain open.

PDF API implementation does not mean PDF writer visual fidelity is complete.
The PR records no rendered-PDF image-golden comparison. Images, shadows,
gradients and tagged output remain documented writer limitations tracked by
the separate vector/pdfbdf issue. The DOCX paragraph-mark issue likewise retains its list-level run-property gap.

## Validation

- Fresh local runner self-tests: `node --test .github/local/verify.test.mjs`,
  34 passed, 0 failed.
- Issue CLI plan was reviewed in dry-run before application.
- Existing issue contents were preserved except metadata, path/link updates
  and appended disposition evidence.
- Product test results cited in issue notes are evidence from their referenced
  PRs/commits, not fresh full-runtime or full-parity runs for this docs change.

The roadmap validator now discovers all existing issue state directories, and
the index covers all 45 files. The previously missing XLSX metrics summary now
records the implemented slice and the still-open work; no runtime XLSX changes.
