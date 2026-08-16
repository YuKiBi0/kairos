package tasks

import (
	"errors"
	"testing"
)

func TestValidateMoveRejectsCycle(t *testing.T) {
	nodes := []Node{
		{ID: "root", Depth: 1},
		{ID: "child", ParentID: "root", Depth: 2},
	}
	if _, _, err := ValidateMove(nodes, "root", "child"); !errors.Is(err, ErrCycle) {
		t.Fatalf("expected cycle error, got %v", err)
	}
}

func TestValidateMoveRejectsDeepSubtree(t *testing.T) {
	nodes := []Node{
		{ID: "destination", Depth: 1},
		{ID: "d2", ParentID: "destination", Depth: 2},
		{ID: "d3", ParentID: "d2", Depth: 3},
		{ID: "source", Depth: 1},
		{ID: "s2", ParentID: "source", Depth: 2},
		{ID: "s3", ParentID: "s2", Depth: 3},
		{ID: "s4", ParentID: "s3", Depth: 4},
	}
	if _, _, err := ValidateMove(nodes, "source", "d3"); !errors.Is(err, ErrDepthLimit) {
		t.Fatalf("expected depth error, got %v", err)
	}
}

func TestValidateMoveReturnsDepthDelta(t *testing.T) {
	nodes := []Node{
		{ID: "root", Depth: 1},
		{ID: "child", ParentID: "root", Depth: 2},
		{ID: "grandchild", ParentID: "child", Depth: 3},
	}
	depth, delta, err := ValidateMove(nodes, "child", "")
	if err != nil {
		t.Fatal(err)
	}
	if depth != 1 || delta != -1 {
		t.Fatalf("unexpected move result: depth=%d delta=%d", depth, delta)
	}
}
