DROP TABLE IF EXISTS oauth_links;
DROP TABLE IF EXISTS refresh_tokens;
DROP TRIGGER IF EXISTS trg_max_children_per_parent ON child_profiles;
DROP FUNCTION IF EXISTS enforce_max_children_per_parent();
DROP TABLE IF EXISTS child_profiles;
DROP TABLE IF EXISTS users;
DROP TYPE IF EXISTS user_role;
