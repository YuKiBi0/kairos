ALTER TABLE tasks
    ADD COLUMN group_account_id uuid REFERENCES group_accounts(id) ON DELETE RESTRICT,
    ADD COLUMN created_by_user_id uuid REFERENCES users(id) ON DELETE RESTRICT,
    ADD COLUMN last_operated_by_user_id uuid REFERENCES users(id) ON DELETE RESTRICT;

UPDATE tasks task_row
SET created_by_user_id = task_row.user_id,
    last_operated_by_user_id = task_row.user_id,
    group_account_id = (
        SELECT member_link.group_account_id
        FROM workspaces workspace
        JOIN groups group_row ON group_row.id = workspace.group_id
        JOIN group_account_links member_link ON member_link.group_id = group_row.id
        JOIN group_accounts account ON account.id = member_link.group_account_id
        WHERE workspace.id = task_row.workspace_id
          AND member_link.user_id = task_row.user_id
          AND member_link.unbound_at IS NULL
          AND account.active
        ORDER BY member_link.bound_at DESC
        LIMIT 1
    );

ALTER TABLE tasks
    ALTER COLUMN created_by_user_id SET NOT NULL,
    ALTER COLUMN last_operated_by_user_id SET NOT NULL;

CREATE INDEX idx_tasks_workspace_group_account
    ON tasks(workspace_id, group_account_id, updated_at);

INSERT INTO schema_metadata(key, value)
VALUES ('task_roster_ownership_model', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
