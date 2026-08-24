package invites

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
)

func Generate(secret []byte) (raw string, digest []byte, err error) {
	if len(secret) < 32 {
		return "", nil, errors.New("invite digest secret must contain at least 32 bytes")
	}
	value := make([]byte, 24)
	if _, err := rand.Read(value); err != nil {
		return "", nil, err
	}
	raw = base64.RawURLEncoding.EncodeToString(value)
	return raw, Digest(secret, raw), nil
}

func Digest(secret []byte, raw string) []byte {
	digest := hmac.New(sha256.New, secret)
	_, _ = digest.Write([]byte(raw))
	return digest.Sum(nil)
}
