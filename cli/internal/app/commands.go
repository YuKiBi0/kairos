package app

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/signal"
	"runtime"
	"sort"
	"strings"
	"syscall"
	"time"
)

const cliVersion = "1.0.0"

type options struct {
	server, workspace, output   string
	quiet, noColor, insecure    bool
	allowEncryptedFile          bool
	requestTimeout, waitTimeout time.Duration
	out                         Output
}

func Run(args []string, stdout, stderr io.Writer) int {
	opts, rest, err := parseGlobal(args)
	opts.out = Output{Mode: opts.output, Quiet: opts.quiet, Out: stdout, Err: stderr}
	if err != nil {
		writeError(opts.out, asCLIError(err))
		return ExitUsage
	}
	if opts.insecure {
		if err := validateInsecure(stderr); err != nil {
			writeError(opts.out, asCLIError(err))
			return ExitUsage
		}
	}
	if len(rest) == 0 || rest[0] == "help" {
		printHelp(stdout)
		return ExitOK
	}
	if rest[0] == "version" {
		_, _ = fmt.Fprintf(stdout, "kairos %s (protocol v3)\n", cliVersion)
		return ExitOK
	}
	err = dispatch(opts, rest)
	if err == nil {
		return ExitOK
	}
	ce := asCLIError(err)
	writeError(opts.out, ce)
	return ce.ExitCode
}

func validateInsecure(prompt io.Writer) error {
	if os.Getenv("KAIROS_ALLOW_INSECURE") != "1" {
		return &CLIError{Code: "INSECURE_DISABLED", Message: "--insecure 需要设置 KAIROS_ALLOW_INSECURE=1", ExitCode: ExitUsage}
	}
	info, err := os.Stdin.Stat()
	if err != nil || info.Mode()&os.ModeCharDevice == 0 {
		return &CLIError{Code: "INSECURE_NON_INTERACTIVE", Message: "非交互模式禁止使用 --insecure", ExitCode: ExitUsage}
	}
	_, _ = fmt.Fprint(prompt, "不安全 TLS 仅限开发环境。输入 INSECURE 继续: ")
	var confirmation string
	_, _ = fmt.Fscanln(os.Stdin, &confirmation)
	if confirmation != "INSECURE" {
		return &CLIError{Code: "INSECURE_NOT_CONFIRMED", Message: "未确认不安全 TLS", ExitCode: ExitUsage}
	}
	return nil
}

func parseGlobal(args []string) (options, []string, error) {
	opts := options{output: os.Getenv("KAIROS_OUTPUT"), requestTimeout: 15 * time.Second, waitTimeout: 30 * time.Minute}
	if opts.output == "" {
		opts.output = "table"
	}
	if value := os.Getenv("KAIROS_REQUEST_TIMEOUT"); value != "" {
		d, err := parseDuration(value, opts.requestTimeout)
		if err != nil {
			return opts, nil, err
		}
		opts.requestTimeout = d
	}
	if value := os.Getenv("KAIROS_WAIT_TIMEOUT"); value != "" {
		d, err := parseDuration(value, opts.waitTimeout)
		if err != nil {
			return opts, nil, err
		}
		opts.waitTimeout = d
	}
	var rest []string
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if !strings.HasPrefix(arg, "-") {
			rest = append(rest, arg)
			continue
		}
		value := func() (string, error) {
			if strings.Contains(arg, "=") {
				return strings.SplitN(arg, "=", 2)[1], nil
			}
			if i+1 >= len(args) {
				return "", errors.New("missing value for " + arg)
			}
			i++
			return args[i], nil
		}
		switch {
		case arg == "--quiet":
			opts.quiet = true
		case arg == "--no-color":
			opts.noColor = true
		case arg == "--insecure":
			opts.insecure = true
		case arg == "--allow-encrypted-file":
			opts.allowEncryptedFile = true
		case arg == "--server" || strings.HasPrefix(arg, "--server="):
			v, err := value()
			if err != nil {
				return opts, nil, err
			}
			opts.server = v
		case arg == "--workspace" || strings.HasPrefix(arg, "--workspace="):
			v, err := value()
			if err != nil {
				return opts, nil, err
			}
			opts.workspace = v
		case arg == "--output" || strings.HasPrefix(arg, "--output="):
			v, err := value()
			if err != nil {
				return opts, nil, err
			}
			if v != "table" && v != "json" && v != "ndjson" {
				return opts, nil, errors.New("--output must be table, json, or ndjson")
			}
			opts.output = v
		case arg == "--request-timeout" || strings.HasPrefix(arg, "--request-timeout="):
			v, err := value()
			if err != nil {
				return opts, nil, err
			}
			d, err := parseDuration(v, opts.requestTimeout)
			if err != nil {
				return opts, nil, err
			}
			opts.requestTimeout = d
		case arg == "--wait-timeout" || strings.HasPrefix(arg, "--wait-timeout="):
			v, err := value()
			if err != nil {
				return opts, nil, err
			}
			d, err := parseDuration(v, opts.waitTimeout)
			if err != nil {
				return opts, nil, err
			}
			opts.waitTimeout = d
		default:
			rest = append(rest, arg)
		}
	}
	return opts, rest, nil
}

