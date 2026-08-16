CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id uuid PRIMARY KEY,
    username text NOT NULL UNIQUE,
    password_hash text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE devices (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name text NOT NULL,
    platform text NOT NULL,
    last_seen_at timestamptz,
    revoked_at timestamptz
);
CREATE INDEX idx_devices_user ON devices(user_id);

CREATE TABLE sessions (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id uuid NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    refresh_token_hash bytea NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    rotated_at timestamptz,
    revoked_at timestamptz
);
CREATE INDEX idx_sessions_user_device ON sessions(user_id, device_id);

CREATE TABLE projects (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name varchar(100) NOT NULL,
    archived boolean NOT NULL DEFAULT false,
    version bigint NOT NULL DEFAULT 1,
    field_versions jsonb NOT NULL DEFAULT '{}'::jsonb,
    updated_at timestamptz NOT NULL
);
CREATE INDEX idx_projects_user ON projects(user_id, archived, name);

CREATE TABLE checklist_groups (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name varchar(100) NOT NULL,
    archived boolean NOT NULL DEFAULT false,
    version bigint NOT NULL DEFAULT 1,
    field_versions jsonb NOT NULL DEFAULT '{}'::jsonb,
    updated_at timestamptz NOT NULL
);
CREATE INDEX idx_checklist_groups_user ON checklist_groups(user_id, archived, name);

CREATE TABLE tags (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name varchar(100) NOT NULL,
    color_token text,
    archived boolean NOT NULL DEFAULT false,
    version bigint NOT NULL DEFAULT 1,
    field_versions jsonb NOT NULL DEFAULT '{}'::jsonb,
    updated_at timestamptz NOT NULL,
    UNIQUE(user_id, name)
);

CREATE TABLE tasks (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_id uuid REFERENCES tasks(id),
    title varchar(200) NOT NULL,
    description text,
    quadrant smallint NOT NULL CHECK (quadrant BETWEEN 1 AND 4),
    status smallint NOT NULL CHECK (status BETWEEN 0 AND 3),
    due_at timestamptz,
    depth smallint NOT NULL CHECK (depth BETWEEN 1 AND 5),
    sort_order integer NOT NULL,
    project_id uuid REFERENCES projects(id),
    checklist_group_id uuid REFERENCES checklist_groups(id),
    version bigint NOT NULL DEFAULT 1,
    field_versions jsonb NOT NULL DEFAULT '{}'::jsonb,
    deleted_at timestamptz,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    completed_at timestamptz,
    updated_by_device_id uuid NOT NULL REFERENCES devices(id)
);
CREATE INDEX idx_tasks_user_parent_sort ON tasks(user_id, parent_id, sort_order);
CREATE INDEX idx_tasks_user_status_due ON tasks(user_id, status, due_at);
CREATE INDEX idx_tasks_user_quadrant_status ON tasks(user_id, quadrant, status);
CREATE INDEX idx_tasks_user_updated ON tasks(user_id, updated_at);
CREATE INDEX idx_tasks_user_deleted ON tasks(user_id, deleted_at);

CREATE TABLE blockers (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    body varchar(1000) NOT NULL,
    resolved boolean NOT NULL DEFAULT false,
    resolved_at timestamptz,
    version bigint NOT NULL DEFAULT 1,
    field_versions jsonb NOT NULL DEFAULT '{}'::jsonb,
    deleted_at timestamptz,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL
);
CREATE INDEX idx_blockers_user_task ON blockers(user_id, task_id, deleted_at);

CREATE TABLE task_tags (
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    tag_id uuid NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY(user_id, task_id, tag_id)
);

CREATE TABLE sync_operations (
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    operation_id uuid NOT NULL,
    result jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(user_id, operation_id)
);

CREATE TABLE sync_changes (
    cursor bigserial PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    entity_version bigint NOT NULL,
    deleted boolean NOT NULL DEFAULT false,
    entity jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_sync_changes_user_cursor ON sync_changes(user_id, cursor);

CREATE TABLE schema_metadata (
    key text PRIMARY KEY,
    value text NOT NULL
);
INSERT INTO schema_metadata(key, value) VALUES ('api_version', 'v1');
