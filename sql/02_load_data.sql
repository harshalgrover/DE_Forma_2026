
-- Google Pay UPI database
-- Phase 2: load the nine CSV files into the tables created in 01_schema.sql.
--
-- Run this command from the project root (the folder containing seed_data/):
-- psql -U postgres -d gpay_phase2_test -v ON_ERROR_STOP=1 -f sql/02_load_data.sql
--
-- The file uses psql's \copy command, so the CSV paths are read from this
-- computer. Load into an empty set of tables; running it again will hit
-- duplicate primary-key or unique values.

\set ON_ERROR_STOP on

BEGIN;

-- 1. CITIES
-- Load cities first because users and merchants refer to them.

\copy gpay.cities (city_id, city_name, state) FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true);


-- 2. USERS
-- Each user's city_id must already exist in cities.

\copy gpay.users (user_id, full_name, phone, email, city_id, kyc_status, is_blocked, created_at) FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true);


-- 3. BANK ACCOUNTS
-- Every bank account belongs to a user, so users must be loaded first.

\copy gpay.bank_accounts (account_id, user_id, bank_name, ifsc, account_last4, account_type, is_primary, linked_at) FROM 'seed_data/bank_accounts.csv' WITH (FORMAT csv, HEADER true);


-- 4. VPAS
-- Each VPA refers to both a user and that user's bank account.

\copy gpay.vpas (vpa, user_id, account_id, is_active, created_at) FROM 'seed_data/vpas.csv' WITH (FORMAT csv, HEADER true);


-- 5. MERCHANTS
-- Merchant records also refer to cities.

\copy gpay.merchants (merchant_id, merchant_name, mcc, merchant_vpa, city_id, is_verified, onboarded_on) FROM 'seed_data/merchants.csv' WITH (FORMAT csv, HEADER true);


-- 6. TRANSACTIONS
-- Payers refer to VPAs, and P2M transactions also refer to merchants.

\copy gpay.transactions (txn_id, upi_ref, txn_type, payer_vpa, payee_vpa, merchant_id, amount, note, initiated_at, completed_at, status, failure_code) FROM 'seed_data/transactions.csv' WITH (FORMAT csv, HEADER true);


-- 7. REWARDS
-- A reward refers to the user who received it and the related transaction.

\copy gpay.rewards (reward_id, user_id, txn_id, reward_type, amount, status, issued_at, expires_at, credited_at) FROM 'seed_data/rewards.csv' WITH (FORMAT csv, HEADER true);


-- 8. BILL PAYMENTS
-- Each bill payment belongs to a user.

\copy gpay.bill_payments (bill_id, user_id, biller_category, biller_name, consumer_number, amount, due_date, status, paid_at) FROM 'seed_data/bill_payments.csv' WITH (FORMAT csv, HEADER true);


-- 9. DISPUTES
-- Each dispute refers to the user who raised it and the transaction in question.

\copy gpay.disputes (dispute_id, txn_id, raised_by, reason, raised_at, status, resolved_at) FROM 'seed_data/disputes.csv' WITH (FORMAT csv, HEADER true);


-- Refresh PostgreSQL's statistics after the bulk load.
-- The query planner uses these statistics when it decides how to run a query.
-- This gives us a sensible starting point for the Phase 3 performance tests.

ANALYZE gpay.cities;
ANALYZE gpay.users;
ANALYZE gpay.bank_accounts;
ANALYZE gpay.vpas;
ANALYZE gpay.merchants;
ANALYZE gpay.transactions;
ANALYZE gpay.rewards;
ANALYZE gpay.bill_payments;
ANALYZE gpay.disputes;

COMMIT;

-- All CSV files have been loaded and the transaction has been committed.

