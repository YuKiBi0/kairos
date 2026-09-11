package app

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

type ServerProfile struct {
	URL           string `json:"url"`
	VerifyTLS     bool   `json:"verify_tls"`
	CAFile        string `json:"ca_file,omitempty"`
	DefaultRunner string `json:"default_runner,omitempty"`
}

type Config struct {
	CurrentServer    string                   `json:"current_server,omitempty"`
	CurrentWorkspace string                   `json:"current_workspace,omitempty"`
	Servers          map[string]ServerProfile `json:"servers"`
}

func configDir() string {
	if runtime.GOOS == "windows" {
		if value := os.Getenv("APPDATA"); value != "" {
			return filepath.Join(value, "Kairos")
		}
		if value := os.Getenv("USERPROFILE"); value != "" {
			return filepath.Join(value, "AppData", "Roaming", "Kairos")
		}
	}
	if value := os.Getenv("XDG_CONFIG_HOME"); value != "" {
		return filepath.Join(value, "kairos")
	}
	if home, err := os.UserHomeDir(); err == nil {
		return filepath.Join(home, ".config", "kairos")
	}
	return ".kairos"
}

func configPath() string { return filepath.Join(configDir(), "config.yaml") }

func LoadConfig() (Config, error) {
	config := Config{Servers: map[string]ServerProfile{}}
	data, err := os.ReadFile(configPath())
	if errors.Is(err, os.ErrNotExist) {
		return config, nil
	}
	if err != nil {
		return config, err
	}
	if err := json.Unmarshal(data, &config); err != nil {
		if err := parseYAMLConfig(string(data), &config); err != nil {
			return config, fmt.Errorf("invalid config: %w", err)
		}
	}
	if config.Servers == nil {
		config.Servers = map[string]ServerProfile{}
	}
	return config, nil
}

func SaveConfig(config Config) error {
	if config.Servers == nil {
		config.Servers = map[string]ServerProfile{}
	}
	if err := os.MkdirAll(configDir(), 0o700); err != nil {
		return err
	}
	return os.WriteFile(configPath(), []byte(formatYAMLConfig(config)), 0o600)
}

func parseYAMLConfig(content string, config *Config) error {
	if config.Servers == nil {
		config.Servers = map[string]ServerProfile{}
	}
	section := ""
	current := ""
	for _, raw := range strings.Split(content, "\n") {
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			return errors.New("invalid YAML line")
		}
		key, value := strings.TrimSpace(parts[0]), strings.TrimSpace(parts[1])
		value = strings.Trim(value, "\"'")
		indent := len(raw) - len(strings.TrimLeft(raw, " \t"))
		if indent == 0 {
			section = key
			current = ""
			switch key {
			case "current_server":
				config.CurrentServer = value
			case "current_workspace":
				config.CurrentWorkspace = value
			case "servers":
			case "":
			default:
				return fmt.Errorf("unknown config key %q", key)
			}
			continue
		}
		if section != "servers" {
			continue
		}
		if indent <= 2 {
			current = key
			profile := config.Servers[current]
			config.Servers[current] = profile
			continue
		}
		if current == "" {
			return errors.New("server field without profile")
		}
		profile := config.Servers[current]
		switch key {
		case "url":
			profile.URL = value
		case "verify_tls":
			profile.VerifyTLS = value == "true"
		case "ca_file":
			if value != "null" {
				profile.CAFile = value
			}
		case "default_runner":
			profile.DefaultRunner = value
		default:
			return fmt.Errorf("unknown server key %q", key)
		}
		config.Servers[current] = profile
	}
	return nil
}

func formatYAMLConfig(config Config) string {
	var b strings.Builder
	if config.CurrentServer != "" {
		fmt.Fprintf(&b, "current_server: %s\n", config.CurrentServer)
	}
	if config.CurrentWorkspace != "" {
		fmt.Fprintf(&b, "current_workspace: %s\n", config.CurrentWorkspace)
	}
	b.WriteString("servers:\n")
	for name, profile := range config.Servers {
		fmt.Fprintf(&b, "  %s:\n    url: %s\n    verify_tls: %t\n", name, profile.URL, profile.VerifyTLS)
		if profile.CAFile == "" {
			b.WriteString("    ca_file: null\n")
		} else {
			fmt.Fprintf(&b, "    ca_file: %s\n", profile.CAFile)
		}
		if profile.DefaultRunner != "" {
			fmt.Fprintf(&b, "    default_runner: %s\n", profile.DefaultRunner)
		}
	}
	return b.String()
}

func resolveServer(config Config, requested string) (string, ServerProfile, error) {
	name := requested
	if name == "" && os.Getenv("KAIROS_SERVER_URL") != "" {
		value := strings.TrimRight(strings.TrimSpace(os.Getenv("KAIROS_SERVER_URL")), "/")
		if !strings.HasPrefix(value, "http://") && !strings.HasPrefix(value, "https://") {
			return "", ServerProfile{}, &CLIError{Code: "INVALID_URL", Message: "KAIROS_SERVER_URL 必须以 http:// 或 https:// 开头", ExitCode: ExitUsage}
		}
		return "env", ServerProfile{URL: value, VerifyTLS: strings.HasPrefix(value, "https://")}, nil
	}
	if name == "" {
		name = os.Getenv("KAIROS_SERVER")
	}
	if name == "" {
		name = config.CurrentServer
	}
	if name == "" && len(config.Servers) == 1 {
		for key := range config.Servers {
			name = key
		}
	}
	if name == "" {
		return "", ServerProfile{}, &CLIError{Code: "CONFIG_REQUIRED", Message: "未配置服务，请先运行 kairos server add", ExitCode: ExitUsage}
	}
	profile, ok := config.Servers[name]
	if !ok || strings.TrimSpace(profile.URL) == "" {
		return "", ServerProfile{}, &CLIError{Code: "SERVER_NOT_FOUND", Message: "服务 Profile 不存在: " + name, ExitCode: ExitUsage}
	}
	return name, profile, nil
}
