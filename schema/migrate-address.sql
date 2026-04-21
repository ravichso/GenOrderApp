-- Run this on an existing database to add the address column.
-- wrangler d1 execute generic_order --remote --file=schema/migrate-address.sql

ALTER TABLE customers ADD COLUMN address TEXT;
ALTER TABLE orders ADD COLUMN delivery_address TEXT;
