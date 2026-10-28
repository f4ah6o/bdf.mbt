"""Create a tiny synthetic font for the visual fixture (fonttools 4.60.2)."""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

font = FontBuilder(1000, isTTF=True)
font.setupGlyphOrder([".notdef", "A"])
font.setupCharacterMap({ord("A"): "A"})
empty = TTGlyphPen(None).glyph()
pen = TTGlyphPen(None)
pen.moveTo((50, 0))
pen.lineTo((350, 750))
pen.lineTo((650, 0))
pen.closePath()
pen.moveTo((280, 200))
pen.lineTo((420, 200))
pen.lineTo((350, 450))
pen.closePath()
font.setupGlyf({".notdef": empty, "A": pen.glyph()})
font.setupHorizontalMetrics({".notdef": (700, 0), "A": (700, 50)})
font.setupHorizontalHeader(ascent=800, descent=-200)
font.setupNameTable({"familyName": "BDF Synthetic", "styleName": "Regular"})
font.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
font.setupPost()
font.setupMaxp()
font.font["head"].created = 2082844800
font.font["head"].modified = 2082844800
font.font.recalcTimestamp = False
font.save(Path(__file__).with_name("synthetic.ttf"))
