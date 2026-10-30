# XLSX compatibility fixtures

`verify-workbook.mjs` compares workbook part resolution, date system, worksheet
and chart sheet references, visibility, ordering and unsupported-sheet warnings
against upstream. `verify-reference.mjs` checks cell references, column names
and Excel string escapes; `verify-strings.mjs` covers shared strings; `verify-cells.mjs` checks worksheet
rows and cells; `verify-date.mjs` checks ISO date serials;
`verify-geometry.mjs` and `verify-range.mjs` check worksheet layout; `verify-styles.mjs` checks fonts and cell formats; `verify-general.mjs` checks General number formatting; `verify-builtin.mjs` and `verify-sections.mjs` check built-in formats and section splitting; `verify-formats.mjs` checks format tokens, conditions, colors, section selection and numeric layout; `verify-numeric.mjs` compares numeric output pieces; `verify-date-format.mjs` and `verify-formatted.mjs` check date, number and text cell formatting; `verify-display.mjs` checks workbook cells and indexed color palettes; `verify-layout.mjs` checks initial extents and row/column runs using supplied fitted heights; `verify-paint.mjs` checks fills, gradients and borders; `verify-color.mjs` checks color resolution and tinting; `verify-locale.mjs` checks document metadata and workbook locale inference; `verify-table-values.mjs` checks used ranges, encoded Parquet tables and BDF table manifests; `verify-list-tables.mjs` checks worksheet ListObject references; `verify-store-sheet.mjs` checks sheet table storage, modes and warnings; `verify-render.mjs` checks the supported plain-sheet conversion end to end. The General fixture excludes inputs on which the upstream formatter recurses indefinitely. The cases include seven real workbooks and generated packages.