func dispatch(opts options, args []string) error {
	switch args[0] {
	case "server":
		return serverCommand(opts, args[1:])
	case "login":
		return loginCommand(opts, args[1:])
	case "logout":
		return logoutCommand(opts, args[1:])
	case "whoami":
		return whoamiCommand(opts)
	case "workspace":
		return workspaceCommand(opts, args[1:])
	case "task":
		return taskCommand(opts, args[1:])
	case "run":
		return runCommand(opts, args[1:])
	case "runner":
		return runnerCommand(opts, args[1:])
	case "token":
		return tokenCommand(opts, args[1:])
	case "central":
		return centralCommand(opts, args[1:])
	default:
		return usageError(errors.New("未知命令: " + args[0]))
	}
}

func parseServerURL(raw string) (string, error) {
	raw = strings.TrimRight(strings.TrimSpace(raw), "/")
	if !strings.HasPrefix(raw, "http://") && !strings.HasPrefix(raw, "https://") {
		return "", usageError(errors.New("URL 必须以 http:// 或 https:// 开头"))
	}
	return raw, nil
}
func usageError(err error) error {
	return &CLIError{Code: "USAGE", Message: err.Error(), ExitCode: ExitUsage}
}
func printHelp(w io.Writer) {
	_, _ = fmt.Fprintln(w, "kairos - Kairos 命令行客户端")
	_, _ = fmt.Fprintln(w, "用法: kairos [全局参数] <命令>")
	_, _ = fmt.Fprintln(w, "命令: server login logout whoami workspace task run runner token central version")
}
func runtimePlatform() string {
	if runtime.GOOS == "windows" {
		return "windows"
	}
	return runtime.GOOS
}
func workspaceID(opts options, config Config) string {
	if opts.workspace != "" {
		return opts.workspace
	}
	if value := os.Getenv("KAIROS_WORKSPACE"); value != "" {
		return value
	}
	if config.CurrentWorkspace != "" {
		return config.CurrentWorkspace
	}
	return "personal"
}
func syncPath(workspace, action string) string {
	if workspace == "personal" {
		return "/api/v1/sync/" + action
	}
	return "/api/v2/workspaces/" + workspace + "/sync/" + action
}
func readInput(value string) ([]byte, error) {
	if value == "-" {
		return io.ReadAll(bufio.NewReader(os.Stdin))
	}
	trimmed := strings.TrimSpace(value)
	if strings.HasPrefix(trimmed, "{") || strings.HasPrefix(trimmed, "[") {
		return []byte(value), nil
	}
	if strings.HasPrefix(value, "@") {
		value = strings.TrimPrefix(value, "@")
	}
	return os.ReadFile(value)
}
func toValues(input map[string][]string) url.Values {
	values := url.Values{}
	for key, list := range input {
		for _, value := range list {
			values.Add(key, value)
		}
	}
	return values
}
func argAt(args []string, index int) string {
	if index < len(args) {
		return args[index]
	}
	return ""
}
func safeSegment(value string) (string, error) {
	if value == "" || strings.ContainsAny(value, "/\\\r\n") || value == "." || value == ".." {
		return "", usageError(errors.New("ID 参数无效"))
	}
	return url.PathEscape(value), nil
}
func asCLIError(err error) *CLIError {
	if err == nil {
		return nil
	}
	var value *CLIError
	if errors.As(err, &value) {
		if value.ExitCode == 0 {
			value.ExitCode = ExitGeneral
		}
		return value
	}
	return &CLIError{Code: "ERROR", Message: err.Error(), ExitCode: ExitGeneral}
}
func writeError(out Output, err *CLIError) {
	if err == nil {
		return
	}
	if out.Mode == "json" || out.Mode == "ndjson" {
		_ = out.JSON(map[string]any{"error": map[string]any{"code": err.Code, "message": err.Message, "request_id": err.RequestID, "details": err.Details}})
		return
	}
	if out.Err != nil {
		_, _ = fmt.Fprintln(out.Err, "错误:", err.Message)
	}
}
func newKey(value string) string {
	if value != "" {
		return value
	}
	return newRequestID()
}

