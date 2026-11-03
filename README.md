# Google Pay (UPI) Digital Payments Database: DBMS Project

**Course:** Database Management Systems · **Year:** B.Tech 2nd year · **Team size:** 4
**Database:** PostgreSQL 15 or newer · **Final submission:** Mon 23 Nov 2026
**Topics used:** Data types & constraints · Keys & relationships · Normalization · Query execution plans · Indexing · Query optimization · VACUUM/ANALYZE · Partitioning & sharding

## Files in this folder

| Path | What it is |
|------|------------|
| `README.md` | This project brief |
| `seed_data.zip` | 9 CSV files (250,468 UPI transactions): the only input for Phase 2. Unzip it to get `seed_data/` |
| `queries/workload_30.sql` | The 30 queries for Phase 3 (do not edit) |
| `benchmarks/run_benchmark.sh` | Timing script: 3 runs per query, average, raw plans saved |
| `CHECKPOINTS.md` | Checkpoint dates and the files each one needs (DE and AP repos) |

**Getting started:** **clone this repository and push it into your team's DE repo** (the DE repo you submitted in the form); the steps are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Keep the structure shown in [Repository structure](#repository-structure-submit-exactly-this). Unzip `seed_data.zip` inside your project folder, but don't commit the CSV files. Deadlines are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Then begin with Phase 1.

---

## Team details (fill in before you start)

| Role | Name | Enrollment No. | GitHub Username |
|------|------|----------------|-----------------|
| Group Lead | Harshal Grover | 2501010180 | harshalgrover|
| Member 2 | Jahanvi Jain | 2501010196 | jahanvijain02 |
| Member 3 |Yogye Berry | 2501010532 | yogyeberry |
| Member 4 | Yug Rastogi| 2501010684 | yugrastogi |

**Team No.:** T0089 · **Section:** D · **Repository URL:** https://github.com/harshalgrover/DE_Forma_2026

---

## How this project works

| Phase | What you do | You submit | Counts toward | Marks |
|-------|-------------|------------|---------------|------:|
| 1 | Understand the problem statements | `docs/01_problem_understanding.md` | Query Execution | 2 |
| 2 | Work out the database schema **from the seed data** and load it | `sql/01_schema.sql`, `sql/02_load_data.sql`, `docs/02_schema_design.md` | Query Execution | 5 |
| 3 | Run the **30 given SQL queries** and record their execution time | `docs/03_baseline_timings.md`, `benchmarks/results/baseline/` | Query Execution | 3 |
| 4 | Optimize the queries and record the new times | `sql/05_indexes.sql`, `sql/06_optimized_queries.sql`, `docs/04_optimization_report.md`, `benchmarks/results/optimized/` | Code Optimization | 16 |
| 5 | Scalability test on the **large dataset** (given later by faculty) and final report | `docs/05_scalability_report.md`, `benchmarks/results/large/` | Code Optimization | 14 |
| | **Total** | | | **40** |

---

## Phase 1: Problem statements

Google Pay is a **UPI** app. A user links one or more **bank accounts** (identified by IFSC) and gets a **UPI ID (VPA)** such as `name@okaxis` for each. Users pay friends (**P2P**)—who may use another UPI app such as PhonePe or Paytm—and pay **merchants** (**P2M**) by scanning a QR code. Every payment gets a 12-digit UPI reference number and ends as success, failure (with an NPCI failure code), reversal or refund. Users earn scratch-card **rewards**, pay **bills**, and raise **disputes**. You have joined the Google Pay India data team.

The current database was put together quickly by an earlier team. It has **no documented schema** (only data exports survive), and the product teams are complaining:

| # | Problem reported | Team | Related queries |
|---|------------------|------|-----------------|
| P1 | "**Transaction history** and the **pay screen** (VPA check, linked accounts) are slow for active users." | User app | R01, R02, R22 |
| P2 | "The **daily UPI limit** check runs on every payment and is too slow." | Payments core | R03, W01 |
| P3 | "**Reconciliation** of stuck PENDING payments and bank callbacks lag." | Ops / Reconciliation | R04, W02 |
| P4 | "**Merchants** want live collections and daily **settlement**; the success team's "merchants with no payments" list is **empty**." | Merchants | R05, R06, R13 |
| P5 | "**Fraud & risk** need mule-account, repeat-payment and refund-rate checks in near real time." | Fraud & Risk | R08, R09, R17 |
| P6 | "**Rewards and bill reminders** jobs (scratch cards, expiry, overdue bills) are slow." | Rewards / Bills | R10, R11, R12, W03, W04, W05 |
| P7 | "**Compliance** needs KYC-risk reports; support needs instant lookups by UPI reference and fast dispute queues." | Compliance / Support | R16, R18, R23, R24 |
| P8 | "**Bank health** dashboards (failure codes, latency, success rate) and business insights time out, and UPI volume will grow **20×**." | Bank partnerships / Analytics | R07, R14, R15, R19, R20, R21, R25 |

**Your job:**
1. Rebuild a correct, well-constrained schema from the data exports (Phase 2).
2. Measure how the 30 most important queries perform today (Phase 3).
3. Make them fast **without changing their results** (Phase 4).
4. Prove the database will survive next year's growth (Phase 5).