After building the JavaScript target, run `node compat/xlsx/verify-workbook.mjs` `node compat/xlsx/verify-reference.mjs`, `node compat/xlsx/verify-strings.mjs`,
`node compat/xlsx/verify-cells.mjs`, `node compat/xlsx/verify-date.mjs`,
`node compat/xlsx/verify-range.mjs`, `node compat/xlsx/verify-geometry.mjs`
`node compat/xlsx/verify-styles.mjs`, `node compat/xlsx/verify-general.mjs`, `node compat/xlsx/verify-builtin.mjs`, `node compat/xlsx/verify-sections.mjs`, `node compat/xlsx/verify-formats.mjs`, `node compat/xlsx/verify-numeric.mjs`, `node compat/xlsx/verify-date-format.mjs`, `node compat/xlsx/verify-formatted.mjs`, `node compat/xlsx/verify-display.mjs`, `node compat/xlsx/verify-layout.mjs`, `node compat/xlsx/verify-paint.mjs`, `node compat/xlsx/verify-color.mjs`, `node compat/xlsx/verify-locale.mjs`, `node compat/xlsx/verify-table-values.mjs`, `node compat/xlsx/verify-list-tables.mjs`, `node compat/xlsx/verify-store-sheet.mjs`, and `node compat/xlsx/verify-render.mjs`.
`npm run test:xlsx-compat` runs the complete XLSX and OOXML fixture suite; it is
also included in `npm run test:visual` after the JavaScript build.
The rendering fixtures include the upstream `form-pages.xlsx`, `print.xlsx`,
`form-fixed.xlsx`, and `form-rows.xlsx`
workbooks, along with generated cases for solid fills, colored and dashed
borders (including diagonals and multiple colors at one weight), named and
themed fonts and default font sizes, italic and decorated text, superscripts
and subscripts, merged rectangles, center-across-selection, wrapped, indented
and shrink-to-fit text, fixed and automatic row heights, hidden rows and
columns, unformatted text runs, links, conditional font, solid-fill, and border formats,
row and column styles including solid backgrounds and borders, and
uncached formula warnings. Patterned base fills and complex base borders have
separate rejection cases. The rendering
cases are split into indexed chunks so individual fixture files stay small.
Copy `generate_render_test.go` without its build tag into upstream
`converter/xlsx` and run `TestCodexXLSXRender` to regenerate them.
The base-fill and base-border cases are regenerated separately using
`generate_base_fill_test.go` / `TestCodexBaseFill` and
`generate_base_border_test.go` / `TestCodexBaseBorder`.
Single-run cases use `generate_plain_run_test.go` and `TestCodexPlainRun`.
Link cases use `generate_links_test.go` / `TestCodexLinks` and
`generate_percent_links_test.go` / `TestCodexPercentLinks`.
Inactive conditional-format cases use `generate_inactive_cf_test.go` and
`TestCodexInactiveCF`.
Conditional-font cases use `generate_active_cf_test.go` and `TestCodexActiveCF`.
Conditional-fill cases use `generate_conditional_fill_test.go` and
`TestCodexConditionalFill`.
Conditional-border cases use `generate_conditional_border_test.go` and
`TestCodexConditionalBorder`.
Conditional comparison cases use `generate_conditional_ops_test.go` and
`TestCodexConditionalOps`.
Conditional interval cases use `generate_conditional_between_test.go` and
`TestCodexConditionalBetween`.
Conditional formula prefix cases use `generate_conditional_equals_test.go` and
`TestCodexConditionalEquals`.
Conditional absolute-reference cases use `generate_conditional_absolute_test.go`
and `TestCodexConditionalAbsolute`.
Single-cell relative-reference cases use `generate_conditional_single_ref_test.go`
and `TestCodexConditionalSingleRef`.
Axis-aligned relative-reference cases use `generate_conditional_axis_ref_test.go`
and `TestCodexConditionalAxisRef`.
Typed string, boolean, error and numeric references use
`generate_conditional_typed_reference_test.go` and `TestCodexConditionalTypedReference`.
Moving relative-reference cases use `generate_conditional_moving_ref_test.go`
and `TestCodexConditionalMovingRef`; bounded ranges, blank paints, multiple
ranges, and sparse rows are covered.
Negated numeric-reference cases use `generate_conditional_negative_ref_test.go`
and `TestCodexConditionalNegativeRef`.
Negated blank and boolean references use `generate_conditional_negative_blank_test.go`
and `TestCodexConditionalNegativeBlank`. Negated numeric strings use
`generate_conditional_negative_string_test.go` and `TestCodexConditionalNegativeString`. Invalid computed references use
`generate_conditional_invalid_reference_test.go` and `TestCodexConditionalInvalidReference`.
Blank and error predicates use `generate_conditional_predicates_test.go`
and `TestCodexConditionalPredicates`.
Text predicates use `generate_conditional_text_test.go` and
`TestCodexConditionalText`. Go Unicode lowercase mappings are regenerated
with `generate_lowercase_test.go` and `TestCodexXLSXLowercaseTable`.
Top and bottom rank predicates use `generate_conditional_top_test.go`
and `TestCodexConditionalTop`, including large and decimal ranks.
Average predicates use `generate_conditional_average_test.go` and
`TestCodexConditionalAverage`; standard-deviation cases use
`generate_conditional_stddev_test.go` and `TestCodexConditionalStdDev`. Large
multipliers use `generate_conditional_large_stddev_test.go` and
`TestCodexConditionalLargeStdDev`; overflowed means use
`generate_conditional_overflow_mean_test.go` and `TestCodexConditionalOverflowMean`.
Nonfinite values use `generate_conditional_nonfinite_average_test.go` and
`TestCodexConditionalNonfiniteAverage`. Independent conditional ranges use
`generate_conditional_disjoint_test.go` and `TestCodexConditionalDisjoint`;
moving references use `generate_conditional_disjoint_moving_test.go` and
`TestCodexConditionalDisjointMoving`. Overlapping ranges with the same style use
`generate_conditional_same_style_test.go` and `TestCodexConditionalSameStyle`;
multiple rules use `generate_conditional_same_rule_style_test.go` and
`TestCodexConditionalSameRuleStyle`. Rules with different styles and disjoint
matches use `generate_conditional_disjoint_matches_test.go` and
`TestCodexConditionalDisjointMatches`.
`conditional-identical-blocks.json` retains Go results for formerly unsupported
identical conditional blocks. Regenerate it from the adjacent input seeds with
`generate_conditional_identical_blocks_test.go` and `TestCodexConditionalIdenticalBlocks`.
Ignored worksheet metadata uses `generate_ignored_sheet_features_test.go` and
`TestCodexIgnoredSheetFeatures`; sheet extensions use
`generate_ignored_sheet_extensions_test.go` and `TestCodexIgnoredSheetExtensions`.
Worksheet filter buttons use `generate_sheet_autofilter_test.go` and
`TestCodexSheetAutoFilter`; tile boundaries use
`generate_sheet_autofilter_tiles_test.go` and `TestCodexSheetAutoFilterTiles`. Missing drawing or table references use
`generate_sheet_missing_parts_test.go` and `TestCodexSheetMissingParts`.
Sheet comment markers use `generate_sheet_notes_test.go` and `TestCodexSheetNotes`; their interaction with
filters uses `generate_sheet_notes_filter_test.go` and `TestCodexSheetNotesFilter`.
Multiple notes are checked with `verify-sheet-multiple-notes.mjs`, which compares
marker paths without assuming the Go map iteration order. The fixtures use
`generate_sheet_multiple_notes_test.go`, `generate_sheet_multiple_notes_filter_test.go`,
and `generate_sheet_multiple_notes_legacy_test.go`.
Multiple unformatted text runs use `generate_multiple_plain_runs_safe_test.go`
and `TestCodexMultiplePlainRunsSafe`. Plain runs with text number formats, mixed
direct text, data extraction, wrapping and duplicate cell references use
`generate_rich_run_data_test.go`, `generate_rich_run_wrap_test.go`,
`generate_rich_run_identity_test.go` and `generate_rich_run_legacy_test.go`.
Single styled runs use `generate_single_styled_run_test.go`,
`generate_single_styled_run_conditional_test.go`, `generate_single_styled_run_variants_test.go`,
and `generate_single_styled_run_legacy_test.go`. Multiple styled runs with color, bold, italic, underline and strike are
supported with wrapping, explicit line breaks, and left, right or center alignment.
Their coverage uses `generate_multi_color_runs_test.go`,
`generate_multi_color_runs_geometry_test.go`,
`generate_multi_color_runs_conditional_test.go` and
`generate_multi_color_runs_unsupported_test.go`,
`generate_multi_font_runs_test.go`, `generate_multi_font_runs_geometry_test.go`,
`generate_multi_font_runs_conditional_test.go`, `generate_multi_font_precision_test.go`
and `generate_multi_font_legacy_test.go`.
Alignment and Unicode coverage uses `generate_multi_align_runs_test.go`,
`generate_multi_align_runs_geometry_test.go`, `generate_multi_align_runs_conditional_test.go`,
`generate_multi_align_precision_test.go`, `generate_multi_unicode_runs_test.go`,
`generate_multi_unicode_runs_geometry_test.go`, `generate_multi_unicode_runs_conditional_test.go`,
`generate_multi_unicode_runs_aligned_test.go`, `generate_multi_unicode_repertoire_test.go`
and `generate_multi_unicode_legacy_test.go`. The original unsupported inputs are
retained for reproducible legacy fixtures. Wrapping coverage uses
`generate_multi_wrap_runs_test.go`, `generate_multi_newline_runs_test.go`,
`generate_multi_wrap_runs_conditional_test.go`, `generate_multi_newline_runs_conditional_test.go`,
`generate_multi_wrap_spaces_test.go`, `generate_multi_wrap_fuzz_test.go` and
`generate_multi_wrap_legacy_test.go`. Base fonts and runs that repeat the cell
font name or size are covered by `generate_multi_equal_font_runs_test.go`,
`generate_multi_equal_font_variants_test.go`, `generate_multi_equal_font_conditional_test.go`,
`generate_multi_base_font_runs_test.go`, `generate_multi_base_font_conditional_test.go`
and `generate_multi_base_font_legacy_test.go`. Shrink-to-fit coverage uses
`generate_multi_shrink_runs_test.go`, `generate_multi_shrink_base_test.go`,
`generate_multi_shrink_conditional_test.go`, `generate_multi_shrink_wrap_test.go`
and `generate_multi_shrink_fuzz_test.go`. Empty and whitespace-only runs,
leading and trailing whitespace, line breaks, tabs and other control characters
use `generate_multi_edge_space_plain_test.go`, `generate_multi_edge_space_wrap_test.go`,
`generate_multi_edge_newline_test.go`, `generate_multi_empty_runs_test.go`,
`generate_multi_control_plain_test.go`, `generate_multi_control_wrap_test.go`,
`generate_multi_control_shrink_test.go` and `generate_multi_edge_legacy_test.go`.
Per-run font families and theme resolution use `generate_multi_family_runs_test.go`,
`generate_multi_family_theme_test.go`, `generate_multi_family_conditional_test.go`,
`generate_multi_family_shrink_test.go`, `generate_multi_family_generic_test.go`
and `generate_multi_family_legacy_test.go`. Uniform per-run sizes and the
1,024-character display limit use `generate_multi_uniform_size_test.go`,
`generate_multi_uniform_size_variants_test.go`, `generate_multi_uniform_size_shrink_test.go`,
`generate_multi_uniform_size_conditional_test.go`, `generate_multi_truncate_plain_test.go`,
`generate_multi_truncate_wrap_test.go`, `generate_multi_truncate_shrink_test.go`
and `generate_multi_truncate_legacy_test.go`.
Duplicate and unique predicates use `generate_conditional_duplicate_test.go`
and `TestCodexConditionalDuplicate`. Numeric comparison-key tests are generated
by `generate_duplicate_keys_test.go` and `TestCodexXLSXDuplicateKeys`, including
subnormal and maximum finite values.
Conditional font cases matching blank cells use `generate_conditional_blank_test.go`
and `TestCodexConditionalBlank`.
Blank-cell paint cases use `generate_conditional_paint_blank_test.go` and
`TestCodexConditionalPaintBlank`.
To regenerate fixtures, copy `generate_workbook_test.go` without its build tag
into upstream `converter/xlsx` and run `TestCodexXLSXWorkbook` with
`BDF_FIXTURE_ROOT` set to this repository.

