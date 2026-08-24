CREATE INDEX idx_users_created_at ON users(created_at DESC, id);

INSERT INTO schema_metadata(key, value)
VALUES ('admin_model', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
