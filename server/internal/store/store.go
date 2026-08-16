package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Store struct {
	pool *pgxpool.Pool
}

type User struct {
	ID           uuid.UUID `json:"id"`
	Username     string    `json:"username"`
	PasswordHash string    `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
}

type Device struct {
	ID       uuid.UUID  `json:"id"`
	UserID   uuid.UUID  `json:"user_id"`
	Name     string     `json:"name"`
	Platform string     `json:"platform"`
	LastSeen *time.Time `json:"last_seen_at"`
}

type Session struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	DeviceID  uuid.UUID
	ExpiresAt time.Time
}

func Open(ctx context.Context, databaseURL string) (*Store, error) {
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse database configuration: %w", err)
	}
	config.MaxConns = 10
	config.MinConns = 1
	config.MaxConnLifetime = time.Hour
	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}
	return &Store{pool: pool}, nil
}

func (s *Store) Close() {
	s.pool.Close()
}

func (s *Store) Ping(ctx context.Context) error {
	return s.pool.Ping(ctx)
}

func (s *Store) APIVersion(ctx context.Context) (string, error) {
	var version string
	if err := s.pool.QueryRow(
		ctx,
		`SELECT value FROM schema_metadata WHERE key = 'api_version'`,
	).Scan(&version); err != nil {
		return "", fmt.Errorf("read schema metadata: %w", err)
	}
	return version, nil
}

func (s *Store) CreateUser(ctx context.Context, username, passwordHash string) (User, error) {
	user := User{ID: uuid.New(), Username: username, PasswordHash: passwordHash}
	err := s.pool.QueryRow(
		ctx,
		`INSERT INTO users(id, username, password_hash)
		 VALUES($1, $2, $3)
		 RETURNING created_at`,
		user.ID,
		user.Username,
		user.PasswordHash,
	).Scan(&user.CreatedAt)
	if err != nil {
		return User{}, fmt.Errorf("create user: %w", err)
	}
	return user, nil
}

func (s *Store) UserByUsername(ctx context.Context, username string) (User, error) {
	var user User
	err := s.pool.QueryRow(
		ctx,
		`SELECT id, username, password_hash, created_at
		 FROM users WHERE username = $1`,
		username,
	).Scan(&user.ID, &user.Username, &user.PasswordHash, &user.CreatedAt)
	if err != nil {
		return User{}, err
	}
	return user, nil
}

func (s *Store) UserByID(ctx context.Context, userID uuid.UUID) (User, error) {
	var user User
	err := s.pool.QueryRow(
		ctx,
		`SELECT id, username, password_hash, created_at
		 FROM users WHERE id = $1`,
		userID,
	).Scan(&user.ID, &user.Username, &user.PasswordHash, &user.CreatedAt)
	if err != nil {
		return User{}, err
	}
	return user, nil
}

func (s *Store) DeviceByID(
	ctx context.Context,
	userID, deviceID uuid.UUID,
) (Device, error) {
	var device Device
	err := s.pool.QueryRow(
		ctx,
		`SELECT id, user_id, name, platform, last_seen_at
		 FROM devices
		 WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL`,
		deviceID,
		userID,
	).Scan(
		&device.ID,
		&device.UserID,
		&device.Name,
		&device.Platform,
		&device.LastSeen,
	)
	if err != nil {
		return Device{}, err
	}
	return device, nil
}

func (s *Store) UpsertDevice(
	ctx context.Context,
	userID uuid.UUID,
	requestedID *uuid.UUID,
	name, platform string,
) (Device, error) {
	deviceID := uuid.New()
	if requestedID != nil {
		deviceID = *requestedID
	}
	var device Device
	err := s.pool.QueryRow(
		ctx,
		`INSERT INTO devices(id, user_id, name, platform, last_seen_at)
		 VALUES($1, $2, $3, $4, now())
		 ON CONFLICT(id) DO UPDATE SET
		   name = EXCLUDED.name,
		   platform = EXCLUDED.platform,
		   last_seen_at = now(),
		   revoked_at = NULL
		 WHERE devices.user_id = EXCLUDED.user_id
		 RETURNING id, user_id, name, platform, last_seen_at`,
		deviceID,
		userID,
		name,
		platform,
	).Scan(
		&device.ID,
		&device.UserID,
		&device.Name,
		&device.Platform,
		&device.LastSeen,
	)
	if err != nil {
		return Device{}, fmt.Errorf("upsert device: %w", err)
	}
	return device, nil
}

func (s *Store) CreateSession(
	ctx context.Context,
	userID, deviceID uuid.UUID,
	refreshHash []byte,
	expiresAt time.Time,
) (Session, error) {
	session := Session{
		ID:        uuid.New(),
		UserID:    userID,
		DeviceID:  deviceID,
		ExpiresAt: expiresAt,
	}
	_, err := s.pool.Exec(
		ctx,
		`INSERT INTO sessions(
		   id, user_id, device_id, refresh_token_hash, expires_at
		 ) VALUES($1, $2, $3, $4, $5)`,
		session.ID,
		session.UserID,
		session.DeviceID,
		refreshHash,
		session.ExpiresAt,
	)
	if err != nil {
		return Session{}, fmt.Errorf("create session: %w", err)
	}
	return session, nil
}

func (s *Store) RotateSession(
	ctx context.Context,
	oldHash, newHash []byte,
	newExpiresAt time.Time,
) (Session, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return Session{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var current Session
	err = tx.QueryRow(
		ctx,
		`SELECT id, user_id, device_id, expires_at
		 FROM sessions
		 WHERE refresh_token_hash = $1
		   AND revoked_at IS NULL
		   AND expires_at > now()
		 FOR UPDATE`,
		oldHash,
	).Scan(&current.ID, &current.UserID, &current.DeviceID, &current.ExpiresAt)
	if err != nil {
		return Session{}, err
	}
	command, err := tx.Exec(
		ctx,
		`UPDATE sessions
		 SET refresh_token_hash = $1, expires_at = $2, rotated_at = now()
		 WHERE id = $3 AND revoked_at IS NULL`,
		newHash,
		newExpiresAt,
		current.ID,
	)
	if err != nil || command.RowsAffected() != 1 {
		return Session{}, errors.New("refresh session could not be rotated")
	}
	current.ExpiresAt = newExpiresAt
	if err := tx.Commit(ctx); err != nil {
		return Session{}, err
	}
	return current, nil
}

func (s *Store) RevokeSession(ctx context.Context, refreshHash []byte) error {
	_, err := s.pool.Exec(
		ctx,
		`UPDATE sessions SET revoked_at = now()
		 WHERE refresh_token_hash = $1 AND revoked_at IS NULL`,
		refreshHash,
	)
	return err
}

func IsNotFound(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}
