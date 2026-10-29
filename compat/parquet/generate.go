// Generate fixtures from the pinned upstream checkout.
package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"github.com/shibukawa/bdf/encoding/parquet"
	"math"
	"os"
	"time"
)

func main() {
	tables := []*parquet.Table{
		{Columns: []parquet.Column{{Name: "empty", Type: parquet.String}}},
		{Columns: []parquet.Column{{Name: "名前", Type: parquet.String}, {Name: "number", Type: parquet.Number}, {Name: "integer", Type: parquet.Integer}, {Name: "bool", Type: parquet.Boolean}, {Name: "date", Type: parquet.Date}, {Name: "time", Type: parquet.DateTime}}, Rows: [][]any{
			{"日本語", math.Copysign(0, -1), int64(-123456789), true, time.Unix(-86400, 0), time.UnixMilli(-123456789)},
			{nil, 1.25, nil, false, time.Unix(19723*86400, 0), time.UnixMilli(1704067200123)},
			{"", nil, int64(9223372036854775807)},
			{nil, nil, nil, nil, time.Date(9999, 12, 31, 0, 0, 0, 0, time.UTC)},
			{nil, nil, nil, nil, time.Date(1, 1, 1, 0, 0, 0, 0, time.UTC)},
		}},
		{}, {},
		{Columns: []parquet.Column{{Name: "name", Type: parquet.String}, {Name: "amount", Type: parquet.Number}, {Name: "day", Type: parquet.Date}}, Rows: [][]any{
			{"Alice", float64(1), time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)},
			{"Bob", float64(2.5), time.Date(2024, 1, 2, 0, 0, 0, 0, time.UTC)},
		}},
	}
	for i := 0; i < 16; i++ {
		tables[2].Columns = append(tables[2].Columns, parquet.Column{Name: fmt.Sprintf("c%d", i), Type: parquet.Boolean})
	}
	row := []any{}
	for i := 0; i < 16; i++ {
		row = append(row, i%2 == 0)
	}
	tables[2].Rows = [][]any{row}
	tables[3].Columns = []parquet.Column{{Name: "flag", Type: parquet.Boolean}}
	for i := 0; i < 65538; i++ {
		if i%3 == 0 {
			tables[3].Rows = append(tables[3].Rows, []any{nil})
		} else {
			tables[3].Rows = append(tables[3].Rows, []any{i%2 == 0})
		}
	}
	result := []string{}
	for _, t := range tables {
		data, err := parquet.Encode(t)
		if err != nil {
			panic(err)
		}
		result = append(result, base64.StdEncoding.EncodeToString(data))
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		panic(err)
	}
}
