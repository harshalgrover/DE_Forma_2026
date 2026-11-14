# Phase 4: Query Optimization Report

## 1. Overview

This phase optimizes the 30-query Google Pay workload using PostgreSQL indexes and query rewrites.

The original workload is preserved in `queries/workload_30.sql`. Optimized queries are in `sql/06_optimized_queries.sql`, and index definitions are in `sql/05_indexes.sql`.

The official benchmark was run using:

```bash
./benchmarks/run_benchmark.sh gpay_db optimized 5 sql/06_optimized_queries.sql
```

The benchmark uses five runs and reports average execution time.

## 2. Overall Results

- Total queries benchmarked: 30
- Queries improved: 28
- Queries slower: 2
- R01 improved from 26.511 ms to 0.165 ms (99.38%).
- R19 improved from 5150.828 ms to 11.176 ms (99.78%).

Percentage improvement is calculated as:

`((Before - After) / Before) * 100`

## 3. Complete Benchmark Comparison

| Query | Type | Before (ms) | After (ms) | Improvement |
|---|---|---:|---:|---:|
| R01 | READ | 26.511 | 0.165 | 99.38% |
| R02 | READ | 0.051 | 0.040 | 21.57% |
| R03 | READ | 17.511 | 0.048 | 99.73% |
| R04 | READ | 9.810 | 0.033 | 99.66% |
| R05 | READ | 8.243 | 0.049 | 99.41% |
| R06 | READ | 8.323 | 0.467 | 94.39% |
| R07 | READ | 8.828 | 0.802 | 90.92% |
| R08 | READ | 365.723 | 46.969 | 87.16% |
| R09 | READ | 912.078 | 104.347 | 88.56% |
| R10 | READ | 2.209 | 0.025 | 98.87% |
| R11 | READ | 3.047 | 0.032 | 98.95% |
| R12 | READ | 2.553 | 0.023 | 99.10% |
| R13 | READ | 32.860 | 1.459 | 95.56% |
| R14 | READ | 17.999 | 0.090 | 99.50% |
| R15 | READ | 9.792 | 3.253 | 66.78% |
| R16 | READ | 0.327 | 0.347 | -6.12% |
| R17 | READ | 13.148 | 8.653 | 34.19% |
| R18 | READ | 24.447 | 16.824 | 31.18% |
| R19 | READ | 5150.828 | 11.176 | 99.78% |
| R20 | READ | 9.345 | 2.258 | 75.84% |
| R21 | READ | 1.032 | 0.261 | 74.71% |
| R22 | READ | 4.817 | 0.045 | 99.07% |
| R23 | READ | 68.912 | 12.147 | 82.37% |
| R24 | READ | 0.038 | 0.031 | 18.42% |
| R25 | READ | 21.969 | 14.008 | 36.24% |
| W01 | WRITE | 0.572 | 0.932 | -62.94% |
| W02 | WRITE | 24.049 | 0.338 | 98.59% |
| W03 | WRITE | 1.726 | 0.202 | 88.30% |
| W04 | WRITE | 2.585 | 0.296 | 88.55% |
| W05 | WRITE | 3.288 | 1.063 | 67.67% |

## 4. Major Execution Plan Improvements

### R01: User Transaction History

**Problem:** The original query used an OR condition between payer and payee VPAs. PostgreSQL scanned the transactions table and could not efficiently use both VPA indexes.

**Optimization:**
- Split sent and received transaction lookups into two SELECT statements.
- Combined them using UNION to eliminate duplicates.
- Added `idx_vpas_user` on `vpas(user_id) INCLUDE (vpa)`.
- Used the existing payer and payee transaction indexes.

**Plan change:**
- Before: Parallel sequential scan on transactions and sequential scans on VPAs.
- After: Index-only scan on `idx_vpas_user`, with bitmap index scans on payer and payee transaction indexes.

**Result:** 26.511 ms to 0.165 ms (99.38% faster).

### R04: Old Pending Transactions

**Problem:** The original plan scanned a large part of the transactions table and sorted pending transactions.

**Optimization:** Added a partial B-tree index:

`idx_tx_pending_time ON transactions(initiated_at) WHERE status = 'PENDING'`

**Plan change:**
- Before: Parallel sequential scan and sort.
- After: Direct index scan using `idx_tx_pending_time`.

**Result:** 9.810 ms to 0.033 ms (99.66% faster).

### R05: Merchant Successful Collections

**Problem:** The original plan used a parallel sequential scan of transactions to find successful payments for a merchant within a date range.

**Optimization:** Added a partial covering index:

`idx_tx_merchant_time_success ON transactions(merchant_id, initiated_at) INCLUDE (amount) WHERE status = 'SUCCESS'`

**Plan change:**
- Before: Parallel sequential scan on transactions.
- After: Index-only scan using `idx_tx_merchant_time_success`, with zero heap fetches in the inspected plan.

