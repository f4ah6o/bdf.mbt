Test fonts for the Word converter: subsets of M PLUS 1p Regular and Bold
(https://github.com/google/fonts/tree/main/ofl/mplus1p, SIL Open Font
License 1.1, see OFL.txt) holding ASCII, Latin-1, general punctuation,
arrows, geometric shapes, circled numbers, kana, CJK punctuation, the
vertical forms (U+FE10–FE19, of which the font has only a few), the
full-width forms and the characters the test documents use. The tests and
testdata/docx lay text out with these fonts only (-font-dir testdata/fonts
-no-system-fonts), so the output does not depend on the fonts installed on
the machine. Every family the documents ask for (Century, Arial, 游明朝 …)
falls back to them.

Made with fontTools, chars.txt holding the ranges above and the characters
of converter/docx/testdata/*.docx:

    pyftsubset MPLUS1p-Regular.ttf --text-file=chars.txt --layout-features='*' \
      --no-hinting --name-IDs='*' --name-languages='*' --output-file=MPLUS1p-Regular-subset.ttf

The form-label characters 細・価・総・量・金・額 were appended from the
matching M PLUS 1p 1.062 sources, preserving existing glyph IDs, outlines
and metrics. See the extension procedure in
converter/pptx/testdata/fonts/README.md; OFL.txt still applies.

STIXTwoMath-subset.ttf is the formula font of the tests (math.docx, and the
Markdown and HTML tests that lay text out with this directory): a subset of
STIX Two Math 2.13 b171 (https://github.com/stipub/stixfonts, the TrueType
build, SIL Open Font License 1.1, see OFL-STIX.txt) that keeps its MATH
table (constants, italic corrections, accent positions, and the larger
variants and parts of the glyphs kept). It holds ASCII, Latin-1, Greek, the
combining accents formulas use, general punctuation, letterlike symbols,
arrows, mathematical operators, brackets and their parts, and the italic,
bold, script, fraktur and double-struck letters. Made with fontTools:

    pyftsubset STIXTwoMath-Regular.ttf --unicodes-file=unicodes.txt --layout-features='' --no-hinting \
      --name-IDs='*' --name-languages='*' --drop-tables+=GSUB,GPOS,GDEF --output-file=STIXTwoMath-subset.ttf

with unicodes.txt:

    U+0020-007E,U+00A0-00FF,U+0131,U+0237,U+02C6,U+02C7,U+02D8-02DC
    U+0300-0308,U+030A,U+030C,U+0332,U+0338
    U+0391-03A9,U+03B1-03C9,U+03D1,U+03D5,U+03D6,U+03F0,U+03F1,U+03F5
    U+2000-200B,U+2016,U+2020-2026,U+2032-2037,U+2057,U+2061-2064,U+20D6,U+20D7,U+20E1
    U+2102,U+2107,U+210B-2113,U+2115,U+2118-211D,U+2124,U+2127,U+2128,U+212C,U+212D,U+212F-2131,U+2133-2138
    U+2190-2199,U+21A6,U+21A9,U+21AA,U+21BC-21C4,U+21CC,U+21D0-21D5
    U+2200-22FF,U+2308-230B,U+2322,U+2323,U+239B-23B7,U+23DC-23E1
    U+25A1,U+25B3,U+25B7,U+25BD,U+25C1,U+25CB,U+25EF
    U+27E6-27EF,U+27F5-27FF,U+2983-2986,U+2997,U+2998
    U+2A00-2A0C,U+2A2F,U+2A7D,U+2A7E
    U+1D400-1D49B,U+1D49C-1D4CF,U+1D504-1D56B,U+1D6A4,U+1D6A5,U+1D6E2-1D71B,U+1D7CE-1D7D7
