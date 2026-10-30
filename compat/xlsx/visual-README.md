# XLSX table decoration visual regression

`npm run test:xlsx-visual` compares four existing Go-generated XLSX/BDF fixture pairs. Run `moon build --target js` and install Playwright Chromium first. The upstream 0.2.1 JavaScript renderer draws the Go-converted BDF as the reference. The first variant draws the MoonBit-converted BDF using that same renderer; the second uses the MoonBit sheet renderer with MoonBit-converted BDF. This separates conversion differences from end-to-end rendering differences. Both paths use the same 560×145 sheet region and scale 1.

| Fixture and index | Focus |
| --- | --- |
| `plain-table-whole-paired-row-stripe-style-plain.json` 4 | Whole-table and paired row stripes, including empty cells |
| `plain-table-whole-paired-column-stripe-style-plain.json` 4 | Whole-table and paired column stripes, including empty cells |
| `plain-table-whole-paired-row-stripe-style-mixed.json` 10 | Stripe font/fill combination and explicit cell formatting |
| `plain-table-multi-whole-paired-stripe-style.json` 6 | Overlapping tables, merged cells, row/column styles and conditional formatting |

The tests check rendering readiness and colored pixels for every case, then use VLMKit screenshots and exact RGBA comparisons at its wide, desktop, and mobile viewport sizes. Reports are written under `_build/visual-diff/` and uploaded by Visual CI on failure. The desktop and wide views include the full 560-pixel sheet region; the mobile screenshot clips the right side. This is a regression sample, not an exhaustive visual proof or a comparison against Excel. The underlying fixture generators and broader BDF structure comparisons are documented in `README.md` and `verify-render.mjs`.
