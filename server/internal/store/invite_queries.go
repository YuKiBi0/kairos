package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

var (
	ErrInviteInvalid      = errors.New("invite code is invalid")
	ErrInviteExpired      = errors.New("invite has expired")
	ErrInviteRevoked      = errors.New("invite has been revoked")
	ErrInviteExhausted    = errors.New("invite has no remaining uses")
	ErrInviteAccountBound = errors.New("invite target account is already bound")
)

type GroupInvite struct {
	ID                   uuid.UUID  `json:"id"`
	GroupID              uuid.UUID  `json:"group_id"`
	TargetGroupAccountID *uuid.UUID `json:"target_group_account_id,omitempty"`
	MaxUses              *int       `json:"max_uses,omitempty"`
	UseCount             int        `json:"use_count"`
	ExpiresAt            time.Time  `json:"expires_at"`
	RevokedAt            *time.Time `json:"revoked_at,omitempty"`
	CreatedByUserID      uuid.UUID  `json:"created_by_user_id"`
	CreatedAt            time.Time  `json:"created_at"`
}

type GroupInviteRedemption struct {
	ID             uuid.UUID `json:"id"`
	InviteID       uuid.UUID `json:"invite_id"`
	GroupID        uuid.UUID `json:"group_id"`
	UserID         uuid.UUID `json:"user_id"`
	GroupAccountID uuid.UUID `json:"group_account_id"`
	IdempotencyKey uuid.UUID `json:"idempotency_key"`
	RedeemedAt     time.Time `json:"redeemed_at"`
}

func (s *Store) CreateGroupInvite(ctx context.Context, actorID, groupID uuid.UUID, digest []byte, targetAccountID *uuid.UUID, maxUses *int, expiresAt time.Time) (GroupInvite, error) {
	if len(digest) == 0 {
		return GroupInvite{}, ErrInviteInvalid
	}
	now := time.Now().UTC()
	if !expiresAt.After(now) || expiresAt.After(now.Add(30*24*time.Hour)) {
		return GroupInvite{}, ErrInviteExpired
	}
	if maxUses != nil && *maxUses <= 0 {
		return GroupInvite{}, ErrInviteExhausted
	}
	if targetAccountID != nil && maxUses == nil {
		one := 1
		maxUses = &one
	}
	if targetAccountID != nil && *maxUses != 1 {
		return GroupInvite{}, errors.New("targeted invite must have exactly one use")
	}
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return GroupInvite{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if err := lockGroup(ctx, tx, groupID); err != nil {
		return GroupInvite{}, err
	}
	if err := requireGroupManager(ctx, tx, actorID, groupID); err != nil {
		return GroupInvite{}, err
	}
	if targetAccountID != nil {
		var available bool
		if err := tx.QueryRow(ctx, `
			SELECT account.active AND NOT EXISTS(
				SELECT 1 FROM group_account_links link
				WHERE link.group_account_id = account.id AND link.unbound_at IS NULL
			)
			FROM group_accounts account
			WHERE account.id = $1 AND account.group_id = $2
			FOR UPDATE`, *targetAccountID, groupID).Scan(&available); errors.Is(err, pgx.ErrNoRows) {
			return GroupInvite{}, ErrGroupAccountNotFound
		} else if err != nil {
			return GroupInvite{}, err
		} else if !available {
			return GroupInvite{}, ErrInviteAccountBound
		}
	}
	invite := GroupInvite{ID: uuid.New(), GroupID: groupID, TargetGroupAccountID: targetAccountID, MaxUses: maxUses, ExpiresAt: expiresAt.UTC(), CreatedByUserID: actorID}
	err = tx.QueryRow(ctx, `
		INSERT INTO group_invites(id, group_id, code_digest, target_group_account_id, max_uses, expires_at, created_by_user_id, created_at)
		VALUES($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING use_count, revoked_at, created_at`,
		invite.ID, invite.GroupID, digest, invite.TargetGroupAccountID, invite.MaxUses, invite.ExpiresAt, invite.CreatedByUserID, now,
	).Scan(&invite.UseCount, &invite.RevokedAt, &invite.CreatedAt)
	if err != nil {
		return GroupInvite{}, fmt.Errorf("create group invite: %w", err)
	}
	if err := insertAuditEvent(ctx, tx, actorID, &groupID, "group_invite.create", "group_invite", invite.ID); err != nil {
		return GroupInvite{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return GroupInvite{}, err
	}
	return invite, nil
}

func (s *Store) ListGroupInvites(ctx context.Context, actorID, groupID uuid.UUID) ([]GroupInvite, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.RepeatableRead})
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if err := requireGroupManager(ctx, tx, actorID, groupID); err != nil {
		return nil, err
	}
	rows, err := tx.Query(ctx, `
		SELECT id, group_id, target_group_account_id, max_uses, use_count, expires_at, revoked_at, created_by_user_id, created_at
		FROM group_invites WHERE group_id = $1 ORDER BY created_at DESC, id`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]GroupInvite, 0)
	for rows.Next() {
		var invite GroupInvite
		if err := rows.Scan(&invite.ID, &invite.GroupID, &invite.TargetGroupAccountID, &invite.MaxUses, &invite.UseCount, &invite.ExpiresAt, &invite.RevokedAt, &invite.CreatedByUserID, &invite.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, invite)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return result, nil
}

func (s *Store) RevokeGroupInvite(ctx context.Context, actorID, groupID, inviteID uuid.UUID) error {
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
	command, err := tx.Exec(ctx, `
		UPDATE group_invites SET revoked_at = COALESCE(revoked_at, now())
		WHERE id = $1 AND group_id = $2`, inviteID, groupID)
	if err != nil {
		return err
	}
	if command.RowsAffected() != 1 {
		return ErrInviteInvalid
	}
	if err := insertAuditEvent(ctx, tx, actorID, &groupID, "group_invite.revoke", "group_invite", inviteID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) RedeemGroupInvite(ctx context.Context, userID uuid.UUID, digest []byte, idempotencyKey uuid.UUID) (GroupInviteRedemption, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return GroupInviteRedemption{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	var invite GroupInvite
	err = tx.QueryRow(ctx, `
		SELECT id, group_id, target_group_account_id, max_uses, use_count, expires_at, revoked_at, created_by_user_id, created_at
		FROM group_invites WHERE code_digest = $1 FOR UPDATE`, digest,
	).Scan(&invite.ID, &invite.GroupID, &invite.TargetGroupAccountID, &invite.MaxUses, &invite.UseCount, &invite.ExpiresAt, &invite.RevokedAt, &invite.CreatedByUserID, &invite.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return GroupInviteRedemption{}, ErrInviteInvalid
	}
	if err != nil {
		return GroupInviteRedemption{}, err
	}
	var existing GroupInviteRedemption
	err = tx.QueryRow(ctx, `
		SELECT id, invite_id, user_id, group_account_id, idempotency_key, redeemed_at
		FROM group_invite_redemptions
		WHERE invite_id = $1 AND user_id = $2 AND idempotency_key = $3`, invite.ID, userID, idempotencyKey,
	).Scan(&existing.ID, &existing.InviteID, &existing.UserID, &existing.GroupAccountID, &existing.IdempotencyKey, &existing.RedeemedAt)
	if err == nil {
		existing.GroupID = invite.GroupID
		if err := tx.Commit(ctx); err != nil {
			return GroupInviteRedemption{}, err
		}
		return existing, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return GroupInviteRedemption{}, err
	}
	now := time.Now().UTC()
	if invite.RevokedAt != nil {
		return GroupInviteRedemption{}, ErrInviteRevoked
	}
	if !invite.ExpiresAt.After(now) {
		return GroupInviteRedemption{}, ErrInviteExpired
	}
	if invite.MaxUses != nil && invite.UseCount >= *invite.MaxUses {
		return GroupInviteRedemption{}, ErrInviteExhausted
	}
	var alreadyMember bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS(
		SELECT 1 FROM group_account_links WHERE group_id = $1 AND user_id = $2 AND unbound_at IS NULL
	)`, invite.GroupID, userID).Scan(&alreadyMember); err != nil {
		return GroupInviteRedemption{}, err
	}
	if alreadyMember {
		return GroupInviteRedemption{}, ErrAlreadyGroupMember
	}
	var username string
	if err := tx.QueryRow(ctx, `SELECT username FROM users WHERE id = $1 AND disabled_at IS NULL`, userID).Scan(&username); errors.Is(err, pgx.ErrNoRows) {
		return GroupInviteRedemption{}, ErrGroupForbidden
	} else if err != nil {
		return GroupInviteRedemption{}, err
	}
	accountID := uuid.Nil
	if invite.TargetGroupAccountID != nil {
		accountID = *invite.TargetGroupAccountID
		var available bool
		if err := tx.QueryRow(ctx, `
			SELECT account.active AND NOT EXISTS(
				SELECT 1 FROM group_account_links link
				WHERE link.group_account_id = account.id AND link.unbound_at IS NULL
			)
			FROM group_accounts account
			WHERE account.id = $1 AND account.group_id = $2 FOR UPDATE`, accountID, invite.GroupID).Scan(&available); errors.Is(err, pgx.ErrNoRows) {
			return GroupInviteRedemption{}, ErrGroupAccountNotFound
		} else if err != nil {
			return GroupInviteRedemption{}, err
		} else if !available {
			return GroupInviteRedemption{}, ErrInviteAccountBound
		}
	} else {
		accountID = uuid.New()
		if _, err := tx.Exec(ctx, `
			INSERT INTO group_accounts(id, group_id, account_code, display_name, role)
			VALUES($1, $2, $3, $4, 'L1')`, accountID, invite.GroupID, "member-"+accountSuffix(accountID), username); err != nil {
			return GroupInviteRedemption{}, err
		}
	}
	linkID := uuid.New()
	if _, err := tx.Exec(ctx, `
		INSERT INTO group_account_links(id, group_id, group_account_id, user_id, bound_by_user_id)
		VALUES($1, $2, $3, $4, $4)`, linkID, invite.GroupID, accountID, userID); err != nil {
		if isUniqueViolation(err) {
			return GroupInviteRedemption{}, ErrAlreadyGroupMember
		}
		return GroupInviteRedemption{}, err
	}
	redemption := GroupInviteRedemption{ID: uuid.New(), InviteID: invite.ID, GroupID: invite.GroupID, UserID: userID, GroupAccountID: accountID, IdempotencyKey: idempotencyKey}
	if err := tx.QueryRow(ctx, `
		INSERT INTO group_invite_redemptions(id, invite_id, user_id, group_account_id, idempotency_key)
		VALUES($1, $2, $3, $4, $5)
		RETURNING redeemed_at`, redemption.ID, redemption.InviteID, redemption.UserID, redemption.GroupAccountID, redemption.IdempotencyKey,
	).Scan(&redemption.RedeemedAt); err != nil {
		return GroupInviteRedemption{}, err
	}
	if _, err := tx.Exec(ctx, `UPDATE group_invites SET use_count = use_count + 1 WHERE id = $1`, invite.ID); err != nil {
		return GroupInviteRedemption{}, err
	}
	if err := insertAuditEvent(ctx, tx, userID, &invite.GroupID, "group_invite.redeem", "group_invite", invite.ID); err != nil {
		return GroupInviteRedemption{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return GroupInviteRedemption{}, err
	}
	return redemption, nil
}

func isUniqueViolation(err error) bool {
	var databaseError *pgconn.PgError
	return errors.As(err, &databaseError) && databaseError.Code == "23505"
}
