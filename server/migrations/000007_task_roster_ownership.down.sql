DROP INDEX IF EXISTS idx_tasks_workspace_group_account;
ALTER TABLE tasks
    DROP COLUMN IF EXISTS group_account_id,
    DROP COLUMN IF EXISTS created_by_user_id,
    DROP COLUMN IF EXISTS last_operated_by_user_id;
DELETE FROM schema_metadata WHERE key = 'task_roster_ownership_model';
