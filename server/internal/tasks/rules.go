package tasks

import "errors"

const MaximumDepth = 5

var (
	ErrCycle      = errors.New("task parent would create a cycle")
	ErrDepthLimit = errors.New("task tree exceeds five levels")
	ErrMissing    = errors.New("task or parent does not exist")
)

type Node struct {
	ID       string
	ParentID string
	Depth    int
}

func ValidateMove(nodes []Node, taskID, targetParentID string) (int, int, error) {
	byID := make(map[string]Node, len(nodes))
	children := make(map[string][]Node, len(nodes))
	for _, node := range nodes {
		byID[node.ID] = node
		children[node.ParentID] = append(children[node.ParentID], node)
	}
	task, exists := byID[taskID]
	if !exists {
		return 0, 0, ErrMissing
	}
	targetDepth := 1
	if targetParentID != "" {
		parent, exists := byID[targetParentID]
		if !exists {
			return 0, 0, ErrMissing
		}
		targetDepth = parent.Depth + 1
	}
	descendants := descendantIDs(children, taskID)
	if targetParentID == taskID || descendants[targetParentID] {
		return 0, 0, ErrCycle
	}
	height := 1
	for id := range descendants {
		candidate := byID[id].Depth - task.Depth + 1
		if candidate > height {
			height = candidate
		}
	}
	if targetDepth+height-1 > MaximumDepth {
		return 0, 0, ErrDepthLimit
	}
	return targetDepth, targetDepth - task.Depth, nil
}

func DepthForNewTask(nodes []Node, targetParentID string) (int, error) {
	if targetParentID == "" {
		return 1, nil
	}
	for _, node := range nodes {
		if node.ID == targetParentID {
			if node.Depth >= MaximumDepth {
				return 0, ErrDepthLimit
			}
			return node.Depth + 1, nil
		}
	}
	return 0, ErrMissing
}

func descendantIDs(children map[string][]Node, rootID string) map[string]bool {
	result := make(map[string]bool)
	pending := []string{rootID}
	for len(pending) > 0 {
		parentID := pending[len(pending)-1]
		pending = pending[:len(pending)-1]
		for _, child := range children[parentID] {
			if !result[child.ID] {
				result[child.ID] = true
				pending = append(pending, child.ID)
			}
		}
	}
	return result
}
