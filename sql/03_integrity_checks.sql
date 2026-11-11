
-- Google Pay UPI database
-- Phase 2: checks to run after loading the CSV data.
--
-- Each query returns a count. For the first four checks, we want 0:
-- that means no rows break the rule being tested.
-- The last query is different: it counts external P2P recipients and
-- is included for information, not because those rows are invalid.

SET search_path TO gpay, public;

-- 1. For a merchant payment, the payee VPA should be that merchant's VPA.
-- A non-zero count would mean the transaction points to the wrong merchant VPA.
SELECT COUNT(*) AS p2m_merchant_vpa_violations
FROM transactions t
JOIN merchants m
    ON t.merchant_id = m.merchant_id
WHERE t.txn_type = 'P2M'
  AND t.payee_vpa <> m.merchant_vpa;


-- 2. The user_id on a VPA must be the same as the user_id on its bank account.
-- This catches a VPA accidentally linked to another person's account.
SELECT COUNT(*) AS vpa_account_owner_violations
FROM vpas v
JOIN bank_accounts b
    ON v.account_id = b.account_id
WHERE v.user_id <> b.user_id;


-- 3. The reward should belong to the user who made the payment.
-- We follow the transaction's payer VPA back to its owner and compare user IDs.
SELECT COUNT(*) AS reward_owner_violations
FROM rewards r
JOIN transactions t
    ON r.txn_id = t.txn_id
JOIN vpas v
    ON t.payer_vpa = v.vpa
WHERE r.user_id <> v.user_id;


-- 4. Count users who have zero or more than one primary bank account.
-- The LEFT JOIN keeps users who have no primary account in the result too.
-- This checks the supplied data; it is not a table constraint by itself.
SELECT COUNT(*) AS users_with_invalid_primary_account_count
FROM (
    SELECT u.user_id
    FROM users u
    LEFT JOIN bank_accounts b
        ON u.user_id = b.user_id
       AND b.is_primary = TRUE
    GROUP BY u.user_id
    HAVING COUNT(b.account_id) <> 1
) invalid_users;


-- 5. Some P2P payments go to people whose VPAs are not in these CSV files.
-- We count those recipients to understand the data. This is expected and
-- should not be treated as a failed integrity check.
SELECT COUNT(*) AS external_p2p_recipients
FROM transactions t
LEFT JOIN vpas v
    ON t.payee_vpa = v.vpa
WHERE t.txn_type = 'P2P'
  AND v.vpa IS NULL;
