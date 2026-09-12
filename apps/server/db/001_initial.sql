CREATE TABLE gm_players (
  id text PRIMARY KEY,
  auth_user_id uuid NOT NULL UNIQUE,
  nickname varchar(64) NOT NULL,
  is_guest boolean NOT NULL,
  merged_into text REFERENCES gm_players(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE gm_rooms (
  id text PRIMARY KEY,
  code varchar(6) NOT NULL UNIQUE,
  revision integer NOT NULL CHECK (revision >= 0),
  status text NOT NULL CHECK (status IN ('waiting','playing','paused','finished','closed')),
  host_id text NOT NULL REFERENCES gm_players(id),
  guest_id text REFERENCES gm_players(id),
  payload text NOT NULL,
  updated_at timestamptz NOT NULL,
  deadline_at timestamptz,
  CHECK (host_id <> guest_id)
);
CREATE INDEX gm_rooms_host_active ON gm_rooms(host_id, status);
CREATE INDEX gm_rooms_guest_active ON gm_rooms(guest_id, status);
CREATE INDEX gm_rooms_maintenance ON gm_rooms(status, updated_at);

CREATE TABLE gm_active_seats (
  player_id text PRIMARY KEY REFERENCES gm_players(id),
  room_id text NOT NULL REFERENCES gm_rooms(id) ON DELETE CASCADE
);

CREATE TABLE gm_presence (
  room_id text NOT NULL REFERENCES gm_rooms(id) ON DELETE CASCADE,
  player_id text NOT NULL REFERENCES gm_players(id),
  connection_id text NOT NULL,
  expires_at timestamptz NOT NULL,
  PRIMARY KEY(room_id, player_id, connection_id)
);
CREATE INDEX gm_presence_expiration ON gm_presence(room_id, expires_at);

CREATE TABLE gm_commands (
  player_id text NOT NULL REFERENCES gm_players(id),
  command_id text NOT NULL,
  request_hash text NOT NULL,
  room_id text REFERENCES gm_rooms(id),
  response text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(player_id, command_id)
);

CREATE TABLE gm_records (
  id text PRIMARY KEY,
  source text NOT NULL CHECK(source IN ('local','online')),
  payload text NOT NULL,
  payload_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE gm_record_owners (
  record_id text NOT NULL REFERENCES gm_records(id) ON DELETE CASCADE,
  player_id text NOT NULL REFERENCES gm_players(id),
  changed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(record_id, player_id)
);
CREATE INDEX gm_record_sync ON gm_record_owners(player_id, changed_at, record_id);

CREATE TABLE gm_outbox (
  id bigserial PRIMARY KEY,
  room_id text NOT NULL REFERENCES gm_rooms(id) ON DELETE CASCADE,
  revision integer NOT NULL,
  payload text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  delivered_at timestamptz,
  UNIQUE(room_id, revision)
);
CREATE INDEX gm_outbox_pending ON gm_outbox(id) WHERE delivered_at IS NULL;

CREATE TABLE gm_rate_limits (
  key_hash text NOT NULL,
  window_start bigint NOT NULL,
  hits integer NOT NULL,
  PRIMARY KEY(key_hash, window_start)
);
