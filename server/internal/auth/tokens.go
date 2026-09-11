package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type TokenManager struct {
	secret    []byte
	accessTTL time.Duration
	issuer    string
	clock     func() time.Time
}

type AccessClaims struct {
	DeviceID string   `json:"device_id"`
	Scopes   []string `json:"scopes,omitempty"`
	jwt.RegisteredClaims
}

func NewTokenManager(secret []byte, accessTTL time.Duration, issuer string) *TokenManager {
	return &TokenManager{
		secret:    append([]byte(nil), secret...),
		accessTTL: accessTTL,
		issuer:    issuer,
		clock:     time.Now,
	}
}

func (m *TokenManager) IssueAccess(userID, deviceID uuid.UUID) (string, time.Time, error) {
	return m.IssueAccessWithScopes(userID, deviceID, nil)
}

func (m *TokenManager) IssueAccessWithScopes(userID, deviceID uuid.UUID, scopes []string) (string, time.Time, error) {
	return m.issueAccess(userID, deviceID, scopes, m.accessTTL)
}

func (m *TokenManager) IssueAccessWithScopesTTL(userID, deviceID uuid.UUID, scopes []string, ttl time.Duration) (string, time.Time, error) {
	if ttl <= 0 {
		return "", time.Time{}, errors.New("token ttl must be positive")
	}
	return m.issueAccess(userID, deviceID, scopes, ttl)
}

func (m *TokenManager) issueAccess(userID, deviceID uuid.UUID, scopes []string, ttl time.Duration) (string, time.Time, error) {
	now := m.clock().UTC()
	expiresAt := now.Add(ttl)
	claims := AccessClaims{
		DeviceID: deviceID.String(),
		Scopes:   append([]string(nil), scopes...),
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    m.issuer,
			Subject:   userID.String(),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			ID:        uuid.NewString(),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(m.secret)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("sign access token: %w", err)
	}
	return signed, expiresAt, nil
}

func (m *TokenManager) ParseAccess(raw string) (uuid.UUID, uuid.UUID, error) {
	userID, deviceID, _, err := m.ParseAccessWithScopes(raw)
	return userID, deviceID, err
}

func (m *TokenManager) ParseAccessWithScopes(raw string) (uuid.UUID, uuid.UUID, []string, error) {
	claims := new(AccessClaims)
	token, err := jwt.ParseWithClaims(
		raw,
		claims,
		func(token *jwt.Token) (any, error) {
			if token.Method != jwt.SigningMethodHS256 {
				return nil, errors.New("unexpected signing method")
			}
			return m.secret, nil
		},
		jwt.WithIssuer(m.issuer),
		jwt.WithExpirationRequired(),
	)
	if err != nil || !token.Valid {
		return uuid.Nil, uuid.Nil, nil, errors.New("invalid access token")
	}
	userID, err := uuid.Parse(claims.Subject)
	if err != nil {
		return uuid.Nil, uuid.Nil, nil, errors.New("invalid access token subject")
	}
	deviceID, err := uuid.Parse(claims.DeviceID)
	if err != nil {
		return uuid.Nil, uuid.Nil, nil, errors.New("invalid access token device")
	}
	return userID, deviceID, append([]string(nil), claims.Scopes...), nil
}

func NewRefreshToken() (raw string, hash []byte, err error) {
	value := make([]byte, 32)
	if _, err = rand.Read(value); err != nil {
		return "", nil, fmt.Errorf("generate refresh token: %w", err)
	}
	raw = base64.RawURLEncoding.EncodeToString(value)
	digest := sha256.Sum256([]byte(raw))
	return raw, digest[:], nil
}

func HashRefreshToken(raw string) []byte {
	digest := sha256.Sum256([]byte(raw))
	return digest[:]
}
