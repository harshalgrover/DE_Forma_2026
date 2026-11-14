CREATE EXTENSION IF NOT EXISTS pg_trgm;

SET search_path TO gpay, public;

-- R01: Find transactions sent by a VPA, newest first.
CREATE INDEX IF NOT EXISTS idx_tx_payer_time
ON transactions (payer_vpa, initiated_at DESC);

-- R01: Find transactions received by a VPA, newest first.
CREATE INDEX IF NOT EXISTS idx_tx_payee_time
ON transactions (payee_vpa, initiated_at DESC);

-- R03, R14, R18: Find successful/pending transactions by payer VPA.
CREATE INDEX IF NOT EXISTS idx_tx_payer_status_time
ON transactions (payer_vpa, status, initiated_at)
INCLUDE (merchant_id, amount);

-- R04: Find old pending transactions efficiently.
CREATE INDEX IF NOT EXISTS idx_tx_pending_time
ON transactions (initiated_at)
WHERE status = 'PENDING';

-- W02: Find the oldest pending transaction by txn_id.
CREATE INDEX IF NOT EXISTS idx_tx_pending_id
ON transactions (txn_id)
WHERE status = 'PENDING';

-- R05: Merchant-specific successful collections by time.
CREATE INDEX IF NOT EXISTS idx_tx_merchant_time_success
ON transactions (merchant_id, initiated_at)
INCLUDE (amount)
WHERE status = 'SUCCESS';

-- R06, R15: Successful transactions within date ranges.
CREATE INDEX IF NOT EXISTS idx_tx_success_time
ON transactions (initiated_at)
INCLUDE (merchant_id, amount)
WHERE status = 'SUCCESS';

-- R07: Failed transactions by date, payer VPA and failure code.
CREATE INDEX IF NOT EXISTS idx_tx_failed_time
ON transactions (initiated_at)
INCLUDE (payer_vpa, failure_code)
WHERE status = 'FAILED';

-- R08: Successful P2P transactions grouped by recipient and date.
CREATE INDEX IF NOT EXISTS idx_tx_p2p_recipient_time
ON transactions (payee_vpa, initiated_at)
INCLUDE (payer_vpa, amount)
WHERE txn_type = 'P2P' AND status = 'SUCCESS';

-- R09: Repeated successful payments between the same VPAs.
CREATE INDEX IF NOT EXISTS idx_tx_success_vpa_pair_time
ON transactions (payer_vpa, payee_vpa, initiated_at)
INCLUDE (amount)
WHERE status = 'SUCCESS';

-- R13: Check whether a merchant has any transaction records.
CREATE INDEX IF NOT EXISTS idx_tx_merchant_id
ON transactions (merchant_id)
WHERE merchant_id IS NOT NULL;

-- R17: Group P2M transactions by merchant and status.
CREATE INDEX IF NOT EXISTS idx_tx_p2m_merchant
ON transactions (merchant_id)
INCLUDE (status)
WHERE txn_type = 'P2M';

-- R23: Support newest-first transaction ordering.
CREATE INDEX IF NOT EXISTS idx_tx_initiated_desc
ON transactions (initiated_at DESC)
INCLUDE (txn_id, upi_ref, txn_type, amount, status);

-- R25: Find completed transactions by payer and initiation time.
CREATE INDEX IF NOT EXISTS idx_tx_completed_payer_time
ON transactions (payer_vpa, initiated_at)
INCLUDE (completed_at)
WHERE completed_at IS NOT NULL;

-- R10: User's unscratched rewards ordered by expiry.
CREATE INDEX IF NOT EXISTS idx_rewards_user_expiry
ON rewards (user_id, expires_at)
INCLUDE (reward_type, issued_at)
WHERE status = 'UNSCRATCHED';

-- R11, W04: Find unscratched rewards that have expired.
CREATE INDEX IF NOT EXISTS idx_rewards_expiry
ON rewards (expires_at)
INCLUDE (user_id)
WHERE status = 'UNSCRATCHED';

-- W03: Find the oldest unscratched reward for a user.
CREATE INDEX IF NOT EXISTS idx_rewards_user_oldest
ON rewards (user_id, reward_id)
WHERE status = 'UNSCRATCHED';

-- R12: Find a user's due bills within a date range.
CREATE INDEX IF NOT EXISTS idx_bills_user_due_date
ON bill_payments (user_id, due_date)
INCLUDE (biller_name, amount)
WHERE status = 'DUE';

-- W05: Find all due bills before a date.
CREATE INDEX IF NOT EXISTS idx_bills_due_date
ON bill_payments (due_date)
WHERE status = 'DUE';

-- R21: Accelerate case-insensitive substring merchant-name searches.
CREATE INDEX IF NOT EXISTS idx_merchants_name_trgm
ON merchants USING GIN (merchant_name gin_trgm_ops);

-- R22: Find a user's bank accounts.
CREATE INDEX IF NOT EXISTS idx_bank_accounts_user
ON bank_accounts (user_id)
INCLUDE (bank_name, account_last4, is_primary);

-- R22: Find VPAs linked to a bank account.
CREATE INDEX IF NOT EXISTS idx_vpas_account
ON vpas (account_id)
INCLUDE (vpa, is_active);

ANALYZE;

-- R01, R03, R14, R18: Quickly find a user's VPAs.
CREATE INDEX IF NOT EXISTS idx_vpas_user
ON vpas (user_id)
INCLUDE (vpa);
