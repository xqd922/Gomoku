ALTER TABLE gm_private_accounts
  ADD COLUMN login_name text UNIQUE CHECK (login_name IN ('1', '2'));
