//go:build ignore

// Overlay without this build tag into converter/internal/ooxml/drawingml when
// generating presentation fixtures, so the actual upstream parser is tested.
package drawingml

import "github.com/shibukawa/bdf/converter/internal/ooxml"

func CodexShapeTransform(n *ooxml.Node) (float64, float64, float64, float64, float64, bool, bool, bool) {
	x, ok := parseXfrm(ownXfrm(n))
	return x.X, x.Y, x.W, x.H, x.Rot, x.FlipH, x.FlipV, ok
}
