package store

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var ErrAdminForbidden = errors.New("admin access forbidden")

type AdminUser struct {
	ID         uuid.UUID  `json:"id"`
	Username   string     `json:"username"`
	CreatedAt  time.Time  `json:"created_at"`
	DisabledAt *time.Time `json:"disabled_at,omitempty"`
	Role       string     `json:"role"`
}

func (s *Store) AdminRole(ctx context.Context, userID uuid.UUID) (string, error) {
	var role string
	err := s.pool.QueryRow(ctx, `
		SELECT CASE
			WHEN EXISTS (SELECT 1 FROM server_roles WHERE user_id=$1 AND role='L3' AND active) THEN 'L3'
			WHEN EXISTS (
				SELECT 1 FROM group_account_links link
				JOIN group_accounts account ON account.id=link.group_account_id
				WHERE link.user_id=$1 AND link.unbound_at IS NULL AND account.active AND account.role='L2'
			) THEN 'L2'
			ELSE '' END`, userID).Scan(&role)
	if err != nil {
		return "", err
	}
	if role == "" {
		return "", ErrAdminForbidden
	}
	return role, nil
}

func (s *Store) AdminUsers(ctx context.Context) ([]AdminUser, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT users.id, users.username, users.created_at, users.disabled_at,
		       COALESCE(server_roles.role, '')
		FROM users LEFT JOIN server_roles ON server_roles.user_id=users.id AND server_roles.active
		ORDER BY users.created_at DESC, users.id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	users := make([]AdminUser, 0)
	for rows.Next() {
		var user AdminUser
		if err := rows.Scan(&user.ID, &user.Username, &user.CreatedAt, &user.DisabledAt, &user.Role); err != nil {
			return nil, err
		}
		users = append(users, user)
	}
	return users, rows.Err()
}

func (s *Store) AdminGroups(ctx context.Context, userID uuid.UUID, role string) ([]Group, error) {
	query := `SELECT group_row.id, group_row.workspace_id, group_row.name, group_row.archived,
		group_row.collaboration_enabled_at, group_row.created_by_user_id, group_row.created_at
		FROM groups group_row`
	args := []any{}
	if role != "L3" {
		query += ` JOIN group_account_links link ON link.group_id=group_row.id
			JOIN group_accounts account ON account.id=link.group_account_id
			WHERE link.user_id=$1 AND link.unbound_at IS NULL AND account.active AND account.role='L2'`
		args = append(args, userID)
	}
	query += ` ORDER BY group_row.created_at DESC, group_row.id`
	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	groups := make([]Group, 0)
	for rows.Next() {
		var group Group
		if err := rows.Scan(&group.ID, &group.WorkspaceID, &group.Name, &group.Archived, &group.CollaborationEnabledAt, &group.CreatedByUserID, &group.CreatedAt); err != nil {
			return nil, err
		}
		groups = append(groups, group)
	}
	return groups, rows.Err()
}

func (s *Store) AdminGroupAccounts(ctx context.Context, actorID, groupID uuid.UUID, role string) ([]GroupAccount, error) {
	if role != "L3" {
		var allowed bool
		if err := s.pool.QueryRow(ctx, `SELECT EXISTS(
			SELECT 1 FROM group_account_links link JOIN group_accounts account ON account.id=link.group_account_id
			WHERE link.user_id=$1 AND link.group_id=$2 AND link.unbound_at IS NULL AND account.active AND account.role='L2'
		)`, actorID, groupID).Scan(&allowed); err != nil {
			return nil, err
		}
		if !allowed {
			return nil, ErrAdminForbidden
		}
	}
	return s.ListGroupAccounts(ctx, groupID)
}

func (s *Store) AdminUserByID(ctx context.Context, userID uuid.UUID) (AdminUser, error) {
	var user AdminUser
	err := s.pool.QueryRow(ctx, `
		SELECT users.id, users.username, users.created_at, users.disabled_at, COALESCE(server_roles.role, '')
		FROM users LEFT JOIN server_roles ON server_roles.user_id=users.id AND server_roles.active
		WHERE users.id=$1`, userID).Scan(&user.ID, &user.Username, &user.CreatedAt, &user.DisabledAt, &user.Role)
	if errors.Is(err, pgx.ErrNoRows) {
		return AdminUser{}, pgx.ErrNoRows
	}
	return user, err
}
