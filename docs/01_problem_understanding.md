# Phase 1: Problem Understanding

## Google Pay (UPI) Digital Payments Database

### 1. Business Problem

Google Pay handles UPI payments between individuals (P2P) and from customers to merchants (P2M). The database stores users, linked bank accounts, UPI IDs (VPAs), transactions, merchants, rewards, bill payments and disputes. It has no documented schema, and several product teams report slow queries. This phase identifies the affected stakeholders and classifies the workload before we design and optimize the database.

### 2. Problem Statements, Stakeholders and Classification

| ID | Business Requirement | Affected Stakeholders | Queries | Classification |
|---|---|---|---|---|
| P1 | Users need fast access to their transaction history (sent and received) and a quick payment screen that checks UPI IDs and linked bank accounts. | Payer, Payee | R01, R02, R22 | Customer-facing / Real-time |
| P2 | The system must quickly total a user's successful and pending payments for the day to enforce the ₹1,00,000 daily UPI limit on every payment. | Payer, Payments Core, Bank Partner | R03, W01 | Customer-facing / Real-time |
| P3 | Operations must find payments that stay PENDING beyond the expected time and apply delayed bank callbacks, so payment statuses stay accurate. | Reconciliation/Ops, Payer, Payee, Bank Partner | R04, W02 | Real-time (operational) |
| P4 | Merchants need live collections and an accurate daily settlement amount. The success team needs the list of merchants who have never received a payment; it currently comes back empty, which points to a wrong result, not just slowness. | Merchant, Merchant Success Team | R05, R06, R13 | R05: Real-time (interactive). R06, R13: Reporting |
| P5 | Fraud & Risk must detect mule accounts, repeated payments between the same parties and unusually high refund rates in near real time. | Fraud & Risk Team, Payer, Payee, Merchant | R08, R09, R17 | Reporting / Analytics (needs near-real-time freshness) |
| P6 | Users need their reward cards and bill reminders quickly. Scheduled jobs for reward expiry, notifications and overdue bills must finish within the batch window. | Payer, Rewards Team | R10, R12, W03 (user); R11, W04, W05 (jobs) | User queries: Real-time. Nightly jobs: Batch |
| P7 | Compliance needs reports on users with KYC risk. Support needs instant payment lookup by UPI reference and fast dispute queues. | Compliance (RBI/KYC), Customer Support, Payer, Payee | R16, R18, R23, R24 | R24: Real-time. R16, R23: Interactive ops. R18: Reporting |
| P8 | Bank partners and business teams need reliable reports on failure codes, latency, success rates and business insights, and these must keep working when volume grows 20×. | Bank Partner, Payments Team, Analytics Team | R07, R14, R15, R19, R20, R21, R25 | Reporting / Analytics (R21 is an interactive search) |

**Why the classification matters:** it sets the performance targets in later phases. Real-time queries sit in the payment path, so they need millisecond responses (target under 5 ms) and precisely designed indexes. Reporting queries read large parts of the data and can take seconds (target under 5,000 ms), so they suit summary tables or materialized views. Every extra index also slows writes, so we add indexes only where a query needs them.

### 3. Assumptions

1. P2M payments carry a `merchant_id`; P2P payments do not (it is NULL).
2. Both SUCCESS and PENDING payments count toward the daily limit, as R03 does.
3. The "current date" is about 30 June / 1 July 2026, as hard-coded in the queries.
4. A PENDING payment has no completion time; a bank callback later changes its status. The exact status values and the uniqueness of the 12-digit UPI reference will be confirmed from the data in Phase 2.
5. Payment-path queries have priority, because they affect every payment. Reports can tolerate longer runtimes and slightly stale data where live data is not needed.
6. Optimizations must keep each query's results unchanged, unless we find a query that is wrong; in that case we fix it and explain why.
7. Transaction volume will grow about 20× next year.

### 4. Conclusion

The database must support fast transactional operations (history, payment checks, limit checks, callbacks) and efficient analytical workloads (settlement, fraud, compliance, bank health) at 20× volume. These requirements guide the schema design, indexing, query optimization and scalability work in the next phases.