**Deliverable for Phase 1** (`docs/01_problem_understanding.md`, at most 1 page):
- For each problem P1–P8, write in your own words what the business needs and which **stakeholder** is affected (payer, payee, merchant, bank partner, reconciliation/ops, fraud & risk, compliance (RBI/KYC), rewards team, customer support).
- Classify each problem as **customer-facing / real-time** or **reporting / analytics**. This decides your performance targets later.
- List any assumptions you make.

---

## Phase 2: Work out the schema from the seed data

You receive **`seed_data.zip`**. Unzip it to get a folder **`seed_data/`** with 9 CSV files, a real export of the production data:

| File | Rows | What it contains |
|------|-----:|------------------|
| `cities.csv` | 10 | Cities |
| `users.csv` | 40,000 | Google Pay users |
| `bank_accounts.csv` | 53,333 | Bank accounts linked by each user |
| `vpas.csv` | 53,333 | UPI IDs (virtual payment addresses) of each user |
| `merchants.csv` | 3,000 | Businesses that accept Google Pay |
| `transactions.csv` | 250,468 | Every UPI payment from 1 Jan 2025 to 30 Jun 2026 |
| `rewards.csv` | 39,799 | Scratch cards and cashback |
| `bill_payments.csv` | 30,000 | Utility and recharge bills |
| `disputes.csv` | 3,569 | Complaints raised about payments |

The first line of every file is the header (column names). Here are the headers and the first rows of each file:

**cities.csv**
```
city_id,city_name,state
1,Bengaluru,Karnataka
2,Mumbai,Maharashtra
```

**users.csv**
```
user_id,full_name,phone,email,city_id,kyc_status,is_blocked,created_at
1,Vivaan Sharma,9000000001,,2,PENDING,f,2021-11-24 11:53:54+05:30
2,Aditya Sharma,9000000002,adityasharma2@gmail.com,4,VERIFIED,f,2023-11-15 15:07:21+05:30
```

**bank_accounts.csv**
```
account_id,user_id,bank_name,ifsc,account_last4,account_type,is_primary,linked_at
1,1,HDFC Bank,HDFC0000037,7919,SAVINGS,t,2021-11-24 11:53:54+05:30
3,2,ICICI Bank,ICIC0000074,5838,SAVINGS,t,2023-11-15 15:07:21+05:30
```

**vpas.csv**
```
vpa,user_id,account_id,is_active,created_at
aarav.banerjee10325@oksbi,10325,20649,t,2021-04-11 22:33:07+05:30
aarav.banerjee10825@okhdfcbank,10825,21649,t,2024-02-09 00:00:47+05:30
```

**merchants.csv**
```
merchant_id,merchant_name,mcc,merchant_vpa,city_id,is_verified,onboarded_on
1,Ganesh Store 1,5912,ganesh1@okbizaxis,4,t,2024-02-11
2,Balaji Store 2,7832,balaji2@okbizaxis,1,t,2019-01-02
```

**transactions.csv**
```
txn_id,upi_ref,txn_type,payer_vpa,payee_vpa,merchant_id,amount,note,initiated_at,completed_at,status,failure_code
1,600000007919,P2M,sneha.joshi18289@okhdfcbank,balaji692@okbizaxis,692,20.15,,2025-01-01 00:00:00+05:30,2025-01-01 00:00:03+05:30,SUCCESS,
2,600000015838,P2M,aryan.patel7144@oksbi,sharma2360@okbizaxis,2360,20.01,,2025-01-01 00:03:08+05:30,2025-01-01 00:03:09+05:30,SUCCESS,
```

**rewards.csv**
```
reward_id,user_id,txn_id,reward_type,amount,status,issued_at,expires_at,credited_at
1,4578,5,CASHBACK,41.00,CREDITED,2025-01-01 00:12:36+05:30,2025-01-31 00:12:36+05:30,2025-01-01 02:54:36+05:30
2,30694,10,SCRATCH_CARD,36.00,CREDITED,2025-01-01 00:28:20+05:30,2025-01-31 00:28:20+05:30,2025-01-01 09:08:20+05:30
```

**bill_payments.csv**
```
bill_id,user_id,biller_category,biller_name,consumer_number,amount,due_date,status,paid_at
1,23509,MOBILE,Tata Power,0000007919,188.58,2025-05-05,PAID,2025-05-04 03:00:00+05:30
2,38737,MOBILE,Adani Electricity,0000015838,3922.00,2025-08-26,PAID,2025-08-24 02:00:00+05:30
```

**disputes.csv**
```
dispute_id,txn_id,raised_by,reason,raised_at,status,resolved_at
1,25,4423,MONEY_DEBITED_NOT_CREDITED,2025-01-02 04:15:29+05:30,RESOLVED,2025-01-10 04:15:29+05:30
2,30,10396,FRAUD,2025-01-01 15:31:13+05:30,RESOLVED,2025-01-21 15:31:13+05:30
```

