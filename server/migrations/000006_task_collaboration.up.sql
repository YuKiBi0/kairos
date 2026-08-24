ALTER TABLE tasks ADD COLUMN shared_at timestamptz;

CREATE INDEX idx_tasks_workspace_shared_updated
    ON tasks(workspace_id, shared_at, updated_at);

INSERT INTO schema_metadata(key, value)
VALUES ('task_collaboration_model', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
