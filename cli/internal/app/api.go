package app

import (
	"context"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func newRequestID() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%08x-%04x-%04x-%04x-%012x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}

type APIClient struct {
	BaseURL        *url.URL
	HTTP           *http.Client
	AccessToken    string
	RequestTimeout time.Duration
}

func NewAPIClient(profile ServerProfile, token string, timeout time.Duration, insecure bool) (*APIClient, error) {
	base, err := url.Parse(strings.TrimSpace(profile.URL))
	if err != nil || base.Scheme == "" || base.Host == "" {
		return nil, &CLIError{Code: "INVALID_URL", Message: "服务 URL 无效", ExitCode: ExitUsage}
	}
	if base.Scheme != "https" && base.Scheme != "http" {
		return nil, &CLIError{Code: "INVALID_URL", Message: "服务 URL 必须使用 http 或 https", ExitCode: ExitUsage}
	}
	verify := profile.VerifyTLS
	if insecure {
		verify = false
	}
	tlsConfig := &tls.Config{MinVersion: tls.VersionTLS12, InsecureSkipVerify: !verify} // #nosec G402 -- explicitly controlled by profile and guarded flag.
	if profile.CAFile != "" {
		pem, err := os.ReadFile(filepath.Clean(profile.CAFile))
		if err != nil {
			return nil, fmt.Errorf("读取 CA 文件失败: %w", err)
		}
		pool, _ := x509.SystemCertPool()
		if pool == nil {
			pool = x509.NewCertPool()
		}
		if !pool.AppendCertsFromPEM(pem) {
			return nil, &CLIError{Code: "INVALID_CA", Message: "CA 文件无效", ExitCode: ExitUsage}
		}
		tlsConfig.RootCAs = pool
	}
	return &APIClient{BaseURL: base, HTTP: &http.Client{Transport: &http.Transport{TLSClientConfig: tlsConfig}}, AccessToken: token, RequestTimeout: timeout}, nil
}

func (c *APIClient) Do(ctx context.Context, method, path string, query url.Values, body any, idempotency string) (map[string]any, int, error) {
	var reader io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return nil, 0, err
		}
		reader = strings.NewReader(string(data))
	}
	target := *c.BaseURL
	target.Path = strings.TrimRight(c.BaseURL.Path, "/") + "/" + strings.TrimLeft(path, "/")
	target.RawQuery = query.Encode()
	requestCtx := ctx
	if c.RequestTimeout > 0 {
		var cancel context.CancelFunc
		requestCtx, cancel = context.WithTimeout(ctx, c.RequestTimeout)
		defer cancel()
	}
	req, err := http.NewRequestWithContext(requestCtx, method, target.String(), reader)
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.AccessToken != "" {
		req.Header.Set("Authorization", "Bearer "+c.AccessToken)
	}
	if idempotency != "" {
		req.Header.Set("Idempotency-Key", idempotency)
		req.Header.Set("X-Idempotency-Key", idempotency)
	}
	response, err := c.HTTP.Do(req)
	if err != nil {
		return nil, 0, &CLIError{Code: "NETWORK_ERROR", Message: "无法连接同步服务", ExitCode: ExitUnavailable, Details: err.Error()}
	}
	defer response.Body.Close()
	data, readErr := io.ReadAll(io.LimitReader(response.Body, 16<<20))
	if readErr != nil {
		return nil, response.StatusCode, readErr
	}
	var value map[string]any
	if len(data) > 0 {
		if err := json.Unmarshal(data, &value); err != nil {
			return nil, response.StatusCode, &CLIError{Code: "INVALID_RESPONSE", Message: "服务返回了无效 JSON", ExitCode: ExitUnavailable}
		}
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		code, message, requestID := "HTTP_ERROR", http.StatusText(response.StatusCode), response.Header.Get("X-Request-ID")
		if envelope, ok := value["error"].(map[string]any); ok {
			if v, ok := envelope["code"].(string); ok {
				code = v
			}
			if v, ok := envelope["message"].(string); ok {
				message = v
			}
			if v, ok := envelope["request_id"].(string); ok {
				requestID = v
			}
		}
		return value, response.StatusCode, &CLIError{Code: code, Message: message, RequestID: requestID, Details: value["error"], ExitCode: exitForStatus(response.StatusCode)}
	}
	if value == nil {
		value = map[string]any{}
	}
	if requestID := response.Header.Get("X-Request-ID"); requestID != "" {
		if _, exists := value["request_id"]; !exists {
			value["request_id"] = requestID
		}
	}
	return value, response.StatusCode, nil
}

func (c *APIClient) Get(ctx context.Context, path string, query url.Values) (map[string]any, error) {
	value, _, err := c.Do(ctx, http.MethodGet, path, query, nil, "")
	return value, err
}
func (c *APIClient) Post(ctx context.Context, path string, body any, key string) (map[string]any, error) {
	value, _, err := c.Do(ctx, http.MethodPost, path, nil, body, key)
	return value, err
}
func (c *APIClient) Put(ctx context.Context, path string, body any, key string) (map[string]any, error) {
	value, _, err := c.Do(ctx, http.MethodPut, path, nil, body, key)
	return value, err
}
func (c *APIClient) Delete(ctx context.Context, path string, key string) (map[string]any, error) {
	value, _, err := c.Do(ctx, http.MethodDelete, path, nil, nil, key)
	return value, err
}

func parseDuration(value string, fallback time.Duration) (time.Duration, error) {
	if value == "" {
		return fallback, nil
	}
	duration, err := time.ParseDuration(value)
	if err != nil || duration <= 0 {
		return 0, errors.New("duration must be positive, e.g. 15s or 30m")
	}
	return duration, nil
}
