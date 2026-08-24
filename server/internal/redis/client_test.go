package redis

import (
	"bufio"
	"context"
	"net"
	"strings"
	"testing"
	"time"
)

func TestNewParsesRedisURL(t *testing.T) {
	client, err := New("rediss://:secret@example.test:6380/2", time.Second, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	if client.address != "example.test:6380" || client.password != "secret" || client.database != 2 || !client.tls {
		t.Fatalf("unexpected client: %+v", client)
	}
	aclClient, err := New("redis://kairos:secret@example.test:6379/0", time.Second, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	if aclClient.username != "kairos" || aclClient.password != "secret" {
		t.Fatalf("redis ACL credentials were not parsed: %+v", aclClient)
	}
}

func TestNewRejectsUnsupportedURL(t *testing.T) {
	if _, err := New("http://127.0.0.1:6379", time.Second, time.Second); err == nil {
		t.Fatal("expected unsupported scheme to fail")
	}
}

func TestPingSpeaksRESP(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	serverErr := make(chan error, 1)
	go func() {
		conn, err := listener.Accept()
		if err != nil {
			serverErr <- err
			return
		}
		defer conn.Close()
		request, err := bufio.NewReader(conn).ReadString('\n')
		if err != nil {
			serverErr <- err
			return
		}
		if !strings.HasPrefix(request, "*1\r\n") {
			serverErr <- &unexpectedRequest{request}
			return
		}
		_, err = conn.Write([]byte("+PONG\r\n"))
		serverErr <- err
	}()

	client, err := New("redis://"+listener.Addr().String(), time.Second, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	if err := client.Ping(context.Background()); err != nil {
		t.Fatal(err)
	}
	if err := <-serverErr; err != nil {
		t.Fatal(err)
	}
}

type unexpectedRequest struct{ value string }

func (e *unexpectedRequest) Error() string { return "unexpected request: " + e.value }
