package store

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var (
	ErrGroupNotFound        = errors.New("group not found")
	ErrGroupAccountNotFound = errors.New("group account not found")
	ErrGroupForbidden       = errors.New("group operation forbidden")
	ErrRoleEscalation       = errors.New("role escalation is not allowed")
	ErrLastGroupAdmin       = errors.New("the last group administrator cannot be removed")
	ErrLastSuperAdmin       = errors.New("the last super administrator cannot be disabled")
	ErrSuperAdminExists     = errors.New("a super administrator already exists")
	ErrAlreadyGroupMember   = errors.New("user is already a member of this group")
)

type Workspace struct {
	ID          uuid.UUID  `json:"id"`
	Kind        string     `json:"kind"`
	DisplayName string     `json:"display_name,omitempty"`
	Role        string     `json:"role,omitempty"`
	OwnerUserID *uuid.UUID `json:"owner_user_id,omitempty"`
	GroupID     *uuid.UUID `json:"group_id,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
}

type Group struct {
	ID                     uuid.UUID  `json:"id"`
	WorkspaceID            uuid.UUID  `json:"workspace_id"`
	Name                   string     `json:"name"`
	Archived               bool       `json:"archived"`
	CollaborationEnabledAt *time.Time `json:"collaboration_enabled_at,omitempty"`
	CreatedByUserID        uuid.UUID  `json:"created_by_user_id"`
	CreatedAt              time.Time  `json:"created_at"`
}

type GroupAccount struct {
	ID          uuid.UUID `json:"id"`
	GroupID     uuid.UUID `json:"group_id"`
	AccountCode string    `json:"account_code"`
	DisplayName string    `json:"display_name"`
	Role        string    `json:"role"`
	Active      bool      `json:"active"`
	CreatedAt   time.Time `json:"created_at"`
}

type GroupAccountLink struct {
	ID              uuid.UUID  `json:"id"`
	GroupID         uuid.UUID  `json:"group_id"`
	GroupAccountID  uuid.UUID  `json:"group_account_id"`
	UserID          uuid.UUID  `json:"user_id"`
	BoundAt         time.Time  `json:"bound_at"`
	UnboundAt       *time.Time `json:"unbound_at,omitempty"`
	BoundByUserID   uuid.UUID  `json:"bound_by_user_id"`
	UnboundByUserID *uuid.UUID `json:"unbound_by_user_id,omitempty"`
	UnboundReason   *string    `json:"unbound_reason,omitempty"`
}

type auditRequestIDKey struct{}

func WithAuditRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, auditRequestIDKey{}, requestID)
}

func auditRequestID(ctx context.Context) string {
	value, _ := ctx.Value(auditRequestIDKey{}).(string)
	return value
}

func (s *Store) EnsurePersonalWorkspace(ctx context.Context, userID uuid.UUID) (Workspace, error) {
	workspace := Workspace{ID: uuid.New(), Kind: "personal", OwnerUserID: &userID}
	err := s.pool.QueryRow(ctx, `
		INSERT INTO workspaces(id, kind, owner_user_id)
		VALUES($1, 'personal', $2)
		ON CONFLICT (owner_user_id) WHERE kind = 'personal' DO UPDATE SET owner_user_id = EXCLUDED.owner_user_id
		RETURNING id, kind, owner_user_id, group_id, created_at`, workspace.ID, userID,
	).Scan(&workspace.ID, &workspace.Kind, &workspace.OwnerUserID, &workspace.GroupID, &workspace.CreatedAt)
	if err != nil {
		return Workspace{}, fmt.Errorf("ensure personal workspace: %w", err)
	}
	return workspace, nil
}

func (s *Store) CreateGroup(ctx context.Context, creatorID uuid.UUID, name string) (Group, GroupAccount, GroupAccountLink, error) {
	name = strings.TrimSpace(name)
	if name == "" || len(name) > 100 {
		return Group{}, GroupAccount{}, GroupAccountLink{}, errors.New("group name must contain between 1 and 100 characters")
	}
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return Group{}, GroupAccount{}, GroupAccountLink{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var username string
	if err := tx.QueryRow(ctx, `SELECT username FROM users WHERE id = $1 AND disabled_at IS NULL`, creatorID).Scan(&username); err != nil {
		return Group{}, GroupAccount{}, GroupAccountLink{}, err
	}
	group := Group{ID: uuid.New(), WorkspaceID: uuid.New(), Name: name, CreatedByUserID: creatorID}
	if _, err := tx.Exec(ctx, `
		INSERT INTO workspaces(id, kind, group_id) VALUES($1, 'group', $2)`, group.WorkspaceID, group.ID); err != nil {
		return Group{}, GroupAccount{}, GroupAccountLink{}, fmt.Errorf("create group workspace: %w", err)
	}
	if err := tx.QueryRow(ctx, `
		INSERT INTO groups(id, workspace_id, name, created_by_user_id)
		VALUES($1, $2, $3, $4)
		RETURNING archived, collaboration_enabled_at, created_at`,
		group.ID, group.WorkspaceID, group.Name, group.CreatedByUserID,
	).Scan(&group.Archived, &group.CollaborationEnabledAt, &group.CreatedAt); err != nil {
		return Group{}, GroupAccount{}, GroupAccountLink{}, fmt.Errorf("create group: %w", err)
	}
	account := GroupAccount{
		ID:          uuid.New(),
		GroupID:     group.ID,
		AccountCode: "owner-" + strings.ToLower(strings.ReplaceAll(accountSuffix(group.ID), "-", "")),
		DisplayName: username,
		Role:        "L2",
		Active:      true,
	}
	if err := tx.QueryRow(ctx, `
		INSERT INTO group_accounts(id, group_id, account_code, display_name, role)
		VALUES($1, $2, $3, $4, $5)
		RETURNING active, created_at`,
		account.ID, account.GroupID, account.AccountCode, account.DisplayName, account.Role,
	).Scan(&account.Active, &account.CreatedAt); err != nil {
		return Group{}, GroupAccount{}, GroupAccountLink{}, fmt.Errorf("create group account: %w", err)
	}
	link := GroupAccountLink{ID: uuid.New(), GroupID: group.ID, GroupAccountID: account.ID, UserID: creatorID, BoundByUserID: creatorID}
	if err := tx.QueryRow(ctx, `
		INSERT INTO group_account_links(id, group_id, group_account_id, user_id, bound_by_user_id)
		VALUES($1, $2, $3, $4, $5)
		RETURNING bound_at`,
		link.ID, link.GroupID, link.GroupAccountID, link.UserID, link.BoundByUserID,
	).Scan(&link.BoundAt); err != nil {
		return Group{}, GroupAccount{}, GroupAccountLink{}, fmt.Errorf("bind group creator: %w", err)
	}
	if err := insertAuditEvent(ctx, tx, creatorID, &group.ID, "group.create", "group", group.ID); err != nil {
		return Group{}, GroupAccount{}, GroupAccountLink{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return Group{}, GroupAccount{}, GroupAccountLink{}, err
	}
	return group, account, link, nil
}

func accountSuffix(id uuid.UUID) string { return id.String()[:8] }

func (s *Store) GroupByID(ctx context.Context, groupID uuid.UUID) (Group, error) {
	var group Group
	err := s.pool.QueryRow(ctx, `
		SELECT id, workspace_id, name, archived, collaboration_enabled_at, created_by_user_id, created_at
		FROM groups WHERE id = $1`, groupID,
	).Scan(&group.ID, &group.WorkspaceID, &group.Name, &group.Archived, &group.CollaborationEnabledAt, &group.CreatedByUserID, &group.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Group{}, ErrGroupNotFound
	}
	if err != nil {
		return Group{}, err
	}
	return group, nil
}

func (s *Store) GroupAccessRole(ctx context.Context, userID, groupID uuid.UUID) (string, error) {
	var role string
	err := s.pool.QueryRow(ctx, `
		SELECT CASE
			WHEN EXISTS(SELECT 1 FROM server_roles WHERE user_id = $1 AND role = 'L3' AND active) THEN 'L3'
			ELSE COALESCE((
				SELECT account.role
				FROM group_account_links link
				JOIN group_accounts account ON account.id = link.group_account_id
				WHERE link.user_id = $1 AND link.group_id = $2 AND link.unbound_at IS NULL AND account.active
			), '')
		END`, userID, groupID).Scan(&role)
	if err != nil {
		return "", err
	}
	if role == "" {
		return "", ErrGroupForbidden
	}
	return role, nil
}

func (s *Store) CreateGroupAccount(ctx context.Context, actorID, groupID uuid.UUID, accountCode, displayName, role string) (GroupAccount, error) {
	accountCode = strings.TrimSpace(accountCode)
	displayName = strings.TrimSpace(displayName)
	role = strings.ToUpper(strings.TrimSpace(role))
	if role == "" {
		role = "L1"
	}
	if accountCode == "" || len(accountCode) > 64 || displayName == "" || len(displayName) > 100 {
		return GroupAccount{}, errors.New("invalid group account")
	}
	if role != "L1" && role != "L2" {
		return GroupAccount{}, ErrRoleEscalation
	}
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return GroupAccount{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if err := lockGroup(ctx, tx, groupID); err != nil {
		return GroupAccount{}, err
	}
	if err := requireGroupManager(ctx, tx, actorID, groupID); err != nil {
		return GroupAccount{}, err
	}
	account := GroupAccount{ID: uuid.New(), GroupID: groupID, AccountCode: accountCode, DisplayName: displayName, Role: role}
	err = tx.QueryRow(ctx, `
		INSERT INTO group_accounts(id, group_id, account_code, display_name, role)
		VALUES($1, $2, $3, $4, $5)
		RETURNING active, created_at`, account.ID, account.GroupID, account.AccountCode, account.DisplayName, account.Role,
	).Scan(&account.Active, &account.CreatedAt)
	if err != nil {
		return GroupAccount{}, fmt.Errorf("create group account: %w", err)
	}
	if err := insertAuditEvent(ctx, tx, actorID, &groupID, "group_account.create", "group_account", account.ID); err != nil {
		return GroupAccount{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return GroupAccount{}, err
	}
	return account, nil
}

func (s *Store) ListGroupAccounts(ctx context.Context, groupID uuid.UUID) ([]GroupAccount, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, group_id, account_code, display_name, role, active, created_at
		FROM group_accounts WHERE group_id = $1 ORDER BY account_code, id`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	accounts := make([]GroupAccount, 0)
	for rows.Next() {
		var account GroupAccount
		if err := rows.Scan(&account.ID, &account.GroupID, &account.AccountCode, &account.DisplayName, &account.Role, &account.Active, &account.CreatedAt); err != nil {
			return nil, err
		}
		accounts = append(accounts, account)
	}
	return accounts, rows.Err()
}

