# 3. Baseline Query Performance Analysis

## 3.1 Introduction

The objective of this phase is to measure the performance of the Google Pay UPI database before applying query optimizations.

The baseline benchmark establishes the initial execution performance of the database and helps identify queries that require optimization.

The database was tested using PostgreSQL's `EXPLAIN (ANALYZE, BUFFERS)` command, which provides information about query execution time, execution plans, and the scanning methods used by the PostgreSQL query planner.

The benchmark covers all 30 queries provided in `queries/workload_30.sql`, consisting of 25 read queries and 5 write queries.

## 3.2 Benchmark Environment and Methodology

The following environment and configuration were used for the baseline benchmark.

| Parameter | Details |
|---|---|
| Database | `gpay_db` |
| Schema | `gpay` |
| Database System | PostgreSQL 17 |
| Total Queries | 30 |
| Read Queries | 25 (R01–R25) |
| Write Queries | 5 (W01–W05) |
| Executions per Query | 3 |
| Total Executions | 90 |
| Benchmark Command | `./benchmarks/run_benchmark.sh gpay_db baseline 3` |
| Execution Analysis | `EXPLAIN (ANALYZE, BUFFERS)` |

### 3.2.1 Benchmark Procedure

The following procedure was used to measure the baseline performance:

1. The PostgreSQL database was started, and the `gpay` schema was selected.
2. The fixed workload containing 30 SQL queries was executed using the benchmark script.
3. Each query was executed three times to observe variations in execution time.
4. PostgreSQL execution plans were collected using `EXPLAIN (ANALYZE, BUFFERS)`.
5. The execution time of each run was extracted from the execution plan.
6. The average execution time was calculated for every query.
7. The scan types used by PostgreSQL were recorded from the execution plans.

Write queries were executed inside transactions using `BEGIN` and `ROLLBACK`. This ensured that database modifications made during benchmarking were not permanently saved.

### 3.2.2 Average Execution Time Calculation

The average execution time was calculated using the following formula:

**Average Execution Time = (Run 1 + Run 2 + Run 3) / 3**

For example, the average execution time of R01 was calculated as:

(34.540 + 24.248 + 20.746) / 3 = 26.511 ms

The same calculation was performed for all 30 queries.

## 3.3 Baseline Execution Timings

The following table contains the execution times recorded for all 30 queries.

All execution times are measured in milliseconds (ms).

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01 | READ | 34.540 | 24.248 | 20.746 | 26.511 |
| R02 | READ | 0.046 | 0.040 | 0.067 | 0.051 |
| R03 | READ | 19.037 | 17.900 | 15.595 | 17.511 |
| R04 | READ | 10.186 | 10.064 | 9.179 | 9.810 |
| R05 | READ | 8.738 | 8.429 | 7.561 | 8.243 |
| R06 | READ | 8.637 | 8.604 | 7.728 | 8.323 |
| R07 | READ | 8.796 | 8.793 | 8.895 | 8.828 |
| R08 | READ | 368.730 | 360.626 | 367.813 | 365.723 |
| R09 | READ | 898.941 | 905.034 | 932.259 | 912.078 |
| R10 | READ | 2.083 | 2.177 | 2.367 | 2.209 |
| R11 | READ | 2.769 | 3.282 | 3.091 | 3.047 |
| R12 | READ | 2.717 | 2.561 | 2.381 | 2.553 |
| R13 | READ | 41.546 | 31.173 | 25.862 | 32.860 |
| R14 | READ | 18.061 | 17.897 | 18.038 | 17.999 |
| R15 | READ | 10.072 | 9.772 | 9.533 | 9.792 |
| R16 | READ | 0.321 | 0.349 | 0.310 | 0.327 |
| R17 | READ | 14.141 | 13.173 | 12.131 | 13.148 |
| R18 | READ | 25.292 | 24.038 | 24.010 | 24.447 |
| R19 | READ | 4996.416 | 5262.033 | 5194.035 | 5150.828 |
| R20 | READ | 9.497 | 9.093 | 9.445 | 9.345 |
| R21 | READ | 0.885 | 1.011 | 1.200 | 1.032 |
| R22 | READ | 4.384 | 4.907 | 5.161 | 4.817 |
| R23 | READ | 76.573 | 64.998 | 65.164 | 68.912 |
| R24 | READ | 0.038 | 0.040 | 0.037 | 0.038 |
| R25 | READ | 24.690 | 21.031 | 20.185 | 21.969 |
| W01 | WRITE | 0.618 | 0.569 | 0.530 | 0.572 |
| W02 | WRITE | 26.446 | 23.673 | 22.029 | 24.049 |
| W03 | WRITE | 1.703 | 1.800 | 1.675 | 1.726 |
| W04 | WRITE | 2.562 | 2.952 | 2.242 | 2.585 |
| W05 | WRITE | 3.643 | 3.772 | 2.449 | 3.288 |

