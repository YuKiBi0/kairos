DROP INDEX IF EXISTS idx_tasks_workspace_shared_updated;
ALTER TABLE tasks DROP COLUMN IF EXISTS shared_at;
DELETE FROM schema_metadata WHERE key = 'task_collaboration_model';
