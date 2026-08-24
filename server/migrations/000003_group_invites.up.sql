CREATE TABLE group_invites (
    id uuid PRIMARY KEY,
    group_id uuid NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
    code_digest bytea NOT NULL UNIQUE,
    target_group_account_id uuid,
    max_uses integer,
    use_count integer NOT NULL DEFAULT 0,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    created_by_user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (max_uses IS NULL OR max_uses > 0),
    CHECK (use_count >= 0),
    CHECK (max_uses IS NULL OR use_count <= max_uses),
    CHECK (expires_at > created_at AND expires_at <= created_at + interval '30 days'),
    CHECK (target_group_account_id IS NULL OR max_uses = 1),
    FOREIGN KEY (group_id, target_group_account_id)
        REFERENCES group_accounts(group_id, id)
        ON DELETE RESTRICT
);
CREATE INDEX idx_group_invites_group_created ON group_invites(group_id, created_at DESC);
CREATE INDEX idx_group_invites_active ON group_invites(group_id, expires_at)
    WHERE revoked_at IS NULL;

CREATE TABLE group_invite_redemptions (
    id uuid PRIMARY KEY,
    invite_id uuid NOT NULL REFERENCES group_invites(id) ON DELETE RESTRICT,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    group_account_id uuid NOT NULL REFERENCES group_accounts(id) ON DELETE RESTRICT,
    idempotency_key uuid NOT NULL,
    redeemed_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (invite_id, user_id, idempotency_key)
);
CREATE INDEX idx_group_invite_redemptions_user ON group_invite_redemptions(user_id, redeemed_at DESC);

INSERT INTO schema_metadata(key, value)
VALUES ('group_invites_model', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