Varying run sizes, including sizes inherited from the cell, support wrapping,
shrink-to-fit, whitespace, controls and the display-length limit. Coverage uses `generate_multi_varying_size_test.go`,
`generate_multi_varying_aligned_test.go`, `generate_multi_varying_unicode_test.go`,
`generate_multi_varying_unicode_aligned_test.go`, `generate_multi_varying_height_test.go`,
`generate_multi_varying_conditional_test.go`, `generate_multi_varying_fuzz_test.go`
and `generate_multi_varying_unsupported_test.go`. Inherited-size cases use
`generate_multi_inherited_size_test.go`, `generate_multi_inherited_base_test.go`,
`generate_multi_inherited_conditional_test.go`, `generate_multi_inherited_height_test.go`,
`generate_multi_inherited_legacy_test.go` and `generate_multi_inherited_varying_legacy_test.go`.
Wrap-enabled cells that fit on one line are covered by `generate_multi_varying_wrap_fit_test.go`,
`generate_multi_varying_wrap_fit_conditional_test.go` and `generate_multi_varying_wrap_fit_height_test.go`.
Mixed-size wrapping uses `generate_multi_real_wrap_explicit_test.go`,
`generate_multi_real_wrap_inherited_test.go`, `generate_multi_real_wrap_height_test.go`,
`generate_multi_real_wrap_conditional_test.go`, `generate_multi_real_wrap_vertical_test.go`,
`generate_multi_real_wrap_fuzz_test.go`, `generate_multi_real_wrap_shrink_test.go`,
`generate_multi_real_wrap_control_test.go`, `generate_multi_real_wrap_edges_test.go`,
`generate_multi_real_wrap_long_test.go`, `generate_multi_real_wrap_legacy_test.go`
and `generate_multi_real_wrap_varying_legacy_test.go`.