**Result:** 8.243 ms to 0.049 ms (99.41% faster).

### R19: Merchant Payment Summary

**Problem:** The original query used two correlated subqueries for every qualifying merchant. Each subquery repeatedly scanned the transactions table.

**Optimization:**
- Replaced correlated subqueries with one grouped aggregate subquery.
- Joined the aggregate result to merchants using LEFT JOIN.
- Calculated the latest payment and successful-payment count in the same grouped scan.

**Plan change:**
- Before: Two transaction-table sequential scans per qualifying merchant, with 239 loops for each correlated subplan.
- After: One parallel sequential scan, hash aggregation, and hash join.

**Result:** 5150.828 ms to 11.176 ms (99.78% faster).

A sequential scan remains in the optimized plan, but scanning the table once is much more efficient than repeatedly scanning it for every merchant.

### R22: User Bank Accounts and VPAs

**Problem:** The original plan scanned all VPAs and used a hash join.

**Optimization:**
- Added `idx_bank_accounts_user` on `bank_accounts(user_id) INCLUDE (bank_name, account_last4, is_primary)`.
- Added `idx_vpas_account` on `vpas(account_id) INCLUDE (vpa, is_active)`.

**Plan change:**
- Before: Sequential scan on VPAs and hash join.
- After: Index scan on bank accounts followed by index-only scan on VPAs.

**Result:** 4.817 ms to 0.045 ms (99.07% faster).

## 5. Other Query Rewrites and Indexing

- R03, R14 and R18 benefit from the payer/status/time index and the VPA user index.
- R06 and R15 use the partial successful-transaction time index.
- R07 uses a partial index for failed transactions.
- R08 uses a partial covering index for successful P2P transactions.
- R09 uses an index ordered by payer VPA, payee VPA and initiation time.
- R10 and R11 use partial indexes for unscratched rewards.
- R12 uses a partial index for due bills by user and due date.
- R13 uses an index on non-null merchant IDs.
- R17 uses a partial index for P2M transactions.
- R20 uses a sargable timestamp range instead of applying a date conversion in the WHERE clause.
- R21 uses a GIN trigram index for case-insensitive substring searches.
- R23 uses an index supporting newest-first transaction ordering.
- W02, W03, W04 and W05 use indexes to locate rows for updates efficiently.

## 6. R13 Correctness Fix

The original R13 used `NOT IN` with a subquery selecting `merchant_id` from transactions.

The transactions table contains NULL merchant IDs. In SQL, NULL values in a `NOT IN` subquery can make the predicate evaluate to UNKNOWN, causing the original query to return zero rows.

The optimized query uses `NOT EXISTS` to find merchants that have never had a transaction.

The corrected query returns 450 merchants. Its result was checked against an equivalent `LEFT JOIN ... IS NULL` query, and both returned the same 450 rows.

This is an intentional correctness fix based on the query's stated business purpose, not merely a performance rewrite.

## 7. Queries That Did Not Improve

### R16

- Before: 0.327 ms
- After: 0.347 ms
- Change: 6.12% slower

The absolute difference is only 0.020 ms. This is a very small query, so timing variation can be significant. No additional index was introduced solely to optimize this small difference.

### W01

- Before: 0.572 ms
- After: 0.932 ms
- Change: 62.94% slower

W01 inserts a new transaction. The additional indexes on transactions must also be maintained during insertion. This creates write overhead.

The absolute increase is 0.360 ms. This is an expected trade-off when adding indexes to improve read performance.


## 8. Index Storage Analysis

Storage was measured using PostgreSQL relation-size functions after applying the indexes.

| Table | Table Size | Index Size | Total Size |
|---|---:|---:|---:|
| bank_accounts | 4736 kB | 4736 kB | 9504 kB |
| bill_payments | 3072 kB | 792 kB | 3896 kB |
| cities | 8192 bytes | 16 kB | 24 kB |
| disputes | 336 kB | 96 kB | 464 kB |
| merchants | 280 kB | 648 kB | 960 kB |
| rewards | 3608 kB | 1000 kB | 4640 kB |
| transactions | 35 MB | 141 MB | 176 MB |
| users | 3904 kB | 3800 kB | 7736 kB |
| vpas | 4224 kB | 7712 kB | 12 MB |

The transactions table has the largest index footprint: 141 MB of indexes compared with 35 MB of table data. These indexes substantially improve read performance but increase disk usage and write-maintenance cost.

## 9. Conclusion

The optimization phase improved 28 of the 30 benchmarked queries. Major improvements came from partial and covering indexes, indexing lookup columns, replacing correlated subqueries with grouped aggregation, and making date filtering sargable.

The two regressions are documented transparently:

- R16 has a very small absolute timing difference of 0.020 ms.
- W01 incurs additional index-maintenance overhead during transaction insertion.

The optimized workload preserves the original query results for the tested rewrites, with R13 documented as an intentional correction of NULL-related behavior.