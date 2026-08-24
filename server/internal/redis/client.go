package redis

import (
	"bufio"
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Client is a small Redis RESP2 client used for infrastructure concerns. It
// intentionally exposes only the command surface needed by Kairos so Redis
// remains replaceable and does not become a source of business truth.
type Client struct {
	address        string
	username       string
	password       string
	database       int
	tls            bool
	dialTimeout    time.Duration
	commandTimeout time.Duration

	mu   sync.Mutex
	conn net.Conn
}

func New(rawURL string, dialTimeout, commandTimeout time.Duration) (*Client, error) {
	parsed, err := url.Parse(strings.TrimSpace(rawURL))
	if err != nil {
		return nil, fmt.Errorf("parse redis URL: %w", err)
	}
	if parsed.Scheme != "redis" && parsed.Scheme != "rediss" {
		return nil, fmt.Errorf("unsupported redis URL scheme %q", parsed.Scheme)
	}
	address := parsed.Host
	if address == "" {
		return nil, errors.New("redis URL must include a host")
	}
	database := 0
	if path := strings.Trim(parsed.Path, "/"); path != "" {
		database, err = strconv.Atoi(path)
		if err != nil || database < 0 {
			return nil, errors.New("redis URL database must be a non-negative integer")
		}
	}
	username := ""
	password := ""
	if parsed.User != nil {
		username = parsed.User.Username()
		password, _ = parsed.User.Password()
	}
	return &Client{
		address:        address,
		username:       username,
		password:       password,
		database:       database,
		tls:            parsed.Scheme == "rediss",
		dialTimeout:    dialTimeout,
		commandTimeout: commandTimeout,
	}, nil
}

func (c *Client) Ping(ctx context.Context) error {
	_, err := c.Command(ctx, "PING")
	return err
}

func (c *Client) Command(ctx context.Context, command string, args ...string) (any, error) {
	command = strings.TrimSpace(command)
	if command == "" {
		return nil, errors.New("redis command cannot be empty")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.ensureConnection(ctx); err != nil {
		return nil, err
	}
	if err := c.setDeadline(ctx); err != nil {
		return nil, err
	}
	if err := writeCommand(c.conn, append([]string{command}, args...)); err != nil {
		c.closeLocked()
		return nil, err
	}
	reader := bufio.NewReader(c.conn)
	value, err := readReply(reader)
	if err != nil {
		c.closeLocked()
		return nil, err
	}
	return value, nil
}

func (c *Client) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.closeLocked()
}

func (c *Client) ensureConnection(ctx context.Context) error {
	if c.conn != nil {
		return nil
	}
	dialer := net.Dialer{Timeout: c.dialTimeout}
	var conn net.Conn
	var err error
	if c.tls {
		conn, err = tls.DialWithDialer(&dialer, "tcp", c.address, &tls.Config{ServerName: strings.Split(c.address, ":")[0], MinVersion: tls.VersionTLS12})
	} else {
		conn, err = dialer.DialContext(ctx, "tcp", c.address)
	}
	if err != nil {
		return fmt.Errorf("connect to redis: %w", err)
	}
	c.conn = conn
	if c.username != "" || c.password != "" {
		authArgs := []string{c.password}
		if c.username != "" {
			authArgs = []string{c.username, c.password}
		}
		if _, err := c.commandLocked(ctx, "AUTH", authArgs...); err != nil {
			c.closeLocked()
			return fmt.Errorf("authenticate redis: %w", err)
		}
	}
	if c.database != 0 {
		if _, err := c.commandLocked(ctx, "SELECT", strconv.Itoa(c.database)); err != nil {
			c.closeLocked()
			return fmt.Errorf("select redis database: %w", err)
		}
	}
	return nil
}

func (c *Client) commandLocked(ctx context.Context, command string, args ...string) (any, error) {
	if err := c.setDeadline(ctx); err != nil {
		return nil, err
	}
	if err := writeCommand(c.conn, append([]string{command}, args...)); err != nil {
		return nil, err
	}
	return readReply(bufio.NewReader(c.conn))
}

func (c *Client) setDeadline(ctx context.Context) error {
	deadline := time.Now().Add(c.commandTimeout)
	if contextDeadline, ok := ctx.Deadline(); ok && contextDeadline.Before(deadline) {
		deadline = contextDeadline
	}
	return c.conn.SetDeadline(deadline)
}

func (c *Client) closeLocked() error {
	if c.conn == nil {
		return nil
	}
	err := c.conn.Close()
	c.conn = nil
	return err
}

func writeCommand(writer io.Writer, parts []string) error {
	if _, err := fmt.Fprintf(writer, "*%d\r\n", len(parts)); err != nil {
		return err
	}
	for _, part := range parts {
		if _, err := fmt.Fprintf(writer, "$%d\r\n%s\r\n", len([]byte(part)), part); err != nil {
			return err
		}
	}
	return nil
}

func readReply(reader *bufio.Reader) (any, error) {
	prefix, err := reader.ReadByte()
	if err != nil {
		return nil, err
	}
	line, err := reader.ReadString('\n')
	if err != nil {
		return nil, err
	}
	line = strings.TrimSuffix(strings.TrimSuffix(line, "\n"), "\r")
	switch prefix {
	case '+':
		return line, nil
	case '-':
		return nil, errors.New(line)
	case ':':
		return strconv.ParseInt(line, 10, 64)
	case '$':
		length, err := strconv.Atoi(line)
		if err != nil {
			return nil, err
		}
		if length == -1 {
			return nil, nil
		}
		payload := make([]byte, length+2)
		if _, err := io.ReadFull(reader, payload); err != nil {
			return nil, err
		}
		return string(payload[:length]), nil
	case '*':
		count, err := strconv.Atoi(line)
		if err != nil {
			return nil, err
		}
		if count == -1 {
			return nil, nil
		}
		values := make([]any, count)
		for i := range values {
			values[i], err = readReply(reader)
			if err != nil {
				return nil, err
			}
		}
		return values, nil
	default:
		return nil, fmt.Errorf("unknown redis reply type %q", prefix)
	}
}
