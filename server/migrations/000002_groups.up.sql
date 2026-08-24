ALTER TABLE users ADD COLUMN disabled_at timestamptz;

CREATE TABLE workspaces (
    id uuid PRIMARY KEY,
    kind text NOT NULL CHECK (kind IN ('personal', 'group')),
    owner_user_id uuid REFERENCES users(id) ON DELETE CASCADE,
    group_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((kind = 'personal' AND owner_user_id IS NOT NULL AND group_id IS NULL)
        OR (kind = 'group' AND owner_user_id IS NULL AND group_id IS NOT NULL))
);
CREATE UNIQUE INDEX idx_workspaces_personal_owner ON workspaces(owner_user_id)
    WHERE kind = 'personal';
CREATE UNIQUE INDEX idx_workspaces_group ON workspaces(group_id)
    WHERE kind = 'group';

CREATE TABLE groups (
    id uuid PRIMARY KEY,
    workspace_id uuid NOT NULL UNIQUE REFERENCES workspaces(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    name varchar(100) NOT NULL,
    archived boolean NOT NULL DEFAULT false,
    collaboration_enabled_at timestamptz,
    created_by_user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE OR REPLACE FUNCTION prevent_collaboration_disable()
RETURNS trigger AS $$
BEGIN
    IF OLD.collaboration_enabled_at IS NOT NULL
       AND (NEW.collaboration_enabled_at IS NULL
            OR NEW.collaboration_enabled_at <> OLD.collaboration_enabled_at) THEN
        RAISE EXCEPTION 'collaboration_enabled_at is immutable once set';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_groups_collaboration_immutable
BEFORE UPDATE OF collaboration_enabled_at ON groups
FOR EACH ROW EXECUTE FUNCTION prevent_collaboration_disable();
ALTER TABLE workspaces
    ADD CONSTRAINT fk_workspaces_group
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE server_roles (
    user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role = 'L3'),
    active boolean NOT NULL DEFAULT true,
    assigned_by_user_id uuid REFERENCES users(id) ON DELETE RESTRICT,
    assigned_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_server_roles_active ON server_roles(active, role);

CREATE TABLE group_accounts (
    id uuid PRIMARY KEY,
    group_id uuid NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
    account_code varchar(64) NOT NULL,
    display_name varchar(100) NOT NULL,
    role text NOT NULL DEFAULT 'L1' CHECK (role IN ('L1', 'L2')),
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (group_id, id),
    UNIQUE (group_id, account_code)
);
CREATE INDEX idx_group_accounts_group_active ON group_accounts(group_id, active, account_code);

CREATE TABLE group_account_links (
    id uuid PRIMARY KEY,
    group_id uuid NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
    group_account_id uuid NOT NULL REFERENCES group_accounts(id) ON DELETE RESTRICT,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    bound_at timestamptz NOT NULL DEFAULT now(),
    unbound_at timestamptz,
    bound_by_user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    unbound_by_user_id uuid REFERENCES users(id) ON DELETE RESTRICT,
    unbound_reason text,
    CHECK (unbound_at IS NULL OR unbound_at >= bound_at),
    CHECK ((unbound_at IS NULL) = (unbound_by_user_id IS NULL)),
    FOREIGN KEY (group_id, group_account_id)
        REFERENCES group_accounts(group_id, id)
        ON DELETE RESTRICT
);
CREATE UNIQUE INDEX idx_group_links_account_active
    ON group_account_links(group_account_id) WHERE unbound_at IS NULL;
CREATE UNIQUE INDEX idx_group_links_user_active
    ON group_account_links(group_id, user_id) WHERE unbound_at IS NULL;
CREATE INDEX idx_group_links_user ON group_account_links(user_id, group_id, unbound_at);

CREATE TABLE audit_events (
    id uuid PRIMARY KEY,
    actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    group_id uuid REFERENCES groups(id) ON DELETE SET NULL,
    action text NOT NULL,
    target_type text NOT NULL,
    target_id uuid,
    outcome text NOT NULL CHECK (outcome IN ('success', 'failure')),
    request_id text,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_events_group_created ON audit_events(group_id, created_at DESC);
CREATE INDEX idx_audit_events_actor_created ON audit_events(actor_user_id, created_at DESC);

INSERT INTO workspaces (id, kind, owner_user_id)
SELECT gen_random_uuid(), 'personal', users.id
FROM users
ON CONFLICT (owner_user_id) WHERE kind = 'personal' DO NOTHING;

INSERT INTO schema_metadata(key, value)
VALUES ('groups_model', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
