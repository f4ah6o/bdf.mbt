//go:build ignore

// Generates the inline fixtures of convert/xlsx/font_metrics_wbtest.mbt.
//
// The two TrueType faces ("Metrics Fixture", and a digit-less variant) are
// built with upstream's own container builder, internal/sfnt.Build, like
// compat/font/generate-synthetic.go, so the SFNT header, table directory,
// per-table checksums and the head checkSumAdjustment come from the
// reference implementation rather than this file. Each face also validates
// through internal/sfnt.Parse before it is printed. The faces carry no
// external data and have empty outlines; their digits measure 500/1000 em
// and every other character 600/1000 em, so at the workbooks' default size
// 11 the MDW is 8 with the whole-pixel ppem of ordinary fonts and 7 with
// the unrounded Calibri/Carlito ppem. The digit-less face leaves the
// digits unmapped, so their advances fall back to the estimated 0.55 em.
//
// The three workbooks (default font "Metrics Fixture" or "Calibri",
// strings in columns A, B and C indented 0, 1 and 2 levels, one
// fixed-height row) are minimal packages; "metrics" and "calibri" give
// column A width 10, "defaults" instead sets sheetFormatPr defaultColWidth
// 8.5 so the default-column axis carries a measured width.
//
// Copy this file into an upstream checkout (github.com/shibukawa/bdf,
// a5e4d7a6) without its build tag, as cmd/metricsfont/main.go, then from
// the module root run:
//
//	go run ./cmd/metricsfont
//
// which validates each face through internal/sfnt.Parse before printing
// it. The fixtures used here were also cross-checked once with a
// golang.org/x/image/font/sfnt program, outside this generator.
// which prints the five base64 values to paste into the wbtest.
package main

import (
	"archive/zip"
	"bytes"
	"encoding/base64"
	"fmt"

	"github.com/shibukawa/bdf/internal/sfnt"
)

type be struct{ bytes.Buffer }

func (b *be) u16(v uint16) { b.Write([]byte{byte(v >> 8), byte(v)}) }
func (b *be) i16(v int16)  { b.u16(uint16(v)) }
func (b *be) u32(v uint32) {
	b.Write([]byte{byte(v >> 24), byte(v >> 16), byte(v >> 8), byte(v)})
}

// glyph 0 is .notdef; glyphs 1..95 map characters 0x20..0x7E.
func glyphIndex(c int) int { return c - 0x1f }

