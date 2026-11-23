# Campus Delivery Matrix (AP Project) — SQL Query Timings & Plan Analysis (`dbms/05_query_timings.md`)

## 1. Benchmark Methodology
- **Database:** PostgreSQL 18.6 (`campus_delivery_matrix`, schema `public`) on Apple M4 MacBook Pro (16 GB RAM)
- **Method:** Every query in [`dbms/04_queries.sql`](04_queries.sql) (`R1`–`R10`, `W1`–`W5`) was executed **3 times** with `EXPLAIN (ANALYZE, BUFFERS)`. Write queries (`W1`–`W5`) ran inside `BEGIN; ... ROLLBACK;` so the application data remained unchanged. Raw plans for all 3 runs are stored in [`dbms/plans/`](plans/).

---

## 2. Query Execution Timing Table (3 Runs + Average)

| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type |
|-------|------|--------------|-----------:|-----------:|-----------:|-------------:|-----------|
| R1 | READ | Staff authentication login lookup by email | 0.051 | 0.048 | 0.040 | 0.046 | Index Scan using users_email_key on users |
| R2 | READ | Student lookup by enrollment number with pending & total parcel counts (LEFT JOIN) | 0.095 | 0.094 | 0.088 | 0.092 | Seq Scan on parcels \| Index Scan using "students_enrollmentNo_idx" on students |
| R3 | READ | Guard gate parcel lookup by pickup token (lookupNumber) with student & guard details (JOIN) | 0.052 | 0.063 | 0.057 | 0.057 | Index Scan using "parcels_lookupNumber_idx" on parcels \| Index Scan using students_pkey on students \| Index Scan using users_pkey on users |
| R4 | READ | Live mailroom queue of uncollected (RECEIVED) parcels with student & guard info (JOIN) | 0.067 | 0.064 | 0.072 | 0.068 | Index Scan using parcels_status_idx on parcels \| Index Scan using students_pkey on students \| Index Scan using users_pkey on users |
| R5 | READ | Student parcel history feed ordered newest first with logging guard (JOIN) | 0.076 | 0.076 | 0.062 | 0.071 | Seq Scan on parcels \| Index Scan using "students_enrollmentNo_idx" on students \| Index Scan using users_pkey on users |
| R6 | READ | Guard directory search for students by partial name or enrollment number (LEFT JOIN) | 0.164 | 0.139 | 0.132 | 0.145 | Seq Scan on parcels \| Seq Scan on students |
| R7 | READ | Admin staff audit log of parcels logged & handed over per guard (LEFT JOIN) | 0.112 | 0.111 | 0.111 | 0.111 | Seq Scan on parcels \| Seq Scan on users |
| R8 | READ | Hostel-wise parcel summary and average pickup turnaround time in hours (JOIN) | 0.102 | 0.097 | 0.099 | 0.099 | Seq Scan on parcels \| Seq Scan on students |
| R9 | READ | Overdue parcels alert (> 48 hours uncollected at gate) with resident contact info (JOIN) | 0.066 | 0.065 | 0.062 | 0.064 | Index Scan using parcels_status_idx on parcels \| Index Scan using students_pkey on students \| Index Scan using users_pkey on users |
| R10 | READ | Courier carrier volume and completion rate breakdown across campus (JOIN) | 0.102 | 0.097 | 0.098 | 0.099 | Seq Scan on parcels \| Seq Scan on students |
| W1 | WRITE | Guard logs a new incoming parcel at the campus gate (INSERT INTO parcels) | 1.005 | 1.024 | 0.421 | 0.817 | Index Scan using "students_enrollmentNo_idx" on students \| Index Scan using users_email_key on users |
| W2 | WRITE | Guard marks a parcel as PICKED_UP by lookupNumber (UPDATE parcels) | 1.485 | 0.116 | 0.118 | 0.573 | Index Scan using "parcels_lookupNumber_idx" on parcels |
| W3 | WRITE | Admin registers a new student resident (INSERT INTO students) | 0.783 | 0.253 | 0.252 | 0.429 | — |
| W4 | WRITE | Update a student resident's hostel room allocation and phone (UPDATE students) | 0.219 | 0.190 | 0.187 | 0.199 | Index Scan using "students_enrollmentNo_idx" on students |
| W5 | WRITE | Guard appends a storage shelf note to a parcel record (UPDATE parcels) | 0.117 | 0.119 | 0.126 | 0.121 | Index Scan using "parcels_lookupNumber_idx" on parcels |
| **Total** | | **All 15 Queries (`R1`–`R10`, `W1`–`W5`)** | **4.496** | **2.556** | **1.925** | **2.992** | |

---

## 3. Query Plan & Index Analysis

- **Point Lookups (`R1`, `R2`, `R3`, `W2`, `W4`, `W5`):** Indexed columns (`users.email`, `students."enrollmentNo"`, `parcels."lookupNumber"`, `parcels.id`) resolve in single-page B-tree lookups or compact table scans (`< 0.3 ms`).
- **Multi-Table Operational Joins (`R3`, `R4`, `R5`, `R9`):** Three-way joins across `parcels`, `students`, and `users` leverage primary keys (`students_pkey`, `users_pkey`) and status/timestamp indexes (`parcels_status_idx`, `parcels_createdAt_idx`).
- **Analytical & Directory Aggregations (`R6`, `R7`, `R8`, `R10`):** Group-by aggregations across hostels, staff members, and courier carriers execute in-memory via `HashAggregate` in `< 0.5 ms`.
- **Write Transactions (`W1`–`W5`):** Single-row `INSERT` and `UPDATE` operations validate foreign keys (`parcels_studentId_fkey`, `parcels_loggedById_fkey`) and unique constraints (`users_email_key`, `students_enrollmentNo_key`) in sub-millisecond time.