Open the files yourself (a spreadsheet, `head`, or `SELECT` after a quick load into a scratch table) and study the data carefully. **Nobody will give you the CREATE TABLE statements.** Working them out *is* the task.

### 2.1 What you must identify (for every table)
1. **Table name and column names.** Use exactly the file names and CSV headers. The 30 queries depend on them.
2. **Data type** of every column. Choose the *right* type, not just `TEXT` everywhere. Think about money, timestamps with a time-zone offset, yes/no columns, small whole numbers, decimals and short codes.
3. **Primary key.** Is it one column, or a combination? (What is the natural key of a UPI ID? Can `vpas` use the VPA text itself as its primary key? Which tables need a natural UNIQUE key besides their id?)
4. **Foreign keys.** Which column points to which table? What should happen **ON DELETE** (CASCADE, RESTRICT or SET NULL), and why?
5. **NOT NULL vs NULL.** Some columns are empty in some rows. Find out **when** and **why**, and decide which columns must never be empty. Why do some payments have no `merchant_id`? When are `completed_at`, `failure_code`, `credited_at`, `paid_at`, `resolved_at`, `email` and `note` empty?
6. **UNIQUE** columns (natural candidate keys such as emails, phone numbers, codes and handles).
7. **CHECK constraints.** Write at least **12** that the data obeys and the business needs. Look for formats (IFSC, VPA, 12-digit UPI reference, MCC, last 4 digits), allowed values (statuses, types, failure codes, biller categories, dispute reasons), limits (UPI amount cap) and rules tying columns together (P2M ⇔ merchant, failed ⇔ failure code, pending ⇔ not completed, refunds only for merchant payments, payer ≠ payee, at most one primary account per user).
8. **Relationships and cardinalities** (1:1, 1:N, M:N). Draw the **ER diagram** (image + Mermaid code).
9. **Normal form.** Show that each table is in 3NF/BCNF (list its functional dependencies). Point out any column that is *derived or redundant* (hint: `rewards.user_id` vs the payer of `rewards.txn_id`; `transactions.payee_vpa` vs `merchants.merchant_vpa` for P2M payments; `vpas.user_id` vs `bank_accounts.user_id`) and say whether keeping it is justified.

