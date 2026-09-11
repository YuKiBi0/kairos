package app

import (
	"encoding/json"
	"fmt"
	"io"
	"strings"
)

type Output struct {
	Mode  string
	Quiet bool
	Out   io.Writer
	Err   io.Writer
}

func (o Output) JSON(value any) error {
	if o.Quiet && o.Mode == "table" {
		return nil
	}
	if o.Mode == "ndjson" {
		return o.line(value)
	}
	return json.NewEncoder(o.Out).Encode(value)
}

func (o Output) line(value any) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintln(o.Out, string(data))
	return err
}

func (o Output) Table(headers []string, rows [][]string) error {
	if o.Quiet {
		return nil
	}
	widths := make([]int, len(headers))
	for i, h := range headers {
		widths[i] = len([]rune(h))
	}
	for _, row := range rows {
		for i, cell := range row {
			if i < len(widths) && len([]rune(cell)) > widths[i] {
				widths[i] = len([]rune(cell))
			}
		}
	}
	writeRow := func(row []string) {
		for i, cell := range row {
			if i > 0 {
				_, _ = fmt.Fprint(o.Out, "  ")
			}
			_, _ = fmt.Fprintf(o.Out, "%-*s", widths[i], cell)
		}
		_, _ = fmt.Fprintln(o.Out)
	}
	writeRow(headers)
	sep := make([]string, len(headers))
	for i, width := range widths {
		sep[i] = strings.Repeat("-", width)
	}
	writeRow(sep)
	for _, row := range rows {
		writeRow(row)
	}
	return nil
}