Mixed-size normalization and shrinking use `generate_multi_varying_spaces_test.go`,
`generate_multi_varying_control_test.go`, `generate_multi_varying_ghost_test.go`,
`generate_multi_varying_long_test.go`, `generate_multi_varying_control_legacy_test.go`,
`generate_multi_mixed_shrink_base_test.go`, `generate_multi_mixed_shrink_control_test.go`,
`generate_multi_mixed_shrink_fuzz_test.go`, `generate_multi_mixed_shrink_conditional_test.go`,
`generate_multi_mixed_shrink_height_test.go`, `generate_multi_mixed_shrink_ghost_test.go`,
`generate_multi_mixed_shrink_long_test.go`, `generate_multi_mixed_shrink_tiny_test.go`,
`generate_single_styled_shrink_tiny_test.go` and `generate_multi_real_wrap_ghost_test.go`.

The `multi-script-*` fixtures compare superscript and subscript rich-text runs against the Go converter, including inherited sizes, wrapping, shrinking, narrow columns, and conditional formatting. `multi-script-legacy.json` covers all four formerly rejected inputs.

The `multi-base-script-*` fixtures also cover runs inheriting superscript or subscript from the cell font, alongside runs overriding it.

The `multi-repeated-props-*` fixtures verify that the first run font name and size are used when those properties repeat.