func serverCommand(opts options, args []string) error {
	if len(args) == 0 {
		return usageError(errors.New("用法: server add|list|use|remove|doctor"))
	}
	config, err := LoadConfig()
	if err != nil {
		return err
	}
	switch args[0] {
	case "list":
		if opts.output != "table" {
			return opts.out.JSON(config.Servers)
		}
		rows := make([][]string, 0, len(config.Servers))
		names := make([]string, 0, len(config.Servers))
		for name := range config.Servers {
			names = append(names, name)
		}
		sort.Strings(names)
		for _, name := range names {
			profile := config.Servers[name]
			current := ""
			if name == config.CurrentServer {
				current = "*"
			}
			rows = append(rows, []string{name, profile.URL, current})
		}
		return opts.out.Table([]string{"NAME", "URL", "CURRENT"}, rows)
	case "add":
		fs := flag.NewFlagSet("server add", flag.ContinueOnError)
		fs.SetOutput(io.Discard)
		urlValue := fs.String("url", "", "")
		verifyTLS := fs.Bool("verify-tls", true, "")
		caFile := fs.String("ca-file", "", "")
		defaultRunner := fs.String("default-runner", "", "")
		if err := fs.Parse(args[1:]); err != nil {
			return usageError(err)
		}
		if fs.NArg() != 1 || strings.TrimSpace(*urlValue) == "" {
			return usageError(errors.New("用法: server add NAME --url URL"))
		}
		name := fs.Arg(0)
		parsed, err := parseServerURL(*urlValue)
		if err != nil {
			return err
		}
		config.Servers[name] = ServerProfile{URL: parsed, VerifyTLS: *verifyTLS && strings.HasPrefix(parsed, "https://"), CAFile: *caFile, DefaultRunner: *defaultRunner}
		if config.CurrentServer == "" {
			config.CurrentServer = name
		}
		if err := SaveConfig(config); err != nil {
			return err
		}
		return opts.out.JSON(map[string]any{"name": name, "url": parsed})
	case "use":
		if len(args) != 2 {
			return usageError(errors.New("用法: server use NAME"))
		}
		if _, ok := config.Servers[args[1]]; !ok {
			return &CLIError{Code: "SERVER_NOT_FOUND", Message: "服务 Profile 不存在: " + args[1], ExitCode: ExitUsage}
		}
		config.CurrentServer = args[1]
		if err := SaveConfig(config); err != nil {
			return err
		}
		return opts.out.JSON(map[string]any{"current_server": args[1]})
	case "remove":
		if len(args) != 2 {
			return usageError(errors.New("用法: server remove NAME"))
		}
		if _, ok := config.Servers[args[1]]; !ok {
			return &CLIError{Code: "SERVER_NOT_FOUND", Message: "服务 Profile 不存在: " + args[1], ExitCode: ExitUsage}
		}
		delete(config.Servers, args[1])
		_ = DeleteCredentials(args[1])
		if config.CurrentServer == args[1] {
			config.CurrentServer = ""
		}
		if err := SaveConfig(config); err != nil {
			return err
		}
		return opts.out.JSON(map[string]any{"removed": args[1]})
	case "doctor":
		name, profile, err := resolveServer(config, opts.server)
		if err != nil {
			return err
		}
		client, err := NewAPIClient(profile, "", opts.requestTimeout, opts.insecure)
		if err != nil {
			return err
		}
		checks := map[string]any{"server": name, "url": profile.URL}
		if value, err := client.Get(context.Background(), "/healthz", nil); err == nil {
			checks["health"] = value
		} else {
			checks["health_error"] = asCLIError(err).Code
		}
		if value, err := client.Get(context.Background(), "/version", nil); err == nil {
			checks["version"] = value
		}
		return opts.out.JSON(checks)
	default:
		return usageError(errors.New("未知 server 子命令"))
	}
}