**Observation:** The execution times show considerable differences between queries. Some queries complete in less than a millisecond, while others require several seconds to execute.

## 3.4 Execution Plan and Scan Type Analysis

PostgreSQL uses different scanning methods to retrieve records from database tables. The query planner selects an execution strategy based on factors such as available indexes, filtering conditions, table statistics, and estimated query costs.

The following scan types were observed during the baseline benchmark.

### 3.4.1 Sequential Scan (Seq Scan)

A Sequential Scan reads records from a table sequentially and evaluates the query conditions against the records.

It is commonly selected when:
- A large portion of the table needs to be processed.
- No suitable index is available for the filtering conditions.
- Scanning the entire table is estimated to be cheaper than using an index.

### 3.4.2 Index Scan

An Index Scan uses an existing index to locate matching records instead of examining every row in the table.

It is commonly selected when:
- The query searches using an indexed column.
- The filtering condition is selective.
- Retrieving matching records through an index is estimated to be more efficient.

### 3.4.3 Scan Types Observed in the Workload

The following table summarizes the scan nodes recorded by the benchmark script.

| Query | Observed Scan Type | Explanation |
|---|---|---|
| R01 | Seq Scan on transactions, Seq Scan on vpas | PostgreSQL scans transactions and VPAs to evaluate the payer and payee conditions. |
| R02 | Index Scan on vpas and users | Indexes are used to locate the VPA and its corresponding user efficiently. |
| R03 | Seq Scan on transactions and vpas | The query filters transactions by user, status and date, requiring PostgreSQL to examine relevant table records. |
| R04 | Seq Scan on transactions | PostgreSQL scans transactions to identify pending payments older than the specified timestamp. |
| R05 | Seq Scan on transactions | Transactions are scanned to filter payments by merchant, status and date before grouping them by hour. |
| R06 | Seq Scan on transactions, Index Scan on merchants | Transactions are scanned for successful payments, while merchant records are retrieved using an index. |
| R07 | Seq Scan on transactions, Index Scan on vpas and bank_accounts | Failed transactions are scanned, and related VPA and bank-account records are retrieved using indexes. |
| R08 | Seq Scan on transactions | The query processes transactions for grouping and distinct payer counting, requiring a large portion of the table. |
| R09 | Seq Scan on transactions | The query processes successful transactions using the `LAG()` window function to identify repeated payments. |
| R10 | Seq Scan on rewards | PostgreSQL scans rewards to find the specified user's unscratched and unexpired cards. |
| R11 | Seq Scan on rewards | The query checks reward status and expiry dates across the rewards table. |
| R12 | Seq Scan on bill_payments | PostgreSQL scans bill payments to find unpaid bills belonging to the specified user within the due-date range. |
| R13 | Seq Scan on merchants and transactions | The `NOT IN` subquery checks which merchants have no corresponding transaction records. |
| R14 | Seq Scan on transactions and vpas, Index Scan on merchants | Transactions and VPAs are scanned for user spending analysis, while merchant records are retrieved using an index. |
| R15 | Seq Scan on transactions and merchants | The query aggregates successful transactions by merchant and city before applying ranking. |
| R16 | Seq Scan on disputes, Index Scan on transactions | Disputes are scanned to find open cases, and matching transactions are retrieved through the transaction primary-key index. |
| R17 | Seq Scan on transactions | PostgreSQL processes P2M transactions to calculate refund percentages grouped by merchant. |
| R18 | Seq Scan on transactions, vpas and users | Multiple tables are scanned and joined to calculate total successful spending for users with unverified KYC. |
| R19 | Seq Scan on merchants and transactions | The correlated subqueries repeatedly retrieve payment information for verified Bengaluru merchants, contributing to the high execution time. |
| R20 | Seq Scan on transactions | Transactions are scanned to calculate daily payment counts and success rates. |
| R21 | Seq Scan on merchants | The leading wildcard in `ILIKE '%chai%'` prevents an ordinary B-tree index from efficiently supporting the name search. |
| R22 | Seq Scan on vpas, Index Scan on bank_accounts | The query retrieves the user's bank accounts and associated VPAs. |
| R23 | Seq Scan on transactions | The query sorts transactions by initiation time and skips 200,000 rows before returning the requested page. |
| R24 | Index Scan on transactions | The unique index on `upi_ref` allows PostgreSQL to find the payment efficiently. |
| R25 | Seq Scan on transactions, vpas and bank_accounts | The query processes transactions and joins VPAs and bank accounts to calculate average completion time per bank. |
| W01 | No Scan | The query inserts a new transaction. No existing-table scan is reported in the captured plan. |
| W02 | Index Scan on transactions | The subquery uses the transaction primary-key index to locate the selected transaction for updating. |
| W03 | Seq Scan and Index Scan on rewards | PostgreSQL searches for the oldest unscratched reward and uses the primary-key index for the update. |
| W04 | Seq Scan on rewards | PostgreSQL scans rewards to find records matching the status and expiry-date conditions. |
| W05 | Seq Scan on bill_payments | PostgreSQL scans bill payments to find records matching the overdue conditions. |