// faceTables assembles the raw tables of one face. Without mapDigits the
// cmap leaves the digits unmapped.
func faceTables(mapDigits bool) map[string][]byte {
	const upem = 1000
	const glyphs = 96

	// head: 54 bytes. The checkSumAdjustment field stays zero here;
	// sfnt.Build writes it once the container is laid out.
	var head be
	head.u32(0x00010000)         // version
	head.u32(0x00010000)         // fontRevision
	head.u32(0)                  // checkSumAdjustment
	head.u32(0x5F0F3CF5)         // magicNumber
	head.u16(0)                  // flags
	head.u16(upem)               // unitsPerEm (offset 18)
	head.Write(make([]byte, 16)) // created, modified
	head.i16(0)                  // xMin
	head.i16(-200)               // yMin
	head.i16(1000)               // xMax
	head.i16(800)                // yMax
	head.u16(0)                  // macStyle
	head.u16(8)                  // lowestRecPPEM
	head.i16(2)                  // fontDirectionHint
	head.i16(0)                  // indexToLocFormat: short (offset 50)
	head.i16(0)                  // glyphDataFormat

	// maxp 1.0: exactly 32 bytes, as x/image/font/sfnt requires.
	var maxp be
	maxp.u32(0x00010000)
	maxp.u16(glyphs)
	maxp.Write(make([]byte, 26))

	// hhea: 36 bytes.
	var hhea be
	hhea.u32(0x00010000)
	hhea.i16(800)               // ascender
	hhea.i16(-200)              // descender
	hhea.i16(0)                 // lineGap
	hhea.u16(1000)              // advanceWidthMax
	hhea.i16(0)                 // minLeftSideBearing
	hhea.i16(0)                 // minRightSideBearing
	hhea.i16(1000)              // xMaxExtent
	hhea.i16(1)                 // caretSlopeRise
	hhea.i16(0)                 // caretSlopeRun
	hhea.i16(0)                 // caretOffset
	hhea.Write(make([]byte, 8)) // four reserved int16 fields
	hhea.i16(0)                 // metricDataFormat
	hhea.u16(glyphs)            // numberOfHMetrics (offset 34)

	// hmtx: digits (glyphs 17..26) measure 500, space 250, the rest 600.
	var hmtx be
	for g := 0; g < glyphs; g++ {
		advance := uint16(600)
		switch {
		case g == 0:
			advance = 500
		case g == glyphIndex(0x20):
			advance = 250
		case g >= glyphIndex('0') && g <= glyphIndex('9'):
			advance = 500
		}
		hmtx.u16(advance)
		hmtx.i16(0) // leftSideBearing
	}

	// cmap: a (3, 1) format-4 subtable via the reference builder.
	characters := map[uint32]uint16{}
	for c := 0x20; c <= 0x7E; c++ {
		digits := c >= '0' && c <= '9'
		if mapDigits || !digits {
			characters[uint32(c)] = uint16(glyphIndex(c))
		}
	}
	cmap := sfnt.BuildCmap(characters)

	// glyf and loca: every glyph is empty.
	glyf := make([]byte, 16)
	var loca be
	for i := 0; i <= glyphs; i++ {
		loca.u16(0)
	}

	// name: family, subfamily, full and PostScript names. Windows platform
	// records take UTF-16BE strings.
	names := []struct {
		id    int
		value string
	}{
		{1, "Metrics Fixture"},
		{2, "Regular"},
		{4, "Metrics Fixture Regular"},
		{6, "MetricsFixture-Regular"},
	}
	var storage be
	type record struct{ id, length, offset uint16 }
	records := make([]record, len(names))
	for i, n := range names {
		records[i] = record{uint16(n.id), uint16(2 * len(n.value)), uint16(storage.Len())}
		for _, r := range n.value {
			storage.u16(uint16(r))
		}
	}
	var name be
	name.u16(0) // format
	name.u16(uint16(len(records)))
	name.u16(uint16(6 + 12*len(records))) // stringOffset
	for _, r := range records {
		name.u16(3) // platform: Windows
		name.u16(1) // encoding: Unicode BMP
		name.u16(0x409)
		name.u16(r.id)
		name.u16(r.length)
		name.u16(r.offset)
	}
	name.Write(storage.Bytes())

	// OS/2 v4: 96 bytes, installable embedding (fsType 0).
	var os2 be
	os2.u16(4)                  // version
	os2.i16(500)                // xAvgCharWidth
	os2.u16(400)                // usWeightClass
	os2.u16(5)                  // usWidthClass
	os2.u16(0)                  // fsType (offset 8)
	os2.Write(make([]byte, 20)) // subscript and superscript (16), strikeout size and position (4)
	os2.i16(0)                  // sFamilyClass
	os2.Write(make([]byte, 10)) // panose
	os2.u32(0x3)                // ulUnicodeRange1: Latin 1
	os2.u32(0)                  // ulUnicodeRange2
	os2.u32(0)                  // ulUnicodeRange3
	os2.u32(0)                  // ulUnicodeRange4
	os2.Write([]byte("MFTR"))   // achVendID
	os2.u16(0x40)               // fsSelection: regular
	os2.u16(0x20)               // usFirstCharIndex
	os2.u16(0x7E)               // usLastCharIndex
	os2.i16(800)                // sTypoAscender
	os2.i16(-200)               // sTypoDescender
	os2.i16(0)                  // usTypoLineGap
	os2.u16(800)                // usWinAscent (offset 74)
	os2.u16(200)                // usWinDescent (offset 76)
	os2.u32(0)                  // ulCodePageRange1
	os2.u32(0)                  // ulCodePageRange2
	os2.i16(700)                // sxHeight
	os2.i16(700)                // sCapHeight (offset 88)
	os2.u16(0x20)               // usDefaultChar
	os2.u16(0x20)               // usBreakChar
	os2.u16(1)                  // usMaxContext

	// post 3.0: 32 bytes; italicAngle is a 16.16 fixed value.
	var post be
	post.u32(0x00030000)
	post.u32(0)    // italicAngle: Fixed 0
	post.i16(-100) // underlinePosition
	post.i16(50)   // underlineThickness
	post.u32(0)    // isFixedPitch
	post.u32(0)    // minMemType42
	post.u32(0)    // maxMemType42
	post.u32(0)    // minMemType1
	post.u32(0)    // maxMemType1

	return map[string][]byte{
		"OS/2": os2.Bytes(),
		"cmap": cmap,
		"glyf": glyf,
		"head": head.Bytes(),
		"hhea": hhea.Bytes(),
		"hmtx": hmtx.Bytes(),
		"loca": loca.Bytes(),
		"maxp": maxp.Bytes(),
		"name": name.Bytes(),
		"post": post.Bytes(),
	}
}

