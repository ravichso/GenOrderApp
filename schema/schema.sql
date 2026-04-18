-- =====================================================================
-- Generic Product Ordering App - Cloudflare D1 (SQLite) Schema
-- =====================================================================
-- Run once via: wrangler d1 execute <DB_NAME> --file=schema/schema.sql
-- For remote:   wrangler d1 execute <DB_NAME> --remote --file=schema/schema.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- Categories: admin-defined buckets that group products
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  name         TEXT    NOT NULL UNIQUE,
  emoji        TEXT,
  sort_order   INTEGER DEFAULT 100,
  created_at   TEXT    DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- Products: each product has image + unit + price + stock flag
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id   INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  name          TEXT    NOT NULL,
  description   TEXT,
  unit          TEXT    NOT NULL DEFAULT 'each',
  price         REAL    NOT NULL DEFAULT 0,
  image_key     TEXT,
  image_url     TEXT,
  in_stock      INTEGER NOT NULL DEFAULT 1,
  sort_order    INTEGER DEFAULT 100,
  created_at    TEXT    DEFAULT (datetime('now')),
  updated_at    TEXT    DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_stock    ON products(in_stock);

-- ---------------------------------------------------------------------
-- Customers: whitelisted phone numbers + hashed PIN
-- PIN is stored as SHA-256 hex hash + random salt (never plaintext)
-- reset_token lets admin issue a one-time code so the customer picks
-- their own new PIN; admin never sees the PIN.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  phone             TEXT    NOT NULL UNIQUE,
  name              TEXT,
  pin_hash          TEXT,
  pin_salt          TEXT,
  reset_token       TEXT,
  reset_expires_at  TEXT,
  notes             TEXT,
  created_at        TEXT    DEFAULT (datetime('now')),
  updated_at        TEXT    DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);

-- ---------------------------------------------------------------------
-- Orders: one row per submitted order
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  order_code       TEXT    NOT NULL UNIQUE,
  customer_id      INTEGER REFERENCES customers(id) ON DELETE SET NULL,
  customer_name    TEXT,
  customer_phone   TEXT,
  total_amount     REAL    NOT NULL DEFAULT 0,
  payment_status   TEXT    NOT NULL DEFAULT 'pending',
  payment_method   TEXT,
  payment_ref      TEXT,
  order_status     TEXT    NOT NULL DEFAULT 'new',
  notified         INTEGER NOT NULL DEFAULT 0,
  notes            TEXT,
  created_at       TEXT    DEFAULT (datetime('now')),
  updated_at       TEXT    DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status   ON orders(order_status);
CREATE INDEX IF NOT EXISTS idx_orders_created  ON orders(created_at);

-- ---------------------------------------------------------------------
-- Order items: line items per order
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_items (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id     INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id   INTEGER REFERENCES products(id) ON DELETE SET NULL,
  product_name TEXT    NOT NULL,
  unit         TEXT,
  unit_price   REAL    NOT NULL DEFAULT 0,
  quantity     REAL    NOT NULL DEFAULT 0,
  line_total   REAL    NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_items_order ON order_items(order_id);

-- ---------------------------------------------------------------------
-- Settings: single-row key/value store driven from admin UI
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS settings (
  key   TEXT PRIMARY KEY,
  value TEXT
);

-- Default settings (upserted on first run)
INSERT OR IGNORE INTO settings (key, value) VALUES
  ('store_name',         'My Store'),
  ('store_tagline',      'Fresh delivered to your door'),
  ('upi_id',             ''),
  ('upi_payee_name',     ''),
  ('admin_phone',        ''),
  ('admin_pin_hash',     ''),
  ('admin_pin_salt',     ''),
  ('currency_symbol',    '₹'),
  ('whatsapp_template',  'Hi {name}, your order is confirmed. Total: {total}'),
  ('ordering_open',      '1'),
  ('signup_enabled',     '1'),
  ('sms_provider',       ''),              -- 'twilio' or 'msg91'
  ('twilio_account_sid', ''),
  ('twilio_auth_token',  ''),
  ('twilio_from_number', ''),              -- e.g. +14155238886 or whatsapp:+14155238886
  ('twilio_use_whatsapp','0'),             -- '1' to send via WhatsApp instead of SMS
  ('msg91_auth_key',     ''),
  ('msg91_sender_id',    ''),
  ('msg91_template_id',  '');

-- ---------------------------------------------------------------------
-- Pending signups: holds verification codes for self-service sign-up
-- Rows are temporary; deleted after successful verification or expiry.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pending_signups (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  phone        TEXT    NOT NULL,
  name         TEXT,
  code         TEXT    NOT NULL,             -- 6-char verification code
  attempts     INTEGER NOT NULL DEFAULT 0,   -- wrong-code counter (max 5)
  expires_at   TEXT    NOT NULL,
  created_at   TEXT    DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_pending_phone ON pending_signups(phone);

-- ---------------------------------------------------------------------
-- Admin audit log (optional but useful)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_log (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  action     TEXT,
  target     TEXT,
  detail     TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);
