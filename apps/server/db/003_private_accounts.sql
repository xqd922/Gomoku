CREATE TABLE gm_private_accounts (
  player_id text PRIMARY KEY REFERENCES gm_players(id),
  email text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);
