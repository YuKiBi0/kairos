package envfile

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Load parses a dotenv-style file and overwrites the current process environment.
func Load(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("open environment file %q: %w", path, err)
	}
	defer file.Close()

	values := make(map[string]string)
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 4096), 1024*1024)
	lineNumber := 0
	for scanner.Scan() {
		lineNumber++
		line := strings.TrimSpace(strings.TrimPrefix(scanner.Text(), "\ufeff"))
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "export ") {
			line = strings.TrimSpace(strings.TrimPrefix(line, "export "))
		}

		key, rawValue, found := strings.Cut(line, "=")
		key = strings.TrimSpace(key)
		if !found || !validKey(key) {
			return fmt.Errorf("parse environment file %q line %d: expected NAME=value", path, lineNumber)
		}
		value, err := parseValue(strings.TrimSpace(rawValue))
		if err != nil {
			return fmt.Errorf("parse environment file %q line %d: %w", path, lineNumber, err)
		}
		values[key] = value
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read environment file %q: %w", path, err)
	}

	for key, value := range values {
		if err := os.Setenv(key, value); err != nil {
			return fmt.Errorf("set %s from environment file: %w", key, err)
		}
	}
	return nil
}

func validKey(key string) bool {
	if key == "" || !(key[0] == '_' || isLetter(key[0])) {
		return false
	}
	for index := 1; index < len(key); index++ {
		character := key[index]
		if character != '_' && !isLetter(character) && (character < '0' || character > '9') {
			return false
		}
	}
	return true
}

func isLetter(character byte) bool {
	return character >= 'a' && character <= 'z' || character >= 'A' && character <= 'Z'
}

func parseValue(raw string) (string, error) {
	if raw == "" || strings.HasPrefix(raw, "#") {
		return "", nil
	}
	if raw[0] == '\'' {
		if len(raw) < 2 || raw[len(raw)-1] != '\'' {
			return "", fmt.Errorf("unterminated single-quoted value")
		}
		return raw[1 : len(raw)-1], nil
	}
	if raw[0] == '"' {
		if len(raw) < 2 || raw[len(raw)-1] != '"' {
			return "", fmt.Errorf("unterminated double-quoted value")
		}
		value, err := strconv.Unquote(raw)
		if err != nil {
			return "", fmt.Errorf("invalid double-quoted value: %w", err)
		}
		return value, nil
	}
	return strings.TrimSpace(stripInlineComment(raw)), nil
}

func stripInlineComment(raw string) string {
	for index := 1; index < len(raw); index++ {
		if raw[index] == '#' && (raw[index-1] == ' ' || raw[index-1] == '\t') {
			return raw[:index]
		}
	}
	return raw
}
