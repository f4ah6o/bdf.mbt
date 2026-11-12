#!/bin/sh
# Same-renderer AWS parity oracle: converts site/samples/aws.drawio with the
# upstream Go converter (single renderer for both sides) and the MoonBit js
# worker, renders both, and checks the drawn group-label coordinates
# (FILL_TEXT/TRANSLATE) of the page-1 object. Old label spacing (2pt) fails
# the assertions; the ported directional spacing (spacingLeft=30 + base 2)
# passes. Env: REPO UPSTREAM OUT (optional overrides).
set -e
REPO=${REPO:-"$(cd "$(dirname "$0")/../.." && pwd)"}
: "${UPSTREAM:?Set UPSTREAM to a shibukawa/bdf checkout}"
UPSTREAM=$(cd "$UPSTREAM" && pwd)
OUT=${OUT:-/tmp/bdforacle}
SAMPLE="$REPO/site/samples/aws.drawio"
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
git -C "$UPSTREAM" rev-parse HEAD > "$OUT/upstream-sha.txt"
(cd "$UPSTREAM" && go build -o "$OUT/bdf" ./cmd/bdf)
cd "$REPO"
moon build --target js native_converter_worker >/dev/null
WORKER_TARGET="$REPO/_build/js/debug/build/native_converter_worker/native_converter_worker.js" \
INPUT="$SAMPLE" OUTPUT="$OUT/aws_moon.bdf" node "$REPO/compat/drawio/oracle-worker.mjs"
"$OUT/bdf" generate -format drawio "$SAMPLE" "$OUT/aws_go.bdf"
"$OUT/bdf" render "$OUT/aws_go.bdf" "$OUT/go.png"
"$OUT/bdf" render "$OUT/aws_moon.bdf" "$OUT/moon.png"
PAGE_HASH=$("$OUT/bdf" ls "$OUT/aws_moon.bdf" | awk '$2=="obj"{print $1; exit}')
"$OUT/bdf" disasm "$OUT/aws_moon.bdf" "$PAGE_HASH" > "$OUT/moon_page1.asm"
TX_CLOUD=$(awk '/^  TRANSLATE/{tx=$2}/FILL_TEXT "AWS Cloud"/{print tx; exit}' "$OUT/moon_page1.asm")
TX_REGION=$(awk '/^  TRANSLATE/{tx=$2}/FILL_TEXT "Region"/{print tx; exit}' "$OUT/moon_page1.asm")
echo "moon TRANSLATE  AWS Cloud=$TX_CLOUD  Region=$TX_REGION"
# The group labels carry spacingLeft=30 (+2 base): they sit ~32pt inside their
# group frames, at TRANSLATE 104/119 in this page frame. The pre-fix label
# spacing (2pt) drew them at 81.5/96.5, inside the 30-unit corner icon.
awk -v c="$TX_CLOUD" -v r="$TX_REGION" \
  'BEGIN { if (c < 100 || c > 110) { print "FAIL: AWS Cloud label at " c " (expected ~104, pre-fix 81.5)"; exit 1 }
           if (r < 115 || r > 125) { print "FAIL: Region label at " r " (expected ~119, pre-fix 96.5)"; exit 1 }
           print "OK: group labels clear the 30-unit corner icon (pre-fix x=81.5/96.5 failed here)" }'
echo "saved: $OUT/{aws_go.bdf,aws_moon.bdf,go.png,moon.png,moon_page1.asm}"
