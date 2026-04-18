-- Run this on an existing database to add self-service sign-up support.
-- wrangler d1 execute generic_order --remote --file=schema/migrate-signup.sql

CREATE TABLE IF NOT EXISTS pending_signups (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  phone        TEXT    NOT NULL,
  name         TEXT,
  code         TEXT    NOT NULL,
  attempts     INTEGER NOT NULL DEFAULT 0,
  expires_at   TEXT    NOT NULL,
  created_at   TEXT    DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_pending_phone ON pending_signups(phone);

INSERT OR IGNORE INTO settings (key, value) VALUES ('signup_enabled',     '1');
INSERT OR IGNORE INTO settings (key, value) VALUES ('sms_provider',       '');
INSERT OR IGNORE INTO settings (key, value) VALUES ('twilio_account_sid', '');
INSERT OR IGNORE INTO settings (key, value) VALUES ('twilio_auth_token',  '');
INSERT OR IGNORE INTO settings (key, value) VALUES ('twilio_from_number', '');
INSERT OR IGNORE INTO settings (key, value) VALUES ('twilio_use_whatsapp','0');
INSERT OR IGNORE INTO settings (key, value) VALUES ('msg91_auth_key',     '');
INSERT OR IGNORE INTO settings (key, value) VALUES ('msg91_sender_id',    '');
INSERT OR IGNORE INTO settings (key, value) VALUES ('msg91_template_id',  '');
