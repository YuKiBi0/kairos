ALTER TABLE projects ADD COLUMN workspace_id uuid REFERENCES workspaces(id) ON DELETE RESTRICT;
ALTER TABLE checklist_groups ADD COLUMN workspace_id uuid REFERENCES workspaces(id) ON DELETE RESTRICT;
ALTER TABLE tags ADD COLUMN workspace_id uuid REFERENCES workspaces(id) ON DELETE RESTRICT;
ALTER TABLE tasks ADD COLUMN workspace_id uuid REFERENCES workspaces(id) ON DELETE RESTRICT;
ALTER TABLE blockers ADD COLUMN workspace_id uuid REFERENCES workspaces(id) ON DELETE RESTRICT;
ALTER TABLE task_tags ADD COLUMN workspace_id uuid REFERENCES workspaces(id) ON DELETE RESTRICT;
ALTER TABLE sync_operations ADD COLUMN workspace_id uuid REFERENCES workspaces(id) ON DELETE RESTRICT;
ALTER TABLE sync_changes ADD COLUMN workspace_id uuid REFERENCES workspaces(id) ON DELETE RESTRICT;

CREATE OR REPLACE FUNCTION fill_personal_workspace_id()
RETURNS trigger AS $$
BEGIN
    IF NEW.workspace_id IS NULL THEN
        SELECT workspace.id INTO NEW.workspace_id
        FROM workspaces workspace
        WHERE workspace.kind = 'personal' AND workspace.owner_user_id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_projects_workspace BEFORE INSERT ON projects
FOR EACH ROW EXECUTE FUNCTION fill_personal_workspace_id();
CREATE TRIGGER trg_checklist_groups_workspace BEFORE INSERT ON checklist_groups
FOR EACH ROW EXECUTE FUNCTION fill_personal_workspace_id();
CREATE TRIGGER trg_tags_workspace BEFORE INSERT ON tags
FOR EACH ROW EXECUTE FUNCTION fill_personal_workspace_id();
CREATE TRIGGER trg_tasks_workspace BEFORE INSERT ON tasks
FOR EACH ROW EXECUTE FUNCTION fill_personal_workspace_id();
CREATE TRIGGER trg_blockers_workspace BEFORE INSERT ON blockers
FOR EACH ROW EXECUTE FUNCTION fill_personal_workspace_id();
CREATE TRIGGER trg_task_tags_workspace BEFORE INSERT ON task_tags
FOR EACH ROW EXECUTE FUNCTION fill_personal_workspace_id();
CREATE TRIGGER trg_sync_operations_workspace BEFORE INSERT ON sync_operations
FOR EACH ROW EXECUTE FUNCTION fill_personal_workspace_id();
CREATE TRIGGER trg_sync_changes_workspace BEFORE INSERT ON sync_changes
FOR EACH ROW EXECUTE FUNCTION fill_personal_workspace_id();

UPDATE projects entity
SET workspace_id = workspace.id
FROM workspaces workspace
WHERE workspace.kind = 'personal' AND workspace.owner_user_id = entity.user_id;
UPDATE checklist_groups entity
SET workspace_id = workspace.id
FROM workspaces workspace
WHERE workspace.kind = 'personal' AND workspace.owner_user_id = entity.user_id;
UPDATE tags entity
SET workspace_id = workspace.id
FROM workspaces workspace
WHERE workspace.kind = 'personal' AND workspace.owner_user_id = entity.user_id;
UPDATE tasks entity
SET workspace_id = workspace.id
FROM workspaces workspace
WHERE workspace.kind = 'personal' AND workspace.owner_user_id = entity.user_id;
UPDATE blockers entity
SET workspace_id = workspace.id
FROM workspaces workspace
WHERE workspace.kind = 'personal' AND workspace.owner_user_id = entity.user_id;
UPDATE task_tags relation
SET workspace_id = task.workspace_id
FROM tasks task
WHERE relation.user_id = task.user_id AND relation.task_id = task.id;
UPDATE sync_operations entity
SET workspace_id = workspace.id
FROM workspaces workspace
WHERE workspace.kind = 'personal' AND workspace.owner_user_id = entity.user_id;
UPDATE sync_changes entity
SET workspace_id = workspace.id
FROM workspaces workspace
WHERE workspace.kind = 'personal' AND workspace.owner_user_id = entity.user_id;

ALTER TABLE task_tags ALTER COLUMN workspace_id SET NOT NULL;
ALTER TABLE task_tags DROP CONSTRAINT task_tags_pkey;
ALTER TABLE task_tags ADD PRIMARY KEY (workspace_id, task_id, tag_id);
ALTER TABLE sync_operations ALTER COLUMN workspace_id SET NOT NULL;
ALTER TABLE sync_operations DROP CONSTRAINT sync_operations_pkey;
ALTER TABLE sync_operations ADD PRIMARY KEY (workspace_id, operation_id);

CREATE INDEX idx_projects_workspace ON projects(workspace_id, archived, name);
CREATE INDEX idx_checklist_groups_workspace ON checklist_groups(workspace_id, archived, name);
CREATE UNIQUE INDEX idx_tags_workspace_name ON tags(workspace_id, name);
CREATE INDEX idx_tasks_workspace_updated ON tasks(workspace_id, updated_at);
CREATE INDEX idx_tasks_workspace_parent_sort ON tasks(workspace_id, parent_id, sort_order);
CREATE INDEX idx_blockers_workspace_task ON blockers(workspace_id, task_id, deleted_at);
CREATE INDEX idx_task_tags_workspace ON task_tags(workspace_id, task_id, tag_id);
CREATE INDEX idx_sync_operations_workspace ON sync_operations(workspace_id, operation_id);
CREATE INDEX idx_sync_changes_workspace_cursor ON sync_changes(workspace_id, cursor);

INSERT INTO schema_metadata(key, value)
VALUES ('workspace_sync_model', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