The `multi-repeated-children-*` fixtures verify that the first run text and properties elements take precedence when they repeat.

The `multi-large-font-*` and `single-large-font` fixtures cover run sizes of 1,000 and above in fixed-height rows, including wrapping, shrinking, and script formatting.

The `plain-table-*` fixtures cover unstyled tables, including header marks, filter buttons, overlapping ranges, data extraction and empty cells. Table ranges extend the sheet view even when they contain no cells. Custom styles with no effective elements and whole-table font styles are supported. Solid fills and fonts can be combined for one whole-table, header-row, total-row, first-column, last-column, corner-cell style element, paired stripe elements of the same axis, or whole-table, header-row and total-row elements together, or arbitrary combinations of those table regions within the supported table-area limit; cell, row and column fills take precedence. Overlapping tables use the first table. Font, solid fill and border differentials can be combined across custom table regions. The 60 built-in named table styles use the upstream preset definitions, and unknown style names produce the upstream warning.

Table processing follows the upstream per-sheet budget for cells absent from the file. Invalid table ranges are skipped, and missing table parts and supported malformed XML errors produce warnings while other tables continue to render.

Worksheets with empty drawing parts or anchors without drawable elements are converted, and missing drawing parts and supported malformed XML errors produce warnings. Up to 128 embedded PNG, JPEG, GIF, BMP, WebP, AVIF, or SVG rectangular pictures and rectangles with RGB or theme colors or no fill, optional opacity and solid-color outlines up to 20,000 points wide with preset dash patterns per sheet are supported, with at most 1 GiB of image data and 16,384 drawing tiles in total; each anchor may use two cells, one cell, or an absolute position, with cell offsets and absolute positions from -20,000 to 20,000 points, optional visibility, horizontal or vertical flips, rotations from -1,440 to 1,440 degrees, or paired nonnegative transform offsets and positive extents up to 20,000 points, transparency and fill insets, GIF, supported baseline or progressive JPEG, WebP with a VP8X, VP8L, or VP8 first chunk, and uncompressed 24- or 32-bit BMP cropping, and PNG cropping for non-paletted images with 8- or 16-bit samples and dimensions up to 1,000,000 pixels per side and edge percentages from -100% up to (but excluding) 100%, with each opposite pair totaling less than 100%, and row heights in quarter-point increments. SVG cropping supports files up to 4 MiB with positive decimal or scientific-notation width and height up to 1,000,000 pixels, with optional px, pt, pc, in, cm, mm, q, em, or ex units, or a numeric viewBox providing missing or percentage-specified dimensions. Crop rectangles for AVIF and SVG images without an intrinsic size are ignored as in the upstream converter. Theme-based rectangles reject theme alpha and alphaMod values outside 0–100%, and alphaOff values outside -100–100%. Pictures with effects other than transparency, other cropping, other shapes and drawing elements, and markup-compatibility alternatives remain unsupported. Picture fixtures are generated by the `generate_simple_picture*_test.go` and `generate_picture*_test.go` files; `generate_simple_picture_unsupported.py` and `generate_picture_unsupported_formats.py` construct unsupported variants. The image-format fixtures include upstream test images covered by the [upstream MIT license](../../licenses/Shibukawa-bdf.txt).

Conditional rules that reference absent differential styles leave formatting unchanged. Missing-style stopping rules follow priority for matched explicit cells. Stopping rules that match blanks remain unsupported when later formatting could be affected. Hexadecimal and underscored conditional style IDs, and unsupported priority representations in interacting stopping rules, are also rejected.