// buildFace builds one face with the reference container builder and
// validates it with the reference parser: the digit advances, the Windows
// ascent and descent, and the number of mapped characters.
func buildFace(mapDigits bool) []byte {
	font := sfnt.Build(faceTables(mapDigits), false)
	parsed, err := sfnt.Parse(font)
	if err != nil {
		panic(err)
	}
	wantMapped := 85
	if mapDigits {
		wantMapped = 95
	}
	if len(parsed.Cmap) != wantMapped {
		panic(fmt.Sprintf("mapped characters %d, want %d", len(parsed.Cmap), wantMapped))
	}
	digits := 0
	for c := '0'; c <= '9'; c++ {
		if g, ok := parsed.Cmap[uint32(c)]; ok && g > 0 {
			if a := int(parsed.Advances[g]); a != 500 {
				panic(fmt.Sprintf("digit %c advance %d", c, a))
			}
			digits++
		}
	}
	wantDigits := 0
	if mapDigits {
		wantDigits = 10
	}
	if digits != wantDigits {
		panic(fmt.Sprintf("mapped digits %d, want %d", digits, wantDigits))
	}
	if parsed.Ascent != 800 {
		panic(fmt.Sprintf("ascent %d", parsed.Ascent))
	}
	return font
}

func sheetXML(defaultColWidth string, explicitColA bool) string {
	sheet := `<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">`
	if defaultColWidth != "" {
		sheet += `<sheetFormatPr defaultColWidth="` + defaultColWidth + `" defaultRowHeight="15"/>`
	}
	if explicitColA {
		sheet += `<cols><col min="1" max="1" width="10" customWidth="1"/></cols>`
	}
	sheet += `<sheetData><row r="1" ht="30" customHeight="1">` +
		`<c r="A1" t="inlineStr"><is><t>a</t></is></c>` +
		`<c r="B1" s="1" t="inlineStr"><is><t>b</t></is></c>` +
		`<c r="C1" s="2" t="inlineStr"><is><t>c</t></is></c>` +
		`</row></sheetData></worksheet>`
	return sheet
}

func workbook(defaultFont, defaultColWidth string, explicitColA bool) []byte {
	styles := `<styleSheet><fonts count="1"><font><name val="` + defaultFont + `"/><sz val="11"/></font></fonts>` +
		`<cellXfs count="3"><xf numFmtId="0" fontId="0"/>` +
		`<xf numFmtId="0" fontId="0" applyAlignment="1"><alignment horizontal="left" indent="1"/></xf>` +
		`<xf numFmtId="0" fontId="0" applyAlignment="1"><alignment horizontal="left" indent="2"/></xf>` +
		`</cellXfs></styleSheet>`
	files := []struct{ name, body string }{
		{"xl/workbook.xml", `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" r:id="r1"/></sheets></workbook>`},
		{"xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="rStyles" Type="x/styles" Target="styles.xml"/><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/></Relationships>`},
		{"xl/styles.xml", styles},
		{"xl/worksheets/sheet1.xml", sheetXML(defaultColWidth, explicitColA)},
	}
	var buf bytes.Buffer
	z := zip.NewWriter(&buf)
	for _, f := range files {
		w, err := z.Create(f.name)
		if err != nil {
			panic(err)
		}
		if _, err := w.Write([]byte(f.body)); err != nil {
			panic(err)
		}
	}
	if err := z.Close(); err != nil {
		panic(err)
	}
	return buf.Bytes()
}

func main() {
	fmt.Println("font     ", base64.StdEncoding.EncodeToString(buildFace(true)))
	fmt.Println("nodigits ", base64.StdEncoding.EncodeToString(buildFace(false)))
	fmt.Println("metrics  ", base64.StdEncoding.EncodeToString(workbook("Metrics Fixture", "", true)))
	fmt.Println("calibri  ", base64.StdEncoding.EncodeToString(workbook("Calibri", "", true)))
	fmt.Println("defaults ", base64.StdEncoding.EncodeToString(workbook("Metrics Fixture", "8.5", false)))
}