### 2.2 Rules for your schema
- Create every table in a schema named **`gpay`**: `CREATE SCHEMA gpay;` and `SET search_path TO gpay;`
- In this phase create **only constraints**: PK, FK, UNIQUE, NOT NULL, CHECK. **Do not create any other index yet.** (PostgreSQL automatically indexes PRIMARY KEY and UNIQUE columns; that's allowed. Note which indexes exist.) Your baseline in Phase 3 must reflect a database *without* tuning.
- Your constraints must accept **all** rows of the seed data. If a load fails, either your constraint is wrong or you found a data problem. Explain which in your design doc.

### 2.3 Load the data
Write `sql/02_load_data.sql` using `\copy`, loading tables in the right order (parents before children):

```sql
SET search_path TO gpay;
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
-- ... the other tables, in an order that satisfies your foreign keys
ANALYZE;
```

Then verify the row counts match the table above, and run at least **3 integrity checks** of your own (e.g. "for P2M payments the payee VPA equals the merchant's VPA", "a VPA and its bank account belong to the same user", "every user has exactly one primary bank account"). Paste the results into `docs/02_schema_design.md`.

### Phase 2 deliverables
- `sql/01_schema.sql`: runs top-to-bottom on an empty database without errors
- `sql/02_load_data.sql`: loads all 9 files without errors
- `docs/02_schema_design.md`: data dictionary (table · column · type · constraint · *why*), ER diagram, FDs and normal form per table, integrity-check results, and every data problem you found

---

## Phase 3: Run the 30 queries and record the time

The file **`queries/workload_30.sql`** contains **30 queries**: 25 reads (`R01`–`R25`) and 5 writes (`W01`–`W05`). They're also listed in the [Appendix](#appendix-the-30-queries). **Do not modify them.** If a query fails, your schema doesn't match the seed data; fix the schema, not the query.

### 3.1 How to measure (everyone must use the same method)
- Run each query with `EXPLAIN (ANALYZE, BUFFERS)` and read the **`Execution Time`** at the bottom.
- Run each query **3 times** and record the **average** of the three `Execution Time` values. Keep all three runs in the raw plan file.
- Write queries (`W01`–`W05`) must be measured inside `BEGIN; … ROLLBACK;` so the data does not change.
- Close other heavy applications while measuring, and use the **same laptop** for Phase 3 and Phase 4.

The helper script does all of this for you:
```bash
./benchmarks/run_benchmark.sh <your_database> baseline
# → benchmarks/results/baseline/summary.csv   (avg, median, min, max, scan types)
# → benchmarks/results/baseline/R01.txt …     (full plans of all 3 runs)
```
> ⚠️ One of the 30 queries takes **several seconds** on the seed data. That's intentional. Let it finish, and don't skip it.

### 3.2 Deliverable: the timing table
In `docs/03_baseline_timings.md`, fill this table for **all 30** queries:

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Transaction history: everything user 15177 sent or received, newest first | READ | | | | |
| R02: "Pay to UPI ID": check that the entered VPA exists and is active | READ | | | | |
| R03: UPI limit check: total successfully sent by user 15177 on 30 June 2026 (limit ₹1,00,000/day) | READ | | | | |
| R04: Reconciliation: payments still PENDING more than 15 minutes after 23:59 on 30 Jun 2026 | READ | | | | |
| R05: Google Pay for Business: hourly collections of merchant 2 on 29 June 2026 | READ | | | | |
| R06: Settlement: amount to settle to every merchant for 29 June 2026 | READ | | | | |
| R07: Bank health: failure codes per payer bank in the last 7 days | READ | | | | |
| R08: Fraud: VPAs that received P2P money from 5+ different people on the same day | READ | | | | |
| R09: Fraud: repeated payments—same payer to the same payee within 10 minutes of the previous one | READ | | | | |
| R10: Rewards tab: user 15177's unscratched cards that have not expired | READ | | | | |
| R11: Notification job: unscratched rewards that expire in the first 3 days of July | READ | | | | |
| R12: Bill reminders: user 1072's unpaid bills due in the next 7 days | READ | | | | |
| R13: Merchant success team: merchants who have never received a payment (to call and help them) | READ | | | | |
| R14: Spend analysis: user 15177's 2026 spending per merchant category code (MCC) | READ | | | | |
| R15: Business insights: top 10 merchants by June 2026 GMV in each city | READ | | | | |
| R16: Disputes desk: disputes open for more than 7 days (SLA breached) | READ | | | | |
| R17: Merchant risk: refund rate per merchant (at least 30 payments) | READ | | | | |
| R18: Compliance: users without verified KYC who have successfully sent ₹10,000+ in total | READ | | | | |
| R19: Merchant report: last payment time and successful payment count of every verified Bengaluru merchant | READ | | | | |
| R20: Platform health: daily success rate in June 2026 | READ | | | | |
| R21: "Search businesses": merchants with "chai" in their name | READ | | | | |
| R22: Payment screen: user 15177's primary bank account and all their UPI IDs | READ | | | | |
| R23: Operations console: all transactions, newest first, page 8,001 (25 per page) | READ | | | | |
| R24: Customer support: find a payment by its UPI reference number | READ | | | | |
| R25: Bank health: average seconds from initiation to completion per payer bank (June 2026) | READ | | | | |
| W01: Pay: user 15177 starts a ₹250 payment to merchant 2 (PENDING until the bank confirms) | WRITE | | | | |
| W02: Bank callback: mark the oldest PENDING payment as successful | WRITE | | | | |
| W03: Scratch card: user 15177 scratches their oldest unscratched card | WRITE | | | | |
| W04: Nightly job (run at 00:00 on 4 Jul 2026): expire every reward whose time is up | WRITE | | | | |
| W05: Nightly job: bills past their due date and still unpaid become OVERDUE | WRITE | | | | |
| **Total (sum of all 30)** | | | | | |

Below the table, add for each query the **scan type** from the plan (Seq Scan, Index Scan, …) and one line on **why** it is slow or fast.

---

## Phase 4: Optimize the queries

Make the queries faster. **The results must stay the same** (same rows; order matters only where the query has an `ORDER BY`).

### 4.1 Techniques you may use
| Technique | Example |
|-----------|---------|
| B-tree index (single / composite) | the right column **order** matters: equality columns first, then range/sort |
| Partial index | index only the rows a query needs (e.g. a rare status) |
| Covering index | `INCLUDE (...)` so the table is never visited (Index Only Scan) |
| Expression index | index the exact expression used in `WHERE` |
| GIN index | for `ILIKE '%text%'` (extension `pg_trgm`), arrays or full-text search |
| BRIN index | for huge tables stored in time order |
| Query rewrite | sargable date ranges instead of functions on columns; `NOT EXISTS` instead of `NOT IN`; joins instead of correlated subqueries; keyset instead of `OFFSET` pagination; `UNION ALL` instead of `OR` across columns |
| VACUUM / ANALYZE | fresh statistics and visibility maps |
| Summary table / materialized view | for heavy reports that don't need live data (state how it's refreshed) |

**Not allowed:** changing the data, deleting rows, changing PostgreSQL server settings to hide the problem (e.g. huge `work_mem`, `enable_seqscan = off`), or caching results outside the database.

### 4.2 How to work
1. Put every index in `sql/05_indexes.sql`, each with a comment: **which queries it serves and why this type and column order**.
2. Put rewritten queries in `sql/06_optimized_queries.sql`. Copy `queries/workload_30.sql` and change **only** the queries you rewrite, keeping the `-- @R01` markers.
3. **Prove the results are unchanged** for every rewritten query (compare row counts, plus a checksum or an `EXCEPT` query). Put the proof in your report.
4. Benchmark again with the same method:
```bash
./benchmarks/run_benchmark.sh <your_database> optimized 5 sql/06_optimized_queries.sql
```
> 🔎 **Read the results, not just the timings.** At least one of the 30 original queries returns a **wrong answer** because of a subtle SQL rule about NULLs. Find it, explain it, and fix it. This is worth marks.