func (s *Store) SetCollaborationEnabled(ctx context.Context, actorID, groupID uuid.UUID) error {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if err := lockGroup(ctx, tx, groupID); err != nil {
		return err
	}
	if err := requireGroupManager(ctx, tx, actorID, groupID); err != nil {
		return err
	}
	command, err := tx.Exec(ctx, `UPDATE groups SET collaboration_enabled_at = COALESCE(collaboration_enabled_at, now()) WHERE id = $1`, groupID)
	if err != nil {
		return err
	}
	if command.RowsAffected() != 1 {
		return ErrGroupNotFound
	}
	if err := insertAuditEvent(ctx, tx, actorID, &groupID, "group.collaboration_enable", "group", groupID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func lockGroup(ctx context.Context, tx pgx.Tx, groupID uuid.UUID) error {
	var id uuid.UUID
	if err := tx.QueryRow(ctx, `SELECT id FROM groups WHERE id = $1 FOR UPDATE`, groupID).Scan(&id); errors.Is(err, pgx.ErrNoRows) {
		return ErrGroupNotFound
	} else {
		return err
	}
}

func requireGroupManager(ctx context.Context, tx pgx.Tx, actorID, groupID uuid.UUID) error {
	var allowed bool
	err := tx.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM server_roles WHERE user_id = $1 AND role = 'L3' AND active
		) OR EXISTS(
			SELECT 1
			FROM group_account_links link
			JOIN group_accounts account ON account.id = link.group_account_id
			WHERE link.user_id = $1 AND link.group_id = $2 AND link.unbound_at IS NULL
			  AND account.role = 'L2' AND account.active
		)`, actorID, groupID).Scan(&allowed)
	if err != nil {
		return err
	}
	if !allowed {
		return ErrGroupForbidden
	}
	return nil
}

func (s *Store) BindGroupAccount(ctx context.Context, actorID, groupID, accountID, targetUserID uuid.UUID) (GroupAccountLink, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return GroupAccountLink{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if err := lockGroup(ctx, tx, groupID); err != nil {
		return GroupAccountLink{}, err
	}
	if err := requireGroupManager(ctx, tx, actorID, groupID); err != nil {
		return GroupAccountLink{}, err
	}
	var active bool
	if err := tx.QueryRow(ctx, `SELECT active FROM group_accounts WHERE id = $1 AND group_id = $2 FOR UPDATE`, accountID, groupID).Scan(&active); errors.Is(err, pgx.ErrNoRows) {
		return GroupAccountLink{}, ErrGroupAccountNotFound
	} else if err != nil {
		return GroupAccountLink{}, err
	} else if !active {
		return GroupAccountLink{}, errors.New("group account is inactive")
	}
	var existing bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM group_account_links WHERE group_id = $1 AND user_id = $2 AND unbound_at IS NULL)`, groupID, targetUserID).Scan(&existing); err != nil {
		return GroupAccountLink{}, err
	}
	if existing {
		return GroupAccountLink{}, ErrAlreadyGroupMember
	}
	var targetActive bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE id = $1 AND disabled_at IS NULL)`, targetUserID).Scan(&targetActive); err != nil {
		return GroupAccountLink{}, err
	}
	if !targetActive {
		return GroupAccountLink{}, ErrGroupForbidden
	}
	link := GroupAccountLink{ID: uuid.New(), GroupID: groupID, GroupAccountID: accountID, UserID: targetUserID, BoundByUserID: actorID}
	if err := tx.QueryRow(ctx, `
		INSERT INTO group_account_links(id, group_id, group_account_id, user_id, bound_by_user_id)
		VALUES($1, $2, $3, $4, $5)
		RETURNING bound_at`, link.ID, link.GroupID, link.GroupAccountID, link.UserID, link.BoundByUserID,
	).Scan(&link.BoundAt); err != nil {
		return GroupAccountLink{}, fmt.Errorf("bind group account: %w", err)
	}
	if err := insertAuditEvent(ctx, tx, actorID, &groupID, "group_account.bind", "group_account", accountID); err != nil {
		return GroupAccountLink{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return GroupAccountLink{}, err
	}
	return link, nil
}

func (s *Store) UnbindGroupAccount(ctx context.Context, actorID, groupID, accountID uuid.UUID, reason string) error {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if err := lockGroup(ctx, tx, groupID); err != nil {
		return err
	}
	if err := requireGroupManager(ctx, tx, actorID, groupID); err != nil {
		return err
	}
	var role string
	if err := tx.QueryRow(ctx, `
		SELECT account.role
		FROM group_accounts account
		JOIN group_account_links link ON link.group_account_id = account.id AND link.unbound_at IS NULL
		WHERE account.id = $1 AND account.group_id = $2 FOR UPDATE`, accountID, groupID).Scan(&role); errors.Is(err, pgx.ErrNoRows) {
		return ErrGroupAccountNotFound
	} else if err != nil {
		return err
	}
	if role == "L2" {
		var count int
		if err := tx.QueryRow(ctx, `
			SELECT count(*) FROM group_accounts account
			JOIN group_account_links link ON link.group_account_id = account.id AND link.unbound_at IS NULL
			WHERE account.group_id = $1 AND account.active AND account.role = 'L2'`, groupID).Scan(&count); err != nil {
			return err
		}
		if count <= 1 {
			return ErrLastGroupAdmin
		}
	}
	_, err = tx.Exec(ctx, `
		UPDATE group_account_links
		SET unbound_at = now(), unbound_by_user_id = $1, unbound_reason = NULLIF($2, '')
		WHERE group_account_id = $3 AND group_id = $4 AND unbound_at IS NULL`, actorID, strings.TrimSpace(reason), accountID, groupID)
	if err != nil {
		return err
	}
	if err := insertAuditEvent(ctx, tx, actorID, &groupID, "group_account.unbind", "group_account", accountID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) SetGroupAccountRole(ctx context.Context, actorID, groupID, accountID uuid.UUID, role string) error {
	role = strings.ToUpper(strings.TrimSpace(role))
	if role != "L1" && role != "L2" {
		return ErrRoleEscalation
	}
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if err := lockGroup(ctx, tx, groupID); err != nil {
		return err
	}
	if err := requireGroupManager(ctx, tx, actorID, groupID); err != nil {
		return err
	}
	var currentRole string
	var currentlyBound bool
	if err := tx.QueryRow(ctx, `
		SELECT role, EXISTS(
			SELECT 1 FROM group_account_links WHERE group_account_id = $1 AND unbound_at IS NULL
		)
		FROM group_accounts WHERE id = $1 AND group_id = $2 AND active FOR UPDATE`, accountID, groupID).Scan(&currentRole, &currentlyBound); errors.Is(err, pgx.ErrNoRows) {
		return ErrGroupAccountNotFound
	} else if err != nil {
		return err
	}
	if currentlyBound && currentRole == "L2" && role != "L2" {
		var count int
		if err := tx.QueryRow(ctx, `
			SELECT count(*) FROM group_accounts account
			JOIN group_account_links link ON link.group_account_id = account.id AND link.unbound_at IS NULL
			WHERE account.group_id = $1 AND account.active AND account.role = 'L2'`, groupID).Scan(&count); err != nil {
			return err
		}
		if count <= 1 {
			return ErrLastGroupAdmin
		}
	}
	if _, err := tx.Exec(ctx, `UPDATE group_accounts SET role = $1 WHERE id = $2 AND group_id = $3`, role, accountID, groupID); err != nil {
		return err
	}
	if err := insertAuditEvent(ctx, tx, actorID, &groupID, "group_account.role_change", "group_account", accountID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) SetServerSuperAdmin(ctx context.Context, actorID, targetUserID uuid.UUID, active bool) error {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx, `LOCK TABLE server_roles IN SHARE ROW EXCLUSIVE MODE`); err != nil {
		return err
	}
	var actorIsL3 bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM server_roles WHERE user_id = $1 AND role = 'L3' AND active)`, actorID).Scan(&actorIsL3); err != nil {
		return err
	}
	if !actorIsL3 {
		return ErrGroupForbidden
	}
	if active {
		var targetActive bool
		if err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE id = $1 AND disabled_at IS NULL)`, targetUserID).Scan(&targetActive); err != nil {
			return err
		}
		if !targetActive {
			return pgx.ErrNoRows
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO server_roles(user_id, role, active, assigned_by_user_id)
			VALUES($1, 'L3', true, $2)
			ON CONFLICT(user_id) DO UPDATE SET role = 'L3', active = true, assigned_by_user_id = EXCLUDED.assigned_by_user_id, assigned_at = now()`, targetUserID, actorID); err != nil {
			return err
		}
		if err := insertAuditEvent(ctx, tx, actorID, nil, "server_role.grant", "user", targetUserID); err != nil {
			return err
		}
		return tx.Commit(ctx)
	}
	var count int
	if err := tx.QueryRow(ctx, `SELECT count(*) FROM server_roles WHERE role = 'L3' AND active`).Scan(&count); err != nil {
		return err
	}
	if count <= 1 {
		return ErrLastSuperAdmin
	}
	if _, err := tx.Exec(ctx, `UPDATE server_roles SET active = false WHERE user_id = $1 AND role = 'L3'`, targetUserID); err != nil {
		return err
	}
	if err := insertAuditEvent(ctx, tx, actorID, nil, "server_role.revoke", "user", targetUserID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) BootstrapSuperAdmin(ctx context.Context, userID uuid.UUID) error {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx, `LOCK TABLE server_roles IN SHARE ROW EXCLUSIVE MODE`); err != nil {
		return err
	}
	var exists bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM server_roles WHERE role = 'L3' AND active)`).Scan(&exists); err != nil {
		return err
	}
	if exists {
		return ErrSuperAdminExists
	}
	if _, err := tx.Exec(ctx, `INSERT INTO server_roles(user_id, role, active) VALUES($1, 'L3', true)`, userID); err != nil {
		return err
	}
	if err := insertAuditEvent(ctx, tx, userID, nil, "server_role.bootstrap", "user", userID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) SetUserDisabled(ctx context.Context, actorID, targetUserID uuid.UUID, disabled bool) error {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx, `LOCK TABLE server_roles IN SHARE ROW EXCLUSIVE MODE`); err != nil {
		return err
	}
	var actorIsL3 bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM server_roles WHERE user_id = $1 AND role = 'L3' AND active)`, actorID).Scan(&actorIsL3); err != nil {
		return err
	}
	if !actorIsL3 {
		return ErrGroupForbidden
	}
	if disabled {
		var targetIsL3 bool
		if err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM server_roles WHERE user_id = $1 AND role = 'L3' AND active)`, targetUserID).Scan(&targetIsL3); err != nil {
			return err
		}
		if targetIsL3 {
			var count int
			if err := tx.QueryRow(ctx, `SELECT count(*) FROM server_roles WHERE role = 'L3' AND active`).Scan(&count); err != nil {
				return err
			}
			if count <= 1 {
				return ErrLastSuperAdmin
			}
			if _, err := tx.Exec(ctx, `UPDATE server_roles SET active = false WHERE user_id = $1`, targetUserID); err != nil {
				return err
			}
		}
		command, err := tx.Exec(ctx, `UPDATE users SET disabled_at = now() WHERE id = $1 AND disabled_at IS NULL`, targetUserID)
		if err != nil {
			return err
		}
		if command.RowsAffected() != 1 {
			return pgx.ErrNoRows
		}
		if _, err := tx.Exec(ctx, `UPDATE sessions SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`, targetUserID); err != nil {
			return err
		}
	} else {
		command, err := tx.Exec(ctx, `UPDATE users SET disabled_at = NULL WHERE id = $1 AND disabled_at IS NOT NULL`, targetUserID)
		if err != nil {
			return err
		}
		if command.RowsAffected() != 1 {
			return pgx.ErrNoRows
		}
	}
	action := "user.enable"
	if disabled {
		action = "user.disable"
	}
	if err := insertAuditEvent(ctx, tx, actorID, nil, action, "user", targetUserID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) ListAccessibleWorkspaces(ctx context.Context, userID uuid.UUID) ([]Workspace, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT workspace.id, workspace.kind,
		       CASE WHEN workspace.kind='personal' THEN '个人任务' ELSE group_row.name END,
		       CASE
		         WHEN workspace.kind='personal' THEN 'L1'
		         WHEN EXISTS (SELECT 1 FROM server_roles role WHERE role.user_id=$1 AND role.role='L3' AND role.active) THEN 'L3'
		         ELSE COALESCE(account.role, '')
		       END,
		       workspace.owner_user_id, workspace.group_id, workspace.created_at
		FROM workspaces workspace
		LEFT JOIN groups group_row ON group_row.id = workspace.group_id
		LEFT JOIN group_account_links link ON link.group_id=group_row.id AND link.user_id=$1 AND link.unbound_at IS NULL
		LEFT JOIN group_accounts account ON account.id=link.group_account_id AND account.active
		WHERE workspace.owner_user_id = $1
		   OR EXISTS (
			SELECT 1 FROM group_account_links link
			WHERE link.group_id = group_row.id AND link.user_id = $1 AND link.unbound_at IS NULL
		   )
		   OR EXISTS (
			SELECT 1 FROM server_roles role
			WHERE role.user_id = $1 AND role.role = 'L3' AND role.active
		   )
		ORDER BY workspace.kind, workspace.created_at, workspace.id`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	workspaces := make([]Workspace, 0)
	for rows.Next() {
		var workspace Workspace
		if err := rows.Scan(&workspace.ID, &workspace.Kind, &workspace.DisplayName, &workspace.Role, &workspace.OwnerUserID, &workspace.GroupID, &workspace.CreatedAt); err != nil {
			return nil, err
		}
		workspaces = append(workspaces, workspace)
	}
	return workspaces, rows.Err()
}

