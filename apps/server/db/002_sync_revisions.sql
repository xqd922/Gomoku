-- Revisions allocated under one per-player row lock cannot commit out of order.
CREATE TABLE gm_sync_clocks (
  player_id text PRIMARY KEY REFERENCES gm_players(id),
  revision bigint NOT NULL CHECK (revision > 0)
);
ALTER TABLE gm_record_owners ADD COLUMN sync_revision bigint NOT NULL DEFAULT 0;
WITH numbered AS (
  SELECT record_id, player_id,
    row_number() OVER (PARTITION BY player_id ORDER BY changed_at, record_id) AS revision
  FROM gm_record_owners
)
UPDATE gm_record_owners AS owner SET sync_revision = numbered.revision
FROM numbered
WHERE owner.record_id = numbered.record_id AND owner.player_id = numbered.player_id;
INSERT INTO gm_sync_clocks(player_id, revision)
SELECT player_id, max(sync_revision) FROM gm_record_owners GROUP BY player_id;
CREATE UNIQUE INDEX gm_record_sync_revision ON gm_record_owners(player_id, sync_revision);

CREATE FUNCTION gm_next_sync_revision() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO gm_sync_clocks(player_id, revision) VALUES (NEW.player_id, 1)
  ON CONFLICT (player_id) DO UPDATE SET revision = gm_sync_clocks.revision + 1
  RETURNING revision INTO NEW.sync_revision;
  RETURN NEW;
END;
$$;
CREATE TRIGGER gm_assign_sync_revision BEFORE INSERT ON gm_record_owners
FOR EACH ROW EXECUTE FUNCTION gm_next_sync_revision();