### 4.3 Deliverable: the optimization table
In `docs/04_optimization_report.md`:

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|-------|------------:|---------------------------|----------------------|-----------:|------------:|:------------:|
| R03 | | e.g. Seq Scan on 250k transactions + DATE() | e.g. sargable range + index on `transactions(payer_vpa, initiated_at)` | | e.g. 99% (110×) | ✅ |
| … all 30 … | | | | | | |
| **Total** | | | | | | |

Improvement % = (before − after) / before × 100

Also include:
- **Before/after `EXPLAIN` plans** for your 5 biggest improvements
- **Write overhead:** which write queries got **slower** because of your indexes, by how much, and whether that's acceptable
- **Index storage:** the size of each index you created (`pg_relation_size`) compared with its table
- **Queries you could not speed up**, and why (an honest "this query must read most of the table" earns marks)

---

## Phase 5: Scalability report (large dataset round)

Your optimizations worked on 250,468 UPI transactions. Next year the business expects **20× the volume**.

By **Thu 19 Nov 2026**, faculty will release **`large_data.zip`**: the same 9 CSV files with about **20× the rows** (≈ 5,009,000 transactions, ≈ 796,000 rewards, ≈ 800,000 users, ≈ 600,000 bill payments). Until then, work on the design part of the report.

### 5.1 What to do with the large dataset
1. Create a new database. Run **your** `01_schema.sql`, load `large_data/` with your load script (change the folder name only), then run **your** `05_indexes.sql` and `ANALYZE`.
2. Run your **optimized** queries (`sql/06_optimized_queries.sql`). **Do not run the original 30 on the large data.** Some of them could run for a very long time.
   - R23 pages with `OFFSET`; if you replaced it with keyset pagination, explain how the "last seen" value is chosen for the large data.
3. Record the times and compare with your Phase 4 results on the seed data.

