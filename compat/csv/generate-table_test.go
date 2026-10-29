// Copy this file into the pinned upstream converter/csv directory and run
// the named test with BDF_CSV_TABLE_FIXTURE set to the output file.
package csv

import (
	"encoding/json"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"
)

func TestGenerateTableFixture(t *testing.T) {
	path := os.Getenv("BDF_CSV_TABLE_FIXTURE")
	if path == "" {
		t.Skip("set BDF_CSV_TABLE_FIXTURE")
	}
	cases := []string{"0", "-0", "+0", "01", "+01", "1.5", ".5", "1.", "-0.0", "1e3", "1e9999", "1e-9999", "123456789012345678", "1234567890123456789", "2024-02-29", "2023-02-29", "0000-01-01", "9999-12-31", "1970-01-01T00:00:00Z", "1969-12-31T23:59:59.999Z", "2024-05-20T14:05:00.12345678912+09:00", "2024-04-01 09:30", "2024-04-01 09:30Z", "2024-04-01T09:30:00+0960", "2024-04-01 09:30:00+0960", "2024-04-01T09:30:00+24:60", "2024-04-01T24:00:00Z", "2024-04-01T09:30:60Z", "TRUE", "false", "00.1", " 12 ", "NaN", "Infinity"}
	type entry struct{ Input, Kind, Value string }
	result := []entry{}
	for _, value := range cases {
		kind := valueType(strings.TrimSpace(value))
		out := typedValue(kind, value)
		text := ""
		switch x := out.(type) {
		case time.Time:
			if kind.String() == "date" {
				text = strconv.FormatInt(x.Unix()/86400, 10)
			} else {
				text = strconv.FormatInt(x.UnixMilli(), 10)
			}
		case string:
			text = x
		case bool:
			text = strconv.FormatBool(x)
		case int64:
			text = strconv.FormatInt(x, 10)
		case float64:
			text = strconv.FormatFloat(x, 'g', -1, 64)
		}
		result = append(result, entry{value, kind.String(), text})
	}
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	enc := json.NewEncoder(file)
	enc.SetIndent("", "  ")
	if err = enc.Encode(result); err != nil {
		t.Fatal(err)
	}
}
