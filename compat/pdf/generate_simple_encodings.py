#!/usr/bin/env python3
"""Generate PDF simple-font encodings from the upstream MIT-licensed tables."""
import argparse
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("upstream", type=Path, help="path to the upstream bdf checkout")
parser.add_argument("output", type=Path, help="MoonBit output file")
args = parser.parse_args()
inputs = [
    ("pdf_standard_encoding", args.upstream / "internal/cff/encoding.go", "StandardEncoding"),
    ("pdf_win_ansi_encoding", args.upstream / "converter/pdf/encodings.go", "winAnsiEncoding"),
    ("pdf_mac_roman_encoding", args.upstream / "converter/pdf/encodings.go", "macRomanEncoding"),
]
lines = ["///|", "// Generated from upstream PDF and CFF encoding tables (MIT)."]
for target, path, source in inputs:
    text = path.read_text()
    match = re.search(r"var\s+" + source + r"\s*=\s*\[256\]string\s*\{(.*?)\n\}", text, re.S)
    if not match:
        raise ValueError(f"missing encoding {source} in {path}")
    values = re.findall(r'"(?:\\.|[^"\\])*"', match.group(1))
    if len(values) != 256:
        raise ValueError(f"{source}: expected 256 entries, got {len(values)}")
    lines.extend(["///|", f"let {target} : Array[String] = ["])
    lines.extend(f"  {json.dumps(json.loads(value), ensure_ascii=False)}," for value in values)
    lines.append("]")
args.output.write_text("\n".join(lines) + "\n")
