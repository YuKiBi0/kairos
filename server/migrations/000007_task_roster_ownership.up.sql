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

CREATE OR REPLACE FUNCTION validate_task_group_account()
RETURNS trigger AS $$
DECLARE
    workspace_kind text;
    workspace_group_id uuid;
    account_group_id uuid;
BEGIN
    SELECT kind, group_id INTO workspace_kind, workspace_group_id
    FROM workspaces WHERE id = NEW.workspace_id;
    IF NEW.group_account_id IS NULL THEN
        RETURN NEW;
    END IF;
    SELECT group_id INTO account_group_id
    FROM group_accounts WHERE id = NEW.group_account_id;
    IF workspace_kind <> 'group' OR workspace_group_id IS DISTINCT FROM account_group_id THEN
        RAISE EXCEPTION 'task group account does not belong to its workspace';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tasks_group_account_scope
BEFORE INSERT OR UPDATE OF workspace_id, group_account_id ON tasks
FOR EACH ROW EXECUTE FUNCTION validate_task_group_account();

INSERT INTO schema_metadata(key, value)
VALUES ('task_roster_ownership_model', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