| Query | Optimized on seed (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Meets target? | If not, what you changed |
|-------|------------------------:|------------------------:|----------------------:|:-------------:|--------------------------|
| R01 | | | | | |
| … all 30 … | | | | | |

### 5.2 Performance targets on the large dataset
| Query group | Queries | Target (average of 3 runs) |
|-------------|---------|----------------:|
| Real-time / payment path | R01, R02, R03, R04, R10, R12, R22, R24, W01, W02, W03 | **under 5 ms** |
| Interactive merchant and ops tools | R05, R11, R13, R14, R16, R21, R23 | **under 250 ms** |
| Reports, risk and analytics | R06, R07, R08, R09, R15, R17, R18, R19, R20, R25 | **under 5,000 ms** |
| Batch jobs | W04, W05 | **under 1,000 ms** |

If a query misses its target, **find out why from the plan and fix it.** A query that was fast on the seed data can become slow on large data for reasons that only appear at scale. Show the before/after plans for every fix.

### 5.3 Deliverable: `docs/05_scalability_report.md`
1. **Results table** (above), with every target met or explained.
2. **Growth analysis.** Group your queries by how their time grew when the data grew 20×:
   - *stayed about the same* (why? e.g. index lookups grow with log n)
   - *grew about 20×* (why? e.g. they read a fixed *share* of the table)
   - *grew more than 20×* (why, and what you did about it)
3. **What broke at scale** and how you fixed it (plans before/after).
4. **Storage:** total database size, table vs index size, on seed and large data.
5. **Architecture for 100×:** explain with numbers from your own measurements:
   - **Partitioning:** which table, by which column (RANGE / LIST / HASH), and why. Write the DDL for `transactions`, show partition pruning with `EXPLAIN`, and note the primary-key rule for partitioned tables.
   - **Sharding:** Would you shard transactions by payer, by payee/merchant, or by time? A P2P payment touches two users who may live on different shards. Which queries become cross-shard, and how would you handle them?
   - **Read replicas and caching:** which of the 30 queries you would send to a replica or cache, and which must hit the primary.
   - **Maintenance:** VACUUM/autovacuum settings for `transactions`, archiving old data, refreshing summary tables.
6. **Conclusion:** is your database ready for next year? What are the remaining risks?

---

## Repository structure (submit exactly this)

```
googlepay-dbms-<team-no>/
├── README.md                          # team table, how to run, headline numbers
├── team.json                          # group lead, members, enrollment numbers
├── docs/
│   ├── 01_problem_understanding.md
│   ├── 02_schema_design.md
│   ├── 03_baseline_timings.md
│   ├── 04_optimization_report.md
│   └── 05_scalability_report.md
├── diagrams/
│   └── er_diagram.png
├── sql/
│   ├── 01_schema.sql
│   ├── 02_load_data.sql
│   ├── 05_indexes.sql
│   ├── 06_optimized_queries.sql
│   └── 08_partitioning.sql
├── queries/
│   └── workload_30.sql                # given; do not edit
└── benchmarks/
    ├── run_benchmark.sh               # given
    └── results/
        ├── baseline/                  # Phase 3: summary.csv + raw plans
        ├── optimized/                 # Phase 4
        └── large/                     # Phase 5
```

`team.json`:
```json
{
  "team_number": "",
  "group_lead": { "name": "", "enrollment_no": "", "github": "" },
  "members": [
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" }
  ],
  "postgres_version": "",
  "laptop_used_for_benchmarks": ""
}
```

**Do not commit the CSV files** (`seed_data/`, `large_data/`); add them to `.gitignore`. They are too large and we already have them.

---

## Timeline

| Due | Work | Checkpoint |
|-----|------|------------|
| Tue 3 Nov 2026 | Clone this repo into your team's DE repo, add members, commit `team.json` | **CP0** Setup |
| Mon 16 Nov 2026 | Phase 1 + Phase 2 (schema, load, ER, data dictionary) | **CP1** Schema loads all seed data with no errors |
| Tue 17 Nov 2026 | Phase 3 (baseline, 3 runs, average) + start Phase 4 | **CP2** Baseline table for all 30 queries committed |
| Thu 19 Nov 2026 | Phase 4 (indexes, rewrites, wrong-result query) | **CP3** Optimization table committed |
| Mon 23 Nov 2026 | Phase 5 on the large dataset + final report | **CP4 Final submission:** last commit on the default branch |
| Wed 25 – Thu 26 Nov 2026 | Individual analysis, in class time | **CP5** Individual analysis |

Full list of files per checkpoint, including the AP repo: [`CHECKPOINTS.md`](CHECKPOINTS.md).

---

## Evaluation (40 marks)

These 40 marks are the DE part of the project: **Query Execution (10)** and **Code Optimization (30)**.
The AP project (20) and your Individual analysis (40) make up the rest of the 100.

| Phase | Criteria | Marks |
|-------|----------|------:|
| | **Query Execution** | **10** |
| 1 | Problems understood, stakeholders and query groups correctly identified | 2 |
| 2 | Correct data types (1), keys and foreign keys with justified delete rules (1), ≥12 meaningful CHECK / NOT NULL / UNIQUE constraints (1), ER diagram + normal-form analysis (1), data loads cleanly + integrity checks (1) | 5 |
| 3 | All 30 queries measured with the required method: 3 runs, average (1), raw plans committed (1), scan type and reason for each query (1) | 3 |
| | **Code Optimization** | **30** |
| 4 | Speed-up achieved with appropriate techniques (6), every index justified (3), results proven unchanged (2), wrong-result query found and explained (2), write overhead and index storage reported (3) | 16 |
| 5 | Large-dataset results with all targets met or explained (4), growth analysis (3), scale-only problems found and fixed (3), partitioning DDL + sharding/replica design backed by your numbers (4) | 14 |
| | **Total** | **40** |

**Integrity rules**
- Every number in your reports must match the raw plan files in `benchmarks/results/`. Copied or invented timings make the whole phase score 0.
- Every member must have commits; the commit history is checked.
- You may use AI tools to learn, but you must be able to explain every index and rewrite in your individual analysis.

---

## Appendix: the 30 queries

These are identical to `queries/workload_30.sql`. Use the file, not copy-paste from this page.

**R01: Transaction history: everything user 15177 sent or received, newest first**
```sql
SELECT t.txn_id, t.upi_ref, t.payer_vpa, t.payee_vpa, t.amount, t.status, t.initiated_at
FROM transactions t
WHERE t.payer_vpa IN (SELECT vpa FROM vpas WHERE user_id = 15177)
   OR t.payee_vpa IN (SELECT vpa FROM vpas WHERE user_id = 15177)
ORDER BY t.initiated_at DESC
LIMIT 30;
```

**R02: "Pay to UPI ID": check that the entered VPA exists and is active**
```sql
SELECT v.vpa, u.full_name, v.is_active
FROM vpas v
JOIN users u ON u.user_id = v.user_id
WHERE v.vpa = 'aditya.gupta15177@okhdfcbank';
```

**R03: UPI limit check: total successfully sent by user 15177 on 30 June 2026 (limit ₹1,00,000/day)**
```sql
SELECT coalesce(sum(t.amount), 0) AS sent_today
FROM transactions t
JOIN vpas v ON v.vpa = t.payer_vpa
WHERE v.user_id = 15177
  AND t.status IN ('SUCCESS', 'PENDING')
  AND DATE(t.initiated_at) = '2026-06-30';
```

**R04: Reconciliation: payments still PENDING more than 15 minutes after 23:59 on 30 Jun 2026**
```sql
SELECT txn_id, upi_ref, payer_vpa, amount, initiated_at
FROM transactions
WHERE status = 'PENDING'
  AND initiated_at < TIMESTAMPTZ '2026-06-30 23:59:00+05:30' - interval '15 minutes'
ORDER BY initiated_at;
```

**R05: Google Pay for Business: hourly collections of merchant 2 on 29 June 2026**
```sql
SELECT EXTRACT(HOUR FROM initiated_at) AS hour, count(*) AS payments, sum(amount) AS collected
FROM transactions
WHERE merchant_id = 2
  AND status = 'SUCCESS'
  AND initiated_at >= '2026-06-29' AND initiated_at < '2026-06-30'
GROUP BY 1
ORDER BY 1;
```

**R06: Settlement: amount to settle to every merchant for 29 June 2026**
```sql
SELECT m.merchant_id, m.merchant_name, count(*) AS payments, sum(t.amount) AS settle_amount
FROM transactions t
JOIN merchants m ON m.merchant_id = t.merchant_id
WHERE t.status = 'SUCCESS'
  AND t.initiated_at >= '2026-06-29' AND t.initiated_at < '2026-06-30'
GROUP BY m.merchant_id, m.merchant_name
ORDER BY settle_amount DESC;
```

**R07: Bank health: failure codes per payer bank in the last 7 days**
```sql
SELECT ba.bank_name, t.failure_code, count(*) AS failures
FROM transactions t
JOIN vpas v           ON v.vpa = t.payer_vpa
JOIN bank_accounts ba ON ba.account_id = v.account_id
WHERE t.status = 'FAILED'
  AND t.initiated_at >= '2026-06-24'
GROUP BY ba.bank_name, t.failure_code
ORDER BY failures DESC;
```

**R08: Fraud: VPAs that received P2P money from 5+ different people on the same day**
```sql
SELECT payee_vpa, initiated_at::date AS day, count(DISTINCT payer_vpa) AS distinct_payers, sum(amount) AS received
FROM transactions
WHERE txn_type = 'P2P' AND status = 'SUCCESS'
GROUP BY payee_vpa, initiated_at::date
HAVING count(DISTINCT payer_vpa) >= 5
ORDER BY distinct_payers DESC;
```

**R09: Fraud: repeated payments—same payer to the same payee within 10 minutes of the previous one**
```sql
SELECT *
FROM (
    SELECT txn_id, payer_vpa, payee_vpa, amount, initiated_at,
           initiated_at - lag(initiated_at) OVER (PARTITION BY payer_vpa, payee_vpa ORDER BY initiated_at) AS gap
    FROM transactions
    WHERE status = 'SUCCESS'
) t
WHERE gap < interval '10 minutes'
ORDER BY initiated_at DESC;
```

**R10: Rewards tab: user 15177's unscratched cards that have not expired**
```sql
SELECT reward_id, reward_type, issued_at, expires_at
FROM rewards
WHERE user_id = 15177 AND status = 'UNSCRATCHED'
  AND expires_at > '2026-06-30 23:59:00+05:30'
ORDER BY expires_at;
```

**R11: Notification job: unscratched rewards that expire in the first 3 days of July**
```sql
SELECT reward_id, user_id, expires_at
FROM rewards
WHERE status = 'UNSCRATCHED'
  AND expires_at < '2026-07-04'
ORDER BY expires_at;
```

**R12: Bill reminders: user 1072's unpaid bills due in the next 7 days**
```sql
SELECT bill_id, biller_name, amount, due_date
FROM bill_payments
WHERE user_id = 1072 AND status = 'DUE'
  AND due_date BETWEEN '2026-07-01' AND '2026-07-07'
ORDER BY due_date;
```

**R13: Merchant success team: merchants who have never received a payment (to call and help them)**
```sql
SELECT m.merchant_id, m.merchant_name, m.onboarded_on
FROM merchants m
WHERE m.merchant_id NOT IN (SELECT t.merchant_id FROM transactions t);
```

**R14: Spend analysis: user 15177's 2026 spending per merchant category code (MCC)**
```sql
SELECT m.mcc, count(*) AS payments, sum(t.amount) AS spent
FROM transactions t
JOIN merchants m ON m.merchant_id = t.merchant_id
JOIN vpas v      ON v.vpa = t.payer_vpa
WHERE v.user_id = 15177
  AND t.status = 'SUCCESS'
  AND EXTRACT(YEAR FROM t.initiated_at) >= 2025
GROUP BY m.mcc
ORDER BY spent DESC;
```

**R15: Business insights: top 10 merchants by June 2026 GMV in each city**
```sql
SELECT *
FROM (
    SELECT m.city_id, m.merchant_id, m.merchant_name, sum(t.amount) AS gmv,
           RANK() OVER (PARTITION BY m.city_id ORDER BY sum(t.amount) DESC) AS rnk
    FROM transactions t
    JOIN merchants m ON m.merchant_id = t.merchant_id
    WHERE t.status = 'SUCCESS'
      AND t.initiated_at >= '2026-06-01' AND t.initiated_at < '2026-07-01'
    GROUP BY m.city_id, m.merchant_id, m.merchant_name
) r
WHERE rnk <= 10
ORDER BY city_id, rnk;
```

**R16: Disputes desk: disputes open for more than 7 days (SLA breached)**
```sql
SELECT d.dispute_id, d.reason, d.raised_at, t.upi_ref, t.amount
FROM disputes d
JOIN transactions t ON t.txn_id = d.txn_id
WHERE d.status = 'OPEN'
  AND d.raised_at < '2026-06-23'
ORDER BY d.raised_at;
```

**R17: Merchant risk: refund rate per merchant (at least 30 payments)**
```sql
SELECT merchant_id, count(*) AS payments,
       round(100.0 * count(*) FILTER (WHERE status = 'REFUNDED') / count(*), 2) AS refund_pct
FROM transactions
WHERE txn_type = 'P2M'
GROUP BY merchant_id
HAVING count(*) >= 30
ORDER BY refund_pct DESC
LIMIT 20;
```

**R18: Compliance: users without verified KYC who have successfully sent ₹10,000+ in total**
```sql
SELECT u.user_id, u.full_name, u.kyc_status, sum(t.amount) AS total_sent
FROM users u
JOIN vpas v         ON v.user_id = u.user_id
JOIN transactions t ON t.payer_vpa = v.vpa AND t.status = 'SUCCESS'
WHERE u.kyc_status <> 'VERIFIED'
GROUP BY u.user_id, u.full_name, u.kyc_status
HAVING sum(t.amount) >= 10000
ORDER BY total_sent DESC;
```

**R19: Merchant report: last payment time and successful payment count of every verified Bengaluru merchant**
```sql
SELECT m.merchant_id, m.merchant_name,
       (SELECT max(t.initiated_at) FROM transactions t WHERE t.merchant_id = m.merchant_id) AS last_payment_at,
       (SELECT count(*) FROM transactions t WHERE t.merchant_id = m.merchant_id AND t.status = 'SUCCESS') AS successful_payments
FROM merchants m
WHERE m.is_verified AND m.city_id = 1
ORDER BY successful_payments DESC;
```

**R20: Platform health: daily success rate in June 2026**
```sql
SELECT initiated_at::date AS day, count(*) AS payments,
       round(100.0 * count(*) FILTER (WHERE status = 'SUCCESS') / count(*), 2) AS success_pct
FROM transactions
WHERE initiated_at::date BETWEEN '2026-06-01' AND '2026-06-30'
GROUP BY 1
ORDER BY 1;
```

**R21: "Search businesses": merchants with "chai" in their name**
```sql
SELECT merchant_id, merchant_name, merchant_vpa, city_id
FROM merchants
WHERE merchant_name ILIKE '%chai%'
ORDER BY merchant_name
LIMIT 25;
```

**R22: Payment screen: user 15177's primary bank account and all their UPI IDs**
```sql
SELECT ba.bank_name, ba.account_last4, ba.is_primary, v.vpa, v.is_active
FROM bank_accounts ba
LEFT JOIN vpas v ON v.account_id = ba.account_id
WHERE ba.user_id = 15177
ORDER BY ba.is_primary DESC;
```

**R23: Operations console: all transactions, newest first, page 8,001 (25 per page)**
```sql
SELECT txn_id, upi_ref, txn_type, amount, status, initiated_at
FROM transactions
ORDER BY initiated_at DESC
OFFSET 200000
LIMIT 25;
```

**R24: Customer support: find a payment by its UPI reference number**
```sql
SELECT txn_id, payer_vpa, payee_vpa, amount, status, failure_code, initiated_at, completed_at
FROM transactions
WHERE upi_ref = '600977648064';
```

**R25: Bank health: average seconds from initiation to completion per payer bank (June 2026)**
```sql
SELECT ba.bank_name,
       round(avg(EXTRACT(EPOCH FROM (t.completed_at - t.initiated_at))), 2) AS avg_seconds,
       count(*) AS payments
FROM transactions t
JOIN vpas v           ON v.vpa = t.payer_vpa
JOIN bank_accounts ba ON ba.account_id = v.account_id
WHERE t.completed_at IS NOT NULL
  AND t.initiated_at >= '2026-06-01'
GROUP BY ba.bank_name
ORDER BY avg_seconds DESC;
```

**W01: Pay: user 15177 starts a ₹250 payment to merchant 2 (PENDING until the bank confirms)**
```sql
INSERT INTO transactions (txn_id, upi_ref, txn_type, payer_vpa, payee_vpa, merchant_id, amount, initiated_at, status)
VALUES (90000001, '999900000001', 'P2M', 'aditya.gupta15177@okhdfcbank', 'balaji2@okbizaxis', 2, 250.00,
        '2026-07-01 09:00:00+05:30', 'PENDING');
```

**W02: Bank callback: mark the oldest PENDING payment as successful**
```sql
UPDATE transactions
SET status = 'SUCCESS', completed_at = initiated_at + interval '4 seconds'
WHERE txn_id = (SELECT min(txn_id) FROM transactions WHERE status = 'PENDING');
```

**W03: Scratch card: user 15177 scratches their oldest unscratched card**
```sql
UPDATE rewards
SET status = 'CREDITED', credited_at = '2026-07-01 09:05:00+05:30'
WHERE reward_id = (SELECT min(reward_id) FROM rewards WHERE user_id = 15177 AND status = 'UNSCRATCHED');
```

**W04: Nightly job (run at 00:00 on 4 Jul 2026): expire every reward whose time is up**
```sql
UPDATE rewards
SET status = 'EXPIRED'
WHERE status = 'UNSCRATCHED'
  AND expires_at < '2026-07-04 00:00:00+05:30';
```

**W05: Nightly job: bills past their due date and still unpaid become OVERDUE**
```sql
UPDATE bill_payments
SET status = 'OVERDUE'
WHERE status = 'DUE'
  AND due_date < '2026-07-05';
```
