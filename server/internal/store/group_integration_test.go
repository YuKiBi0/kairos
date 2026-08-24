//go:build integration

package store

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestGroupMembershipRolesAndCollaboration(t *testing.T) {
	databaseURL := os.Getenv("KAIROS_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("KAIROS_TEST_DATABASE_URL is not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	database, err := Open(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer database.Close()

	owner, err := database.CreateUser(ctx, "group-owner-"+uuid.NewString(), "test-password-hash")
	if err != nil {
		t.Fatal(err)
	}
	member, err := database.CreateUser(ctx, "group-member-"+uuid.NewString(), "test-password-hash")
	if err != nil {
		t.Fatal(err)
	}
	group, ownerAccount, _, err := database.CreateGroup(ctx, owner.ID, "Integration group")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { cleanupGroupFixture(database, group.ID, owner.ID, member.ID) })

	ownerWorkspaces, err := database.ListAccessibleWorkspaces(ctx, owner.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(ownerWorkspaces) != 2 {
		t.Fatalf("owner should have personal and group workspaces, got %d", len(ownerWorkspaces))
	}
	memberWorkspaces, err := database.ListAccessibleWorkspaces(ctx, member.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(memberWorkspaces) != 1 || memberWorkspaces[0].Kind != "personal" {
		t.Fatalf("member should initially have only a personal workspace: %#v", memberWorkspaces)
	}

	memberAccount, err := database.CreateGroupAccount(ctx, owner.ID, group.ID, "member-001", "Member", "L1")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := database.BindGroupAccount(ctx, owner.ID, group.ID, memberAccount.ID, member.ID); err != nil {
		t.Fatal(err)
	}
	if role, err := database.GroupAccessRole(ctx, member.ID, group.ID); err != nil || role != "L1" {
		t.Fatalf("unexpected member role: role=%q err=%v", role, err)
	}
	if _, err := database.CreateGroupAccount(ctx, member.ID, group.ID, "forbidden", "Forbidden", "L1"); !errors.Is(err, ErrGroupForbidden) {
		t.Fatalf("expected L1 create account to be forbidden, got %v", err)
	}
	if err := database.SetGroupAccountRole(ctx, owner.ID, group.ID, memberAccount.ID, "L2"); err != nil {
		t.Fatal(err)
	}
	if err := database.SetGroupAccountRole(ctx, owner.ID, group.ID, ownerAccount.ID, "L1"); err != nil {
		t.Fatal(err)
	}
	if err := database.SetGroupAccountRole(ctx, member.ID, group.ID, memberAccount.ID, "L1"); !errors.Is(err, ErrLastGroupAdmin) {
		t.Fatalf("expected last group admin protection, got %v", err)
	}

	if err := database.SetCollaborationEnabled(ctx, member.ID, group.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := database.pool.Exec(ctx, `UPDATE groups SET collaboration_enabled_at = NULL WHERE id = $1`, group.ID); err == nil {
		t.Fatal("expected collaboration disable to be rejected by the database")
	}
	if err := database.UnbindGroupAccount(ctx, member.ID, group.ID, ownerAccount.ID, "owner left"); err != nil {
		t.Fatal(err)
	}
	ownerWorkspaces, err = database.ListAccessibleWorkspaces(ctx, owner.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(ownerWorkspaces) != 1 || ownerWorkspaces[0].Kind != "personal" {
		t.Fatalf("unbound owner should only retain personal workspace: %#v", ownerWorkspaces)
	}
}

func TestSuperAdminBootstrapAndLastAdminProtection(t *testing.T) {
	databaseURL := os.Getenv("KAIROS_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("KAIROS_TEST_DATABASE_URL is not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	database, err := Open(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer database.Close()
	var existingSuperAdmins int
	if err := database.pool.QueryRow(ctx, `SELECT count(*) FROM server_roles WHERE role = 'L3' AND active`).Scan(&existingSuperAdmins); err != nil {
		t.Fatal(err)
	}
	if existingSuperAdmins != 0 {
		t.Skip("super administrator fixture already exists")
	}
	first, err := database.CreateUser(ctx, "super-first-"+uuid.NewString(), "test-password-hash")
	if err != nil {
		t.Fatal(err)
	}
	second, err := database.CreateUser(ctx, "super-second-"+uuid.NewString(), "test-password-hash")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		cleanupUsers := []uuid.UUID{first.ID, second.ID}
		cleanupCtx, cleanupCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cleanupCancel()
		_, _ = database.pool.Exec(cleanupCtx, `DELETE FROM audit_events WHERE actor_user_id = ANY($1)`, cleanupUsers)
		_, _ = database.pool.Exec(cleanupCtx, `DELETE FROM server_roles WHERE user_id = ANY($1)`, cleanupUsers)
		_, _ = database.pool.Exec(cleanupCtx, `DELETE FROM workspaces WHERE owner_user_id = ANY($1)`, cleanupUsers)
		_, _ = database.pool.Exec(cleanupCtx, `DELETE FROM users WHERE id = ANY($1)`, cleanupUsers)
	})

	if err := database.BootstrapSuperAdmin(ctx, first.ID); err != nil {
		t.Fatal(err)
	}
	if err := database.BootstrapSuperAdmin(ctx, second.ID); !errors.Is(err, ErrSuperAdminExists) {
		t.Fatalf("expected repeated bootstrap to fail, got %v", err)
	}
	if err := database.SetServerSuperAdmin(ctx, first.ID, second.ID, true); err != nil {
		t.Fatal(err)
	}
	if err := database.SetServerSuperAdmin(ctx, first.ID, first.ID, false); err != nil {
		t.Fatal(err)
	}
	if err := database.SetServerSuperAdmin(ctx, second.ID, second.ID, false); !errors.Is(err, ErrLastSuperAdmin) {
		t.Fatalf("expected last super admin protection, got %v", err)
	}
	if err := database.SetUserDisabled(ctx, second.ID, first.ID, true); err != nil {
		t.Fatal(err)
	}
	if _, err := database.UserByID(ctx, first.ID); !IsNotFound(err) {
		t.Fatalf("disabled user should not be returned, got %v", err)
	}
	if err := database.SetUserDisabled(ctx, second.ID, second.ID, true); !errors.Is(err, ErrLastSuperAdmin) {
		t.Fatalf("expected last super admin disable protection, got %v", err)
	}
	if err := database.SetUserDisabled(ctx, second.ID, first.ID, false); err != nil {
		t.Fatal(err)
	}
}

func cleanupGroupFixture(database *Store, groupID uuid.UUID, userIDs ...uuid.UUID) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	tx, err := database.pool.Begin(ctx)
	if err != nil {
		return
	}
	defer func() { _ = tx.Rollback(ctx) }()
	_, _ = tx.Exec(ctx, `SET CONSTRAINTS ALL DEFERRED`)
	_, _ = tx.Exec(ctx, `DELETE FROM audit_events WHERE group_id = $1 OR actor_user_id = ANY($2)`, groupID, userIDs)
	_, _ = tx.Exec(ctx, `DELETE FROM group_account_links WHERE group_id = $1`, groupID)
	_, _ = tx.Exec(ctx, `DELETE FROM group_accounts WHERE group_id = $1`, groupID)
	_, _ = tx.Exec(ctx, `DELETE FROM groups WHERE id = $1`, groupID)
	_, _ = tx.Exec(ctx, `DELETE FROM workspaces WHERE group_id = $1 OR owner_user_id = ANY($2)`, groupID, userIDs)
	_, _ = tx.Exec(ctx, `DELETE FROM users WHERE id = ANY($1)`, userIDs)
	_ = tx.Commit(ctx)
}