func (s *Store) WorkspaceCursor(ctx context.Context, workspaceID uuid.UUID) (int64, error) {
	var cursor int64
	err := s.pool.QueryRow(ctx, `SELECT COALESCE(MAX(cursor), 0) FROM sync_changes WHERE workspace_id = $1`, workspaceID).Scan(&cursor)
	return cursor, err
}

func (s *Store) WriteAuditEvent(ctx context.Context, actorUserID, groupID *uuid.UUID, action, targetType string, targetID *uuid.UUID, outcome, requestID string, details []byte) error {
	if strings.TrimSpace(action) == "" || strings.TrimSpace(targetType) == "" {
		return errors.New("audit action and target type are required")
	}
	if outcome != "success" && outcome != "failure" {
		return errors.New("audit outcome must be success or failure")
	}
	if len(details) == 0 {
		details = []byte(`{}`)
	}
	_, err := s.pool.Exec(ctx, `
		INSERT INTO audit_events(id, actor_user_id, group_id, action, target_type, target_id, outcome, request_id, details)
		VALUES($1, $2, $3, $4, $5, $6, $7, NULLIF($8, ''), $9::jsonb)`,
		uuid.New(), actorUserID, groupID, action, targetType, targetID, outcome, requestID, details)
	return err
}

func insertAuditEvent(ctx context.Context, tx pgx.Tx, actorID uuid.UUID, groupID *uuid.UUID, action, targetType string, targetID uuid.UUID) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO audit_events(id, actor_user_id, group_id, action, target_type, target_id, outcome, request_id)
		VALUES($1, $2, $3, $4, $5, $6, 'success', NULLIF($7, ''))`, uuid.New(), actorID, groupID, action, targetType, targetID, auditRequestID(ctx))
	return err
}
