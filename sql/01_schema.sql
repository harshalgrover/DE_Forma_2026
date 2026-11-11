
-- Google Pay UPI database
-- Phase 2: create the tables and define the rules for the data.
-- Run this file against an empty project database.
--
-- We are not adding query-optimization indexes here. Those come later,
-- after we measure the original queries in the baseline phase.

BEGIN;

CREATE SCHEMA IF NOT EXISTS gpay;

SET search_path TO gpay, public;


-- 1. CITIES
-- We create this first because both users and merchants refer to a city.

CREATE TABLE cities (
    city_id     INTEGER PRIMARY KEY,
    city_name   VARCHAR(100) NOT NULL,
    state       VARCHAR(100) NOT NULL
);


-- 2. USERS
-- Each row represents a person using the app. A user must have a city,
-- phone number and KYC status. Email is optional in the supplied data.

CREATE TABLE users (
    user_id       INTEGER PRIMARY KEY,
    full_name     VARCHAR(150) NOT NULL,
    phone         VARCHAR(10) NOT NULL UNIQUE,
    email         VARCHAR(255) UNIQUE,
    city_id       INTEGER NOT NULL,
    kyc_status    VARCHAR(20) NOT NULL,
    is_blocked    BOOLEAN NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_users_city
        FOREIGN KEY (city_id)
        REFERENCES cities(city_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_users_phone
        CHECK (phone ~ '^[0-9]{10}$'),

    CONSTRAINT chk_users_kyc_status
        CHECK (kyc_status IN ('PENDING', 'VERIFIED', 'REJECTED'))
);


-- 3. BANK ACCOUNTS
-- A user can link more than one bank account.

CREATE TABLE bank_accounts (
    account_id       INTEGER PRIMARY KEY,
    user_id          INTEGER NOT NULL,
    bank_name        VARCHAR(100) NOT NULL,
    ifsc             VARCHAR(11) NOT NULL,
    account_last4    VARCHAR(4) NOT NULL,
    account_type     VARCHAR(20) NOT NULL,
    is_primary       BOOLEAN NOT NULL,
    linked_at        TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_bank_accounts_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    -- vpas checks account_id and user_id together. This UNIQUE constraint
    -- gives PostgreSQL a matching pair of columns to reference.
    CONSTRAINT uq_bank_accounts_account_user
        UNIQUE (account_id, user_id),

    CONSTRAINT chk_bank_accounts_ifsc
        CHECK (ifsc ~ '^[A-Z]{4}0[A-Z0-9]{6}$'),

    CONSTRAINT chk_bank_accounts_last4
        CHECK (account_last4 ~ '^[0-9]{4}$'),

    CONSTRAINT chk_bank_accounts_type
        CHECK (account_type IN ('SAVINGS', 'CURRENT'))
);


-- 4. VPAS
-- A VPA is linked to both a user and one of their bank accounts.
-- The two-column foreign key below prevents a VPA from being linked
-- to somebody else's bank account.

CREATE TABLE vpas (
    vpa          VARCHAR(255) PRIMARY KEY,
    user_id      INTEGER NOT NULL,
    account_id   INTEGER NOT NULL,
    is_active    BOOLEAN NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_vpas_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_vpas_account_owner
        FOREIGN KEY (account_id, user_id)
        REFERENCES bank_accounts(account_id, user_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_vpas_format
        CHECK (vpa ~ '^[^@[:space:]]+@[^@[:space:]]+$')
);


-- 5. MERCHANTS
-- Merchant details are kept separately from normal user accounts.

CREATE TABLE merchants (
    merchant_id     INTEGER PRIMARY KEY,
    merchant_name   VARCHAR(150) NOT NULL,
    mcc             VARCHAR(4) NOT NULL,
    merchant_vpa    VARCHAR(255) NOT NULL UNIQUE,
    city_id         INTEGER NOT NULL,
    is_verified     BOOLEAN NOT NULL,
    onboarded_on    DATE NOT NULL,

    CONSTRAINT fk_merchants_city
        FOREIGN KEY (city_id)
        REFERENCES cities(city_id)
        ON DELETE RESTRICT,

    -- A P2M transaction references this pair so its merchant_id and
    -- payee_vpa must point to the same merchant.
    CONSTRAINT uq_merchants_id_vpa
        UNIQUE (merchant_id, merchant_vpa),

    CONSTRAINT chk_merchants_mcc
        CHECK (mcc ~ '^[0-9]{4}$'),

    CONSTRAINT chk_merchants_vpa_format
        CHECK (merchant_vpa ~ '^[^@[:space:]]+@[^@[:space:]]+$')
);


-- 6. TRANSACTIONS
-- Every transaction has a payer and a payee.
-- The payer must be one of the VPAs stored in our dataset.
--
-- We do not make payee_vpa a normal foreign key to vpas:
-- a P2P payment can go to someone outside the supplied dataset.
-- For P2M payments, the composite foreign key below checks the
-- payee VPA against the merchant record instead.

CREATE TABLE transactions (
    txn_id         INTEGER PRIMARY KEY,
    upi_ref        VARCHAR(12) NOT NULL UNIQUE,
    txn_type       VARCHAR(3) NOT NULL,
    payer_vpa      VARCHAR(255) NOT NULL,
    payee_vpa      VARCHAR(255) NOT NULL,
    merchant_id    INTEGER,
    amount         NUMERIC(12,2) NOT NULL,
    note           TEXT,
    initiated_at   TIMESTAMPTZ NOT NULL,
    completed_at   TIMESTAMPTZ,
    status         VARCHAR(20) NOT NULL,
    failure_code   VARCHAR(3),

    CONSTRAINT fk_transactions_payer
        FOREIGN KEY (payer_vpa)
        REFERENCES vpas(vpa)
        ON DELETE RESTRICT,

    -- For P2M, merchant_id and payee_vpa must match one merchant row.
    -- For P2P, merchant_id is NULL, so PostgreSQL's default MATCH SIMPLE
    -- behaviour skips this composite foreign-key check.
    CONSTRAINT fk_transactions_merchant_payee
        FOREIGN KEY (merchant_id, payee_vpa)
        REFERENCES merchants(merchant_id, merchant_vpa)
        ON DELETE RESTRICT,

    CONSTRAINT chk_transactions_upi_ref
        CHECK (upi_ref ~ '^[0-9]{12}$'),

    CONSTRAINT chk_transactions_type
        CHECK (txn_type IN ('P2P', 'P2M')),

    CONSTRAINT chk_transactions_status
        CHECK (status IN (
            'FAILED',
            'PENDING',
            'REFUNDED',
            'REVERSED',
            'SUCCESS'
        )),

    CONSTRAINT chk_transactions_amount
        CHECK (amount > 0),

    CONSTRAINT chk_transactions_failure_code
        CHECK (
            failure_code IS NULL
            OR failure_code IN ('U16', 'U30', 'U69', 'XH', 'Z9', 'ZM')
        ),

    CONSTRAINT chk_transactions_failure_status
        CHECK (
            (status = 'FAILED' AND failure_code IS NOT NULL)
            OR
            (status <> 'FAILED' AND failure_code IS NULL)
        ),

    CONSTRAINT chk_transactions_completion_status
        CHECK (
            (status = 'PENDING' AND completed_at IS NULL)
            OR
            (status <> 'PENDING' AND completed_at IS NOT NULL)
        ),

    CONSTRAINT chk_transactions_merchant_type
        CHECK (
            (txn_type = 'P2M' AND merchant_id IS NOT NULL)
            OR
            (txn_type = 'P2P' AND merchant_id IS NULL)
        ),

    CONSTRAINT chk_transactions_different_vpas
        CHECK (payer_vpa <> payee_vpa),

    CONSTRAINT chk_transactions_timestamp
        CHECK (
            completed_at IS NULL
            OR completed_at >= initiated_at
        )
);


-- 7. REWARDS
-- A reward is linked to the user and the transaction that earned it.

CREATE TABLE rewards (
    reward_id     INTEGER PRIMARY KEY,
    user_id       INTEGER NOT NULL,
    txn_id        INTEGER NOT NULL,
    reward_type   VARCHAR(20) NOT NULL,
    amount        NUMERIC(12,2) NOT NULL,
    status        VARCHAR(20) NOT NULL,
    issued_at     TIMESTAMPTZ NOT NULL,
    expires_at    TIMESTAMPTZ NOT NULL,
    credited_at   TIMESTAMPTZ,

    CONSTRAINT fk_rewards_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rewards_transaction
        FOREIGN KEY (txn_id)
        REFERENCES transactions(txn_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_rewards_type
        CHECK (reward_type IN (
            'CASHBACK',
            'COUPON',
            'SCRATCH_CARD'
        )),

    CONSTRAINT chk_rewards_status
        CHECK (status IN (
            'CREDITED',
            'EXPIRED',
            'UNSCRATCHED'
        )),

    CONSTRAINT chk_rewards_amount
        CHECK (amount >= 0),

    CONSTRAINT chk_rewards_credit_status
        CHECK (
            (status = 'CREDITED' AND credited_at IS NOT NULL)
            OR
            (status IN ('EXPIRED', 'UNSCRATCHED')
             AND credited_at IS NULL)
        ),

    CONSTRAINT chk_rewards_expiry
        CHECK (expires_at >= issued_at),

    CONSTRAINT chk_rewards_credit_timestamp
        CHECK (
            credited_at IS NULL
            OR credited_at >= issued_at
        )
);


-- 8. BILL PAYMENTS
-- paid_at is only filled when the bill has been paid.

CREATE TABLE bill_payments (
    bill_id           INTEGER PRIMARY KEY,
    user_id           INTEGER NOT NULL,
    biller_category   VARCHAR(20) NOT NULL,
    biller_name       VARCHAR(150) NOT NULL,
    consumer_number   VARCHAR(50) NOT NULL,
    amount            NUMERIC(12,2) NOT NULL,
    due_date          DATE NOT NULL,
    status            VARCHAR(20) NOT NULL,
    paid_at           TIMESTAMPTZ,

    CONSTRAINT fk_bill_payments_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_bill_payments_category
        CHECK (biller_category IN (
            'BROADBAND',
            'DTH',
            'ELECTRICITY',
            'FASTAG',
            'GAS',
            'MOBILE',
            'WATER'
        )),

    CONSTRAINT chk_bill_payments_status
        CHECK (status IN ('DUE', 'OVERDUE', 'PAID')),

    CONSTRAINT chk_bill_payments_amount
        CHECK (amount > 0),

    CONSTRAINT chk_bill_payments_paid_status
        CHECK (
            (status = 'PAID' AND paid_at IS NOT NULL)
            OR
            (status IN ('DUE', 'OVERDUE') AND paid_at IS NULL)
        )
);


-- 9. DISPUTES
-- A dispute records who raised it and which transaction it concerns.
-- An open dispute has no resolved_at timestamp yet.

CREATE TABLE disputes (
    dispute_id   INTEGER PRIMARY KEY,
    txn_id       INTEGER NOT NULL,
    raised_by    INTEGER NOT NULL,
    reason       VARCHAR(50) NOT NULL,
    raised_at    TIMESTAMPTZ NOT NULL,
    status       VARCHAR(20) NOT NULL,
    resolved_at  TIMESTAMPTZ,

    CONSTRAINT fk_disputes_transaction
        FOREIGN KEY (txn_id)
        REFERENCES transactions(txn_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_disputes_user
        FOREIGN KEY (raised_by)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_disputes_reason
        CHECK (reason IN (
            'DUPLICATE_PAYMENT',
            'FRAUD',
            'MERCHANT_NOT_DELIVERED',
            'MONEY_DEBITED_NOT_CREDITED',
            'WRONG_PAYEE'
        )),

    CONSTRAINT chk_disputes_status
        CHECK (status IN ('OPEN', 'REJECTED', 'RESOLVED')),

    CONSTRAINT chk_disputes_resolution_status
        CHECK (
            (status = 'OPEN' AND resolved_at IS NULL)
            OR
            (status IN ('REJECTED', 'RESOLVED')
             AND resolved_at IS NOT NULL)
        ),

    CONSTRAINT chk_disputes_timestamp
        CHECK (
            resolved_at IS NULL
            OR resolved_at >= raised_at
        )
);


COMMIT;

-- All nine tables have been created. The transaction commits here.
