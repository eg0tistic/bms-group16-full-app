-- Supabase schema for BMS App (Group 16)
-- Run these in Supabase SQL Editor to create the remote tables.
-- Enable Row Level Security (RLS) after creation and add appropriate policies.

CREATE TABLE IF NOT EXISTS customers (
  id           BIGINT PRIMARY KEY,
  name         TEXT NOT NULL,
  phone        TEXT,
  address      TEXT,
  balance      NUMERIC DEFAULT 0,
  credit_limit NUMERIC NOT NULL DEFAULT 0,
  is_active    INTEGER DEFAULT 1,
  created_at   TEXT,
  updated_at   TEXT
);

CREATE TABLE IF NOT EXISTS products (
  id          BIGINT PRIMARY KEY,
  name        TEXT NOT NULL,
  category    TEXT,
  price       NUMERIC NOT NULL,
  unit        TEXT,
  is_active   INTEGER DEFAULT 1,
  created_at  TEXT,
  updated_at  TEXT
);

CREATE TABLE IF NOT EXISTS invoices (
  id             BIGINT PRIMARY KEY,
  invoice_number TEXT UNIQUE NOT NULL,
  customer_id    BIGINT NOT NULL REFERENCES customers(id),
  created_by     BIGINT NOT NULL,
  total_amount   NUMERIC DEFAULT 0,
  tax_amount     NUMERIC DEFAULT 0,
  tax_rate       NUMERIC NOT NULL DEFAULT 0,
  currency       TEXT NOT NULL DEFAULT 'SDG',
  due_date       TEXT,
  notes          TEXT,
  status         TEXT DEFAULT 'Draft',
  created_at     TEXT,
  updated_at     TEXT
);

-- If the tables were created before schema v3, apply instead:
-- ALTER TABLE customers ADD COLUMN credit_limit NUMERIC NOT NULL DEFAULT 0;
-- ALTER TABLE invoices  ADD COLUMN currency TEXT NOT NULL DEFAULT 'SDG';
-- ALTER TABLE invoices  ADD COLUMN due_date TEXT;

CREATE TABLE IF NOT EXISTS invoice_items (
  id          BIGINT PRIMARY KEY,
  invoice_id  BIGINT NOT NULL REFERENCES invoices(id),
  product_id  BIGINT,
  description TEXT NOT NULL,
  quantity    NUMERIC NOT NULL,
  unit_price  NUMERIC NOT NULL,
  subtotal    NUMERIC NOT NULL,
  created_at  TEXT
);

CREATE TABLE IF NOT EXISTS payments (
  id           BIGINT PRIMARY KEY,
  invoice_id   BIGINT NOT NULL REFERENCES invoices(id),
  amount_paid  NUMERIC NOT NULL,
  payment_date TEXT NOT NULL,
  method       TEXT DEFAULT 'Cash',
  notes        TEXT,
  created_at   TEXT,
  reversed_at  TEXT,
  reversed_by  BIGINT,
  reversal_reason TEXT
);

CREATE TABLE IF NOT EXISTS utility_payments (
  id             BIGINT PRIMARY KEY,
  utility_type   TEXT NOT NULL,
  provider       TEXT NOT NULL,
  account_number TEXT NOT NULL,
  payer_name     TEXT,
  payer_phone    TEXT,
  bill_amount    NUMERIC NOT NULL,
  service_fee    NUMERIC NOT NULL DEFAULT 0,
  payment_method TEXT NOT NULL,
  reference      TEXT,
  notes          TEXT,
  created_by     BIGINT NOT NULL,
  created_at     TEXT
);
