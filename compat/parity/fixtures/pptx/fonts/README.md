Test fonts for the PowerPoint converter: subsets of M PLUS 1p Regular and
Bold (https://github.com/google/fonts/tree/main/ofl/mplus1p, SIL Open Font
License 1.1, see OFL.txt) holding ASCII, Latin-1, kana, CJK punctuation and
the characters the test decks use. The tests and testdata/pptx lay text out with
these fonts only (-font-dir testdata/fonts -no-system-fonts), so the output
does not depend on the fonts installed on the machine.

Made with fontTools:

    pyftsubset MPLUS1p-Regular.ttf --text-file=chars.txt --layout-features='*' \
      --no-hinting --name-IDs='*' --name-languages='*' --output-file=MPLUS1p-Regular-subset.ttf

The form labels also need 細・価・総・量・金・額. To extend the existing
subsets, use the matching M PLUS 1p 1.062 Regular/Bold files from Google
Fonts and fontTools: keep the current glyph order and tables, append the
six missing glyphs (without hinting) with their horizontal and vertical
metrics, and add them to the Unicode cmap. Disable timestamp and bounding
box recalculation. This preserves every existing glyph ID, outline and
advance; the cmap becomes its previous character set plus these six.
The Word test fonts were extended in the same way. OFL.txt still applies.

STIXTwoMath-subset.ttf is the formula font of the equations in math.pptx and
math.xlsx: the same subset of STIX Two Math, with its MATH table, as in
converter/docx/testdata/fonts (SIL Open Font License 1.1, see OFL-STIX.txt;
how it was made is described there). No other test document uses it: the
characters they draw are in M PLUS 1p, so their output does not change.