func loginCommand(opts options, args []string) error {
	fs := flag.NewFlagSet("login", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	server := fs.String("server", opts.server, "")
	username := fs.String("username", "", "")
	password := fs.String("password", "", "")
	device := fs.String("device", "kairos-cli", "")
	if err := fs.Parse(args); err != nil {
		return usageError(err)
	}
	config, err := LoadConfig()
	if err != nil {
		return err
	}
	name, profile, err := resolveServer(config, *server)
	if err != nil {
		return err
	}
	if *username == "" {
		*username = os.Getenv("KAIROS_USERNAME")
	}
	if *password == "" {
		*password = os.Getenv("KAIROS_PASSWORD")
	}
	allowEncryptedFile := opts.allowEncryptedFile
	if *username == "" || *password == "" {
		return usageError(errors.New("login 需要 --username 和 --password（或 KAIROS_USERNAME/KAIROS_PASSWORD）"))
	}
	if opts.insecure && os.Getenv("KAIROS_ALLOW_INSECURE") != "1" {
		return &CLIError{Code: "INSECURE_DISABLED", Message: "--insecure 需要设置 KAIROS_ALLOW_INSECURE=1", ExitCode: ExitUsage}
	}
	client, err := NewAPIClient(profile, "", opts.requestTimeout, opts.insecure)
	if err != nil {
		return err
	}
	response, err := client.Post(context.Background(), "/api/v1/auth/login", map[string]any{"username": *username, "password": *password, "device": map[string]string{"name": *device, "platform": runtimePlatform()}}, "")
	if err != nil {
		return err
	}
	access, _ := response["access_token"].(string)
	refresh, _ := response["refresh_token"].(string)
	if access == "" || refresh == "" {
		return &CLIError{Code: "INVALID_RESPONSE", Message: "登录响应缺少令牌", ExitCode: ExitUnavailable}
	}
	expires, _ := response["expires_in"].(float64)
	if err := SaveCredentials(name, Credentials{AccessToken: access, RefreshToken: refresh, ExpiresAt: time.Now().UTC().Add(time.Duration(expires) * time.Second).Format(time.RFC3339)}, allowEncryptedFile); err != nil {
		return err
	}
	return opts.out.JSON(map[string]any{"server": name, "user": response["user"], "expires_in": expires})
}

func logoutCommand(opts options, args []string) error {
	config, err := LoadConfig()
	if err != nil {
		return err
	}
	name, profile, err := resolveServer(config, opts.server)
	if err != nil {
		return err
	}
	credentials, err := LoadCredentials(name)
	if err != nil {
		return err
	}
	if len(args) > 0 && args[0] == "--all" && credentials.RefreshToken != "" {
		client, _ := NewAPIClient(profile, "", opts.requestTimeout, opts.insecure)
		if client != nil {
			_, _ = client.Post(context.Background(), "/api/v1/auth/logout", map[string]string{"refresh_token": credentials.RefreshToken}, "")
		}
	}
	if err := DeleteCredentials(name); err != nil {
		return err
	}
	return opts.out.JSON(map[string]any{"logged_out": name})
}
func whoamiCommand(opts options) error {
	client, _, _, err := authenticatedClient(opts)
	if err != nil {
		return err
	}
	value, err := client.Get(context.Background(), "/api/v1/auth/me", nil)
	if err != nil {
		return err
	}
	return opts.out.JSON(value)
}
func authenticatedClient(opts options) (*APIClient, string, Config, error) {
	config, err := LoadConfig()
	if err != nil {
		return nil, "", config, err
	}
	name, profile, err := resolveServer(config, opts.server)
	if err != nil {
		return nil, "", config, err
	}
	credentials := Credentials{}
	if token := os.Getenv("KAIROS_TOKEN"); token != "" {
		credentials.AccessToken = token
	} else {
		credentials, err = LoadCredentials(name)
		if err != nil {
			return nil, "", config, err
		}
	}
	if credentials.AccessToken == "" {
		return nil, "", config, &CLIError{Code: "UNAUTHENTICATED", Message: "请先运行 kairos login", ExitCode: ExitUnauth}
	}
	client, err := NewAPIClient(profile, credentials.AccessToken, opts.requestTimeout, opts.insecure)
	return client, name, config, err
}

func centralClient(opts options) (*APIClient, string, Config, error) {
	config, err := LoadConfig()
	if err != nil {
		return nil, "", config, err
	}
	name, profile, err := resolveServer(config, opts.server)
	if err != nil {
		return nil, "", config, err
	}
	token := strings.TrimSpace(os.Getenv("KAIROS_CENTRAL_TOKEN"))
	if token == "" {
		return nil, "", config, &CLIError{Code: "CENTRAL_TOKEN_REQUIRED", Message: "中央命令需要 KAIROS_CENTRAL_TOKEN（先用 L3 账号执行 token create）", ExitCode: ExitUnauth}
	}
	client, err := NewAPIClient(profile, token, opts.requestTimeout, opts.insecure)
	return client, name, config, err
}

func centralCommand(opts options, args []string) error {
	if len(args) == 0 || args[0] != "task" || len(args) < 2 || args[1] != "create" {
		return usageError(errors.New("用法: central task create --group GROUP_ID --workspace WORKSPACE_ID --creator-user USER_ID --title TEXT"))
	}
	fs := flag.NewFlagSet("central task create", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	group := fs.String("group", "", "")
	workspace := fs.String("workspace", "", "")
	creator := fs.String("creator-user", "", "")
	creatorUsername := fs.String("creator-username", "", "")
	title := fs.String("title", "", "")
	description := fs.String("description", "", "")
	priority := fs.Int("priority", 2, "")
	agent := fs.String("agent", "", "")
	jsonFile := fs.String("json-file", "", "")
	key := fs.String("idempotency-key", "", "")
	if err := fs.Parse(args[2:]); err != nil {
		return usageError(err)
	}
	payload := map[string]any{}
	if *jsonFile != "" {
		data, err := readInput(*jsonFile)
		if err != nil {
			return err
		}
		var filePayload map[string]any
		if err := json.Unmarshal(data, &filePayload); err != nil {
			return usageError(errors.New("--json-file 必须是 JSON 对象"))
		}
		for field, value := range filePayload {
			payload[field] = value
		}
	}
	// Only explicitly supplied flags override JSON. This preserves values such
	// as a file-provided priority or idempotency key when flags are omitted.
	creatorUserFlag, creatorUsernameFlag := false, false
	fs.Visit(func(f *flag.Flag) {
		switch f.Name {
		case "group":
			payload["group_id"] = strings.TrimSpace(*group)
		case "workspace":
			payload["workspace_id"] = strings.TrimSpace(*workspace)
		case "creator-user":
			creatorUserFlag = true
			delete(payload, "creator_username")
			payload["creator_user_id"] = strings.TrimSpace(*creator)
		case "creator-username":
			creatorUsernameFlag = true
			delete(payload, "creator_user_id")
			payload["creator_username"] = strings.TrimSpace(*creatorUsername)
		case "title":
			payload["title"] = *title
		case "description":
			payload["description"] = *description
		case "priority":
			payload["quadrant"] = *priority
		case "agent":
			payload["source_agent_id"] = strings.TrimSpace(*agent)
		}
	})
	if _, exists := payload["quadrant"]; !exists {
		payload["quadrant"] = *priority
	}
	// parseGlobal accepts --workspace anywhere in the argument list, so a
	// central command's target workspace flag is stored on opts rather than
	// reaching this subcommand's FlagSet. Treat that explicit global value as
	// the central payload field; JSON still supplies the value when no flag is
	// provided.
	if strings.TrimSpace(opts.workspace) != "" {
		payload["workspace_id"] = strings.TrimSpace(opts.workspace)
	}
	stringValue := func(key string) string {
		value, ok := payload[key]
		if !ok || value == nil {
			return ""
		}
		return strings.TrimSpace(fmt.Sprint(value))
	}
	groupValue := stringValue("group_id")
	workspaceValue := stringValue("workspace_id")
	creatorValue := stringValue("creator_user_id")
	creatorUsernameValue := stringValue("creator_username")
	titleValue := stringValue("title")
	if groupValue == "" || workspaceValue == "" || (creatorValue == "" && creatorUsernameValue == "") || titleValue == "" {
		return usageError(errors.New("必须指定 --group、--workspace、--title 和 --creator-user（或 --creator-username），也可在 --json-file 中提供"))
	}
	if (creatorUserFlag && creatorUsernameFlag) || (creatorValue != "" && creatorUsernameValue != "") {
		return usageError(errors.New("--creator-user 与 --creator-username 只能指定一个"))
	}
	if keyValue := strings.TrimSpace(*key); keyValue != "" {
		if fileKey := stringValue("idempotency_key"); fileKey != "" && fileKey != keyValue {
			return usageError(errors.New("--idempotency-key 必须与 JSON 文件中的 idempotency_key 一致"))
		}
		payload["idempotency_key"] = keyValue
	} else if fileKey := stringValue("idempotency_key"); fileKey == "" {
		payload["idempotency_key"] = newKey("")
	}
	client, _, _, err := centralClient(opts)
	if err != nil {
		return err
	}
	return v3Command(client, opts, "POST", "/api/v3/central/tasks", payload, fmt.Sprint(payload["idempotency_key"]))
}

func workspaceCommand(opts options, args []string) error {
	client, _, config, err := authenticatedClient(opts)
	if err != nil {
		return err
	}
	if len(args) == 0 {
		return usageError(errors.New("用法: workspace list|use|current"))
	}
	switch args[0] {
	case "list":
		value, err := client.Get(context.Background(), "/api/v2/workspaces", nil)
		if err != nil {
			return err
		}
		return opts.out.JSON(value)
	case "current":
		current := workspaceID(opts, config)
		return opts.out.JSON(map[string]string{"workspace": current})
	case "use":
		if len(args) != 2 {
			return usageError(errors.New("用法: workspace use ID"))
		}
		config.CurrentWorkspace = args[1]
		if err := SaveConfig(config); err != nil {
			return err
		}
		return opts.out.JSON(map[string]string{"current_workspace": args[1]})
	default:
		return usageError(errors.New("未知 workspace 子命令"))
	}
}

func taskCommand(opts options, args []string) error {
	client, _, config, err := authenticatedClient(opts)
	if err != nil {
		return err
	}
	if len(args) == 0 {
		return usageError(errors.New("用法: task list|get|create|update|comment|run|cancel|logs|result"))
	}
	workspace := workspaceID(opts, config)
	switch args[0] {
	case "list":
		fs := flag.NewFlagSet("task list", flag.ContinueOnError)
		fs.SetOutput(io.Discard)
		status := fs.String("status", "", "")
		tag := fs.String("tag", "", "")
		assignee := fs.String("assignee", "", "")
		limit := fs.Int("limit", 100, "")
		cursor := fs.String("cursor", "", "")
		if err := fs.Parse(args[1:]); err != nil || *limit < 1 {
			return usageError(errors.New("task list 参数无效"))
		}
		value, err := client.Get(context.Background(), syncPath(workspace, "snapshot"), nil)
		if err != nil {
			return err
		}
		tasks, _ := value["tasks"].([]any)
		filtered := make([]any, 0, len(tasks))
		for _, item := range tasks {
			object, ok := item.(map[string]any)
			if !ok {
				continue
			}
			if *status != "" && fmt.Sprint(object["status"]) != *status {
				continue
			}
			if *tag != "" && !containsJSONTag(object, *tag) {
				continue
			}
			if *assignee != "" && fmt.Sprint(object["assignee"]) != *assignee {
				continue
			}
			filtered = append(filtered, object)
			if len(filtered) >= *limit {
				break
			}
		}
		if opts.output != "table" {
			result := map[string]any{"tasks": filtered, "cursor": value["cursor"]}
			if *cursor != "" {
				result["requested_cursor"] = *cursor
			}
			return opts.out.JSON(result)
		}
		rows := make([][]string, 0, len(filtered))
		for _, item := range filtered {
			object := item.(map[string]any)
			rows = append(rows, []string{fmt.Sprint(object["id"]), fmt.Sprint(object["title"]), fmt.Sprint(object["status"])})
		}
		return opts.out.Table([]string{"ID", "TITLE", "STATUS"}, rows)
	case "get":
		if len(args) < 2 {
			return usageError(errors.New("用法: task get ID"))
		}
		id, err := safeSegment(args[1])
		if err != nil {
			return err
		}
		value, err := client.Get(context.Background(), "/api/v1/tasks/"+id, nil)
		if err != nil {
			return err
		}
		return opts.out.JSON(value)
	case "create":
		return taskWrite(client, opts, workspace, args[1:], true)
	case "update":
		if len(args) < 2 {
			return usageError(errors.New("用法: task update ID --title ..."))
		}
		return taskWrite(client, opts, workspace, args[2:], false, args[1])
	case "comment":
		if len(args) < 2 {
			return usageError(errors.New("用法: task comment ID --body TEXT"))
		}
		return v3Command(client, opts, "POST", "/api/v3/tasks/"+args[1]+"/comments", parseBodyFlag(args[2:], "body"), "")
	case "run":
		return taskRun(client, opts, args[1:])
	case "cancel":
		return taskCancel(client, opts, args[1:])
	case "logs":
		return taskLogs(client, opts, args[1:])
	case "result":
		return taskResult(client, opts, args[1:])
	default:
		return usageError(errors.New("未知 task 子命令"))
	}
}

func containsJSONTag(object map[string]any, tag string) bool {
	values, ok := object["tag_ids"].([]any)
	if !ok {
		return false
	}
	for _, value := range values {
		if fmt.Sprint(value) == tag {
			return true
		}
	}
	return false
}

func taskWrite(client *APIClient, opts options, workspace string, args []string, create bool, ids ...string) error {
	fs := flag.NewFlagSet("task write", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	title := fs.String("title", "", "")
	description := fs.String("description", "", "")
	priority := fs.Int("priority", 0, "")
	jsonFile := fs.String("json-file", "", "")
	key := fs.String("idempotency-key", "", "")
	baseVersion := fs.Int64("base-version", -1, "")
	if err := fs.Parse(args); err != nil {
		return usageError(err)
	}
	changes := map[string]any{}
	if *jsonFile != "" {
		data, err := readInput(*jsonFile)
		if err != nil {
			return err
		}
		if err := json.Unmarshal(data, &changes); err != nil {
			return usageError(errors.New("--json-file 必须是 JSON 对象"))
		}
	}
	if *title != "" {
		changes["title"] = *title
	}
	if *description != "" {
		changes["description"] = *description
	}
	if *priority != 0 {
		changes["quadrant"] = *priority
	}
	if len(changes) == 0 {
		return usageError(errors.New("至少指定一个任务字段"))
	}
	id := newRequestID()
	if !create {
		id = ids[0]
		if *baseVersion < 0 {
			current, err := client.Get(context.Background(), "/api/v1/tasks/"+id, nil)
			if err != nil {
				return err
			}
			if value, ok := current["version"].(float64); ok {
				*baseVersion = int64(value)
			}
			if *baseVersion < 0 {
				return &CLIError{Code: "INVALID_RESPONSE", Message: "任务响应缺少 version", ExitCode: ExitUnavailable}
			}
		}
	} else if *baseVersion < 0 {
		*baseVersion = 0
	}
	fields := make([]string, 0, len(changes))
	for field := range changes {
		fields = append(fields, field)
	}
	op := map[string]any{"operation_id": newRequestID(), "entity_type": "task", "entity_id": id, "base_version": *baseVersion, "changes": changes, "changed_fields": fields}
	value, err := client.Post(context.Background(), syncPath(workspace, "push"), map[string]any{"operations": []any{op}}, newKey(*key))
	if err != nil {
		return err
	}
	return opts.out.JSON(value)
}

func taskRun(client *APIClient, opts options, args []string) error {
	if len(args) == 0 {
		return usageError(errors.New("用法: task run ID [--runner NAME] [--input JSON|@FILE|-] [--wait] [--consent]"))
	}
	taskID := args[0]
	for _, arg := range args[1:] {
		if arg == "--approve" {
			return usageError(errors.New("--approve 已废弃，请使用 --consent"))
		}
	}
	fs := flag.NewFlagSet("task run", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	runner := fs.String("runner", "", "")
	input := fs.String("input", "", "")
	wait := fs.Bool("wait", false, "")
	consent := fs.Bool("consent", false, "")
	key := fs.String("idempotency-key", "", "")
	if err := fs.Parse(args[1:]); err != nil {
		return usageError(err)
	}
	payload := map[string]any{"task_id": taskID, "consent": *consent, "input": map[string]any{}}
	if *runner != "" {
		payload["runner"] = *runner
	}
	if *input != "" {
		data, err := readInput(*input)
		if err != nil {
			return err
		}
		var value any
		if err := json.Unmarshal(data, &value); err != nil {
			return usageError(errors.New("--input 必须是 JSON"))
		}
		payload["input"] = value
	}
	value, err := client.Post(context.Background(), "/api/v3/runs", payload, newKey(*key))
	if err != nil {
		return err
	}
	if !*wait {
		return opts.out.JSON(value)
	}
	runID, _ := value["run_id"].(string)
	if runID == "" {
		return opts.out.JSON(value)
	}
	return waitRun(client, opts, runID)
}
func waitRun(client *APIClient, opts options, runID string) error {
	deadline := time.Now().Add(opts.waitTimeout)
	for {
		value, err := client.Get(context.Background(), "/api/v3/runs/"+runID, nil)
		if err != nil {
			return err
		}
		status := fmt.Sprint(value["status"])
		switch status {
		case "succeeded":
			_ = opts.out.JSON(value)
			return nil
		case "failed", "cancelled", "timed_out":
			_ = opts.out.JSON(value)
			return &CLIError{Code: "RUN_" + strings.ToUpper(status), Message: "Run 未成功结束", ExitCode: ExitRunFailed, Details: value}
		case "":
			return opts.out.JSON(value)
		}
		if time.Now().After(deadline) {
			_ = opts.out.JSON(value)
			return &CLIError{Code: "WAIT_TIMEOUT", Message: "本地等待超时，Run 仍在服务端运行", ExitCode: ExitWaitTimeout, Details: value}
		}
		time.Sleep(time.Second)
	}
}

func taskCancel(client *APIClient, opts options, args []string) error {
	if len(args) == 0 {
		return usageError(errors.New("用法: task cancel ID --run RUN_ID"))
	}
	fs := flag.NewFlagSet("task cancel", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	run := fs.String("run", "", "")
	reason := fs.String("reason", "", "")
	key := fs.String("idempotency-key", "", "")
	if err := fs.Parse(args[1:]); err != nil || *run == "" {
		return usageError(errors.New("--run 必须指定，禁止批量取消"))
	}
	return v3Command(client, opts, "POST", "/api/v3/runs/"+*run+"/cancel", map[string]string{"reason": *reason}, newKey(*key))
}
func taskLogs(client *APIClient, opts options, args []string) error {
	if len(args) == 0 {
		return usageError(errors.New("用法: task logs ID --run RUN_ID"))
	}
	fs := flag.NewFlagSet("task logs", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	run := fs.String("run", "", "")
	follow := fs.Bool("follow", false, "")
	since := fs.String("since", "", "")
	if err := fs.Parse(args[1:]); err != nil || *run == "" {
		return usageError(errors.New("--run 必须指定"))
	}
	query := url.Values{}
	if *follow {
		query.Set("follow", "true")
	}
	if *since != "" {
		if _, err := time.Parse(time.RFC3339, *since); err != nil {
			return usageError(errors.New("--since 只接受 RFC3339 时间戳"))
		}
		query.Set("since", *since)
	}
	value, err := client.Get(context.Background(), "/api/v3/runs/"+*run+"/logs", query)
	if err != nil {
		return err
	}
	return opts.out.JSON(value)
}
func taskResult(client *APIClient, opts options, args []string) error {
	if len(args) == 0 {
		return usageError(errors.New("用法: task result ID --run RUN_ID"))
	}
	fs := flag.NewFlagSet("task result", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	run := fs.String("run", "", "")
	artifact := fs.String("artifact", "", "")
	if err := fs.Parse(args[1:]); err != nil || *run == "" {
		return usageError(errors.New("--run 必须指定"))
	}
	runID, err := safeSegment(*run)
	if err != nil {
		return err
	}
	path := "/api/v3/runs/" + runID + "/result"
	if *artifact != "" {
		artifactID, err := safeSegment(*artifact)
		if err != nil {
			return err
		}
		path += "/" + artifactID
	}
	return v3Command(client, opts, "GET", path, nil, "")
}

func v3Command(client *APIClient, opts options, method, path string, body any, key string) error {
	var value map[string]any
	var err error
	switch method {
	case "GET":
		value, err = client.Get(context.Background(), path, nil)
	case "POST":
		value, err = client.Post(context.Background(), path, body, key)
	case "PUT":
		value, err = client.Put(context.Background(), path, body, key)
	case "DELETE":
		value, err = client.Delete(context.Background(), path, key)
	}
	if err != nil {
		return err
	}
	return opts.out.JSON(value)
}
func parseBodyFlag(args []string, name string) map[string]any {
	fs := flag.NewFlagSet("body", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	value := fs.String(name, "", "")
	_ = fs.Parse(args)
	return map[string]any{name: *value}
}

func runCommand(opts options, args []string) error {
	client, _, _, err := authenticatedClient(opts)
	if err != nil {
		return err
	}
	if len(args) == 0 {
		return usageError(errors.New("用法: run list|get|approve|reject"))
	}
	switch args[0] {
	case "list":
		fs := flag.NewFlagSet("run list", flag.ContinueOnError)
		fs.SetOutput(io.Discard)
		task := fs.String("task", "", "")
		workspace := fs.String("workspace", opts.workspace, "")
		status := fs.String("status", "", "")
		limit := fs.Int("limit", 100, "")
		cursor := fs.String("cursor", "", "")
		if err := fs.Parse(args[1:]); err != nil || *limit < 1 {
			return usageError(errors.New("run list 参数无效"))
		}
		query := url.Values{"limit": []string{fmt.Sprint(*limit)}}
		if *task != "" {
			query.Set("task", *task)
		}
		if *workspace != "" {
			query.Set("workspace", *workspace)
		}
		if *status != "" {
			query.Set("status", *status)
		}
		if *cursor != "" {
			query.Set("cursor", *cursor)
		}
		value, err := client.Get(context.Background(), "/api/v3/runs", query)
		if err != nil {
			return err
		}
		return opts.out.JSON(value)
	case "get":
		if len(args) != 2 {
			return usageError(errors.New("用法: run get RUN_ID"))
		}
		return v3Command(client, opts, "GET", "/api/v3/runs/"+args[1], nil, "")
	case "approve", "reject":
		if len(args) < 2 {
			return usageError(errors.New("用法: run approve|reject RUN_ID --reason TEXT"))
		}
		fs := flag.NewFlagSet("run decision", flag.ContinueOnError)
		fs.SetOutput(io.Discard)
		reason := fs.String("reason", "", "")
		if err := fs.Parse(args[2:]); err != nil || (args[0] == "reject" && strings.TrimSpace(*reason) == "") {
			return usageError(errors.New("reject 必须提供 --reason"))
		}
		return v3Command(client, opts, "POST", "/api/v3/runs/"+args[1]+"/"+args[0], map[string]string{"reason": *reason}, "")
	default:
		return usageError(errors.New("未知 run 子命令"))
	}
}

func runnerCommand(opts options, args []string) error {
	if len(args) == 0 {
		return usageError(errors.New("用法: runner list|create|revoke|inspect|install|unquarantine|serve"))
	}
	if args[0] == "serve" {
		return runnerServe(opts, args[1:])
	}
	if args[0] == "install" {
		fs := flag.NewFlagSet("runner install", flag.ContinueOnError)
		fs.SetOutput(io.Discard)
		server := fs.String("server", opts.server, "")
		if *server == "" {
			*server = os.Getenv("KAIROS_SERVER_URL")
		}
		name := fs.String("name", "", "")
		if err := fs.Parse(args[1:]); err != nil || *server == "" || *name == "" {
			return usageError(errors.New("用法: runner install --server URL --name NAME"))
		}
		profile, err := parseServerURL(*server)
		if err != nil {
			return err
		}
		return opts.out.JSON(map[string]any{"server": profile, "name": *name, "config": fmt.Sprintf("KAIROS_SERVER_URL=%s\nKAIROS_RUNNER_NAME=%s\n", profile, *name), "command": "kairos runner serve --server " + profile + " --name " + *name + " --token <ONE_TIME_RUNNER_TOKEN>"})
	}
	client, _, _, err := authenticatedClient(opts)
	if err != nil {
		return err
	}
	switch args[0] {
	case "list":
		return v3Command(client, opts, "GET", "/api/v3/runners", nil, "")
	case "inspect":
		if len(args) != 2 {
			return usageError(errors.New("用法: runner inspect ID"))
		}
		return v3Command(client, opts, "GET", "/api/v3/runners/"+args[1], nil, "")
	case "revoke", "unquarantine":
		if len(args) != 2 {
			return usageError(errors.New("用法: runner revoke|unquarantine ID"))
		}
		return v3Command(client, opts, "POST", "/api/v3/runners/"+args[1]+"/"+args[0], map[string]any{}, "")
	case "create":
		if len(args) != 2 {
			return usageError(errors.New("用法: runner create NAME"))
		}
		return v3Command(client, opts, "POST", "/api/v3/runners", map[string]string{"name": args[1]}, newKey(""))
	default:
		return usageError(errors.New("未知 runner 子命令"))
	}
}

func runnerServe(opts options, args []string) error {
	fs := flag.NewFlagSet("runner serve", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	server := fs.String("server", opts.server, "")
	token := fs.String("token", os.Getenv("KAIROS_RUNNER_TOKEN"), "")
	name := fs.String("name", "", "")
	capabilities := fs.String("capabilities", "shell", "")
	concurrency := fs.Int("concurrency", 1, "")
	if err := fs.Parse(args); err != nil {
		return usageError(err)
	}
	if strings.TrimSpace(*token) == "" || strings.TrimSpace(*name) == "" {
		return usageError(errors.New("runner serve 需要 --name 和 --token（或 KAIROS_RUNNER_TOKEN）"))
	}
	if *concurrency < 1 {
		return usageError(errors.New("concurrency 必须大于 0"))
	}
	config, err := LoadConfig()
	if err != nil {
		return err
	}
	_, profile, err := resolveServer(config, *server)
	if err != nil {
		return err
	}
	client, err := NewAPIClient(profile, *token, opts.requestTimeout, opts.insecure)
	if err != nil {
		return err
	}
	register := map[string]any{"name": *name, "capabilities": splitCSV(*capabilities), "version": cliVersion, "platform": runtimePlatform(), "concurrency": *concurrency}
	value, err := client.Post(context.Background(), "/api/v3/runners/register", register, newKey(""))
	if err != nil {
		return err
	}
	runnerID, _ := value["runner_id"].(string)
	if runnerID == "" {
		return &CLIError{Code: "INVALID_RESPONSE", Message: "Runner 注册响应缺少 runner_id", ExitCode: ExitUnavailable}
	}
	if err := opts.out.JSON(value); err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			_, _ = client.Post(context.Background(), "/api/v3/runners/"+runnerID+"/shutdown", map[string]any{}, "")
			return nil
		case <-ticker.C:
			if _, err := client.Post(ctx, "/api/v3/runners/"+runnerID+"/heartbeat", map[string]any{"capabilities": splitCSV(*capabilities), "active_runs": 0}, ""); err != nil {
				return err
			}
		}
	}
}

func splitCSV(value string) []string {
	values := make([]string, 0)
	for _, item := range strings.Split(value, ",") {
		item = strings.TrimSpace(item)
		if item != "" {
			values = append(values, item)
		}
	}
	return values
}

func tokenCommand(opts options, args []string) error {
	client, _, _, err := authenticatedClient(opts)
	if err != nil {
		return err
	}
	if len(args) == 0 {
		return usageError(errors.New("用法: token create|revoke"))
	}
	switch args[0] {
	case "create":
		fs := flag.NewFlagSet("token create", flag.ContinueOnError)
		fs.SetOutput(io.Discard)
		scope := fs.String("scope", "", "")
		expires := fs.String("expires-in", "", "")
		if err := fs.Parse(args[1:]); err != nil || *scope == "" || *expires == "" {
			return usageError(errors.New("token create 需要 --scope 和 --expires-in"))
		}
		d, err := time.ParseDuration(*expires)
		if err != nil || d <= 0 || d > 24*time.Hour {
			return usageError(errors.New("expires-in 必须为正且不超过 24h"))
		}
		return v3Command(client, opts, "POST", "/api/v3/tokens", map[string]string{"scope": *scope, "expires_in": d.String()}, "")
	case "revoke":
		if len(args) != 2 {
			return usageError(errors.New("用法: token revoke TOKEN_ID"))
		}
		return v3Command(client, opts, "POST", "/api/v3/tokens/"+args[1]+"/revoke", map[string]any{}, "")
	default:
		return usageError(errors.New("未知 token 子命令"))
	}
}
