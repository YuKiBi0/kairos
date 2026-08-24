//go:build integration

package store

import (
	"context"
	"errors"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/invites"
	"github.com/google/uuid"
)

func TestInviteExpiryTargetBindingAndIdempotency(t *testing.T) {
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
	owner, err := database.CreateUser(ctx, "invite-owner-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	member, err := database.CreateUser(ctx, "invite-member-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	secondMember, err := database.CreateUser(ctx, "invite-member-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	concurrentOne, err := database.CreateUser(ctx, "invite-member-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	concurrentTwo, err := database.CreateUser(ctx, "invite-member-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	group, _, _, err := database.CreateGroup(ctx, owner.ID, "Invite integration group")
	if err != nil {
		t.Fatal(err)
	}
	target, err := database.CreateGroupAccount(ctx, owner.ID, group.ID, "target-001", "Target", "L1")
	if err != nil {
		t.Fatal(err)
	}
	defer cleanupGroupFixture(database, group.ID, owner.ID, member.ID, secondMember.ID, concurrentOne.ID, concurrentTwo.ID)

	secret := []byte("01234567890123456789012345678901")
	_, digest, err := testInviteCode(secret)
	if err != nil {
		t.Fatal(err)
	}
	targeted, err := database.CreateGroupInvite(ctx, owner.ID, group.ID, digest, &target.ID, nil, time.Now().UTC().Add(time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	redemption, err := database.RedeemGroupInvite(ctx, member.ID, digest, uuid.New())
	if err != nil {
		t.Fatal(err)
	}
	if redemption.GroupID != group.ID || redemption.GroupAccountID != target.ID || targeted.UseCount != 0 {
		t.Fatalf("targeted invite returned unexpected result: %#v", redemption)
	}
	secondKey := uuid.New()
	_, err = database.RedeemGroupInvite(ctx, secondMember.ID, digest, secondKey)
	if !errors.Is(err, ErrInviteExhausted) && !errors.Is(err, ErrInviteAccountBound) {
		t.Fatalf("expected targeted invite to be unavailable after redemption, got %v", err)
	}
	idempotencyKey := uuid.New()
	raw, digest, err := testInviteCode(secret)
	if err != nil {
		t.Fatal(err)
	}
	_ = raw
	ordinary, err := database.CreateGroupInvite(ctx, owner.ID, group.ID, digest, nil, nil, time.Now().UTC().Add(time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	first, err := database.RedeemGroupInvite(ctx, secondMember.ID, digest, idempotencyKey)
	if err != nil {
		t.Fatal(err)
	}
	retry, err := database.RedeemGroupInvite(ctx, secondMember.ID, digest, idempotencyKey)
	if err != nil {
		t.Fatal(err)
	}
	if first.ID != retry.ID || first.GroupID != group.ID || retry.GroupID != group.ID || ordinary.UseCount != 0 {
		t.Fatalf("idempotent redemption changed result: first=%#v retry=%#v", first, retry)
	}

	_, digest, err = testInviteCode(secret)
	if err != nil {
		t.Fatal(err)
	}
	limited := 1
	limitedInvite, err := database.CreateGroupInvite(ctx, owner.ID, group.ID, digest, nil, &limited, time.Now().UTC().Add(time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	users := []uuid.UUID{concurrentOne.ID, concurrentTwo.ID}
	results := make(chan error, len(users))
	var wait sync.WaitGroup
	for _, userID := range users {
		wait.Add(1)
		go func(id uuid.UUID) {
			defer wait.Done()
			_, err := database.RedeemGroupInvite(context.Background(), id, digest, uuid.New())
			results <- err
		}(userID)
	}
	wait.Wait()
	close(results)
	successes := 0
	for result := range results {
		if result == nil {
			successes++
		} else if !errors.Is(result, ErrInviteExhausted) && !errors.Is(result, ErrAlreadyGroupMember) {
			t.Fatalf("unexpected concurrent redemption error: %v", result)
		}
	}
	if successes != 1 || limitedInvite.UseCount != 0 {
		t.Fatalf("limited invite was redeemed %d times", successes)
	}
	if _, err := database.CreateGroupInvite(ctx, owner.ID, group.ID, []byte("expired"), nil, nil, time.Now().UTC().Add(31*24*time.Hour)); !errors.Is(err, ErrInviteExpired) {
		t.Fatalf("expected 30 day boundary rejection, got %v", err)
	}
}

func testInviteCode(secret []byte) (string, []byte, error) {
	return invites.Generate(secret)
}
