package httpapi

import (
	"context"
	"testing"
)

func TestHasScopeRequiresExactScope(t *testing.T) {
	ctx := context.WithValue(context.Background(), scopesKey, []string{"*"})
	if hasScope(ctx, "central:tasks:create") {
		t.Fatal("wildcard scope must not grant central delegation")
	}
	ctx = context.WithValue(context.Background(), scopesKey, []string{"central:tasks:create"})
	if !hasScope(ctx, "central:tasks:create") {
		t.Fatal("exact central delegation scope should be accepted")
	}
}