**Note:** The scan types in this table are taken from the benchmark script's recorded scan-node output. The explanations describe the corresponding query conditions and observed access patterns.

## 3.5 Performance Analysis and Observations

The baseline results help identify queries that consume more execution time and may require optimization.

### 3.5.1 Slowest Queries

The five slowest queries based on their average execution time are listed below.

| Rank | Query | Average Execution Time (ms) | Description |
|---|---|---:|---|
| 1 | R19 | 5150.828 | Merchant report using correlated subqueries |
| 2 | R09 | 912.078 | Repeated payment detection using a window function |
| 3 | R08 | 365.723 | Fraud detection using grouping and distinct payer counting |
| 4 | R23 | 68.912 | Transaction pagination using a large OFFSET |
| 5 | R13 | 32.860 | Identifying merchants that have never received payments |

### 3.5.2 Analysis of R19

R19 is the slowest query in the baseline workload, with an average execution time of approximately 5150.828 ms.

The query retrieves the last payment time and successful payment count for every verified merchant located in Bengaluru.

It uses two correlated subqueries:
- One subquery calculates the maximum transaction timestamp for each merchant.
- Another subquery calculates the number of successful transactions for each merchant.

These subqueries repeatedly access the `transactions` table for different merchants, resulting in significant execution time.

This query is a major candidate for optimization in the next phase.

### 3.5.3 Analysis of R09

R09 takes approximately 912.078 ms on average.

It identifies repeated payments made by the same payer to the same payee within ten minutes.

The query uses the `LAG()` window function with `PARTITION BY` and `ORDER BY` to calculate the time difference between consecutive transactions.

Processing and ordering a large number of successful transactions contributes to its execution time.

### 3.5.4 Analysis of R08

R08 takes approximately 365.723 ms on average.

It identifies VPAs receiving money from five or more distinct payers on the same day.

The query groups transactions by payee VPA and transaction date and calculates the number of distinct payers.

The grouping and distinct-count operations require processing a large portion of the transaction table.

### 3.5.5 Analysis of R23

R23 takes approximately 68.912 ms on average.

It retrieves transactions from page 8,001 using:

`OFFSET 200000 LIMIT 25`

PostgreSQL must process and skip a large number of rows before returning the requested records.

Large OFFSET values can therefore increase query execution time.

### 3.5.6 Analysis of R13

R13 takes approximately 32.860 ms on average.

It identifies merchants that have never received a payment using a `NOT IN` subquery.

The query checks merchant records against transaction records, requiring PostgreSQL to examine the relevant data from both tables.

## 3.6 Key Findings

The following findings were identified from the baseline benchmark:

1. R19 has the highest execution time, averaging approximately 5.15 seconds.
2. R09 and R08 are also relatively expensive because they process large numbers of transaction records using window functions, grouping and aggregation.
3. R23 demonstrates the performance cost of using a large OFFSET for pagination.
4. Several queries use Sequential Scans because their conditions require examining a significant portion of the underlying tables or do not have suitable indexes.
5. R02 and R24 perform efficiently because PostgreSQL can use existing indexes to locate the required records.
6. The benchmark provides an initial performance reference for evaluating the effectiveness of future database optimizations.

## 3.7 Benchmark Results and Artifacts

All benchmark outputs are stored in the following directory:

`benchmarks/results/baseline/`

The directory contains the following files:

| File | Description |
|---|---|
| `summary.csv` | Contains average, median, minimum and maximum execution times and scan-node information for all queries. |
| `R01.txt` – `R25.txt` | Contains the raw execution plans for all 25 read queries, including all three runs. |
| `W01.txt` – `W05.txt` | Contains the raw execution plans for all 5 write queries, including all three runs. |

These files provide the detailed execution records used to prepare this report.

## 3.8 Conclusion

The baseline benchmarking phase establishes the initial performance of the Google Pay UPI database before applying any query optimizations.

All 30 queries were executed three times, resulting in 90 benchmark executions. Their execution times, averages and scan types were recorded.

The results identify R19, R09 and R08 as the most time-consuming queries in the workload. They also highlight the use of Sequential Scans across several queries and demonstrate the performance benefits of existing indexes in queries such as R02 and R24.

The collected benchmark results will serve as the reference for evaluating query optimization and indexing improvements in CP3.