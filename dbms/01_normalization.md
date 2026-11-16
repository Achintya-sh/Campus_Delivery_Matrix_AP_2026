# AP Project (`Campus Delivery Matrix`): Database Normalization (`1NF → 2NF → 3NF → BCNF`)

## 1. Domain Overview
**Campus Delivery Matrix** is a campus mailroom and parcel management application where security guards and administrators (`users`) log incoming courier packages (`parcels`) for hostel residents (`students`), generate lookup tokens, and track parcel handoffs (`RECEIVED` → `PICKED_UP`).

---

## 2. Unnormalized Form (UNF) / Raw Campus Parcel Register
Before database normalization, the campus gate register tracked every delivery in a single flat spreadsheet/table `raw_parcel_register`:

| Column | Example Value | Description |
| :--- | :--- | :--- |
| `parcel_id` | `clx9p01...` | Unique parcel record ID |
| `lookup_number` | `CDM-4821` | Short pickup token shown to student |
| `carrier` | `BlueDart, Delhivery` | Courier carrier(s) or multi-part shipment tags |
| `tracking_number` | `BD9928172` | Courier AWB / tracking number |
| `status` | `RECEIVED` | Parcel state (`RECEIVED` or `PICKED_UP`) |
| `notes` | `Fragile box` | Guard remarks |
| `created_at` | `2026-11-01 10:15:00` | Logged timestamp |
| `picked_up_at` | `NULL` | Pickup timestamp |
| `student_id` | `stu_01` | Internal student ID |
| `student_enrollment_no` | `2501010022` | University roll/enrollment number |
| `student_name` | `Achintya Sharma` | Student full name |
| `student_hostel` | `Hostel A` | Student hostel building |
| `student_room` | `304` | Hostel room number |
| `student_phone` | `9876543210` | Student mobile number |
| `student_email` | `achintya.s25022@nst.rishihood.edu.in` | Student email |
| `logged_by_id` | `usr_01` | Guard/Admin user ID |
| `logged_by_name` | `Ramesh Kumar` | Guard full name |
| `logged_by_email` | `ramesh.guard@campus.edu` | Guard login email |
| `logged_by_role` | `GUARD` | Staff role (`GUARD` or `ADMIN`) |

### Anomalies in UNF:
1. **Insertion Anomaly:** Cannot register a new student or a new security guard until a parcel arrives for/by them.
2. **Update Anomaly:** If a student changes their hostel room or phone number, every historical parcel row for that student must be updated or the database becomes inconsistent.
3. **Deletion Anomaly:** Deleting the only parcel row for a student deletes the student's contact and hostel details.

---

## 3. First Normal Form (1NF)

### Rule for 1NF:
- Every attribute must contain **atomic (indivisible)** values (no comma-separated lists or repeating groups), and every row must be uniquely identified by a Primary Key.

### Functional Dependencies in the 1NF Universal Relation $R$:
Let the primary key of a parcel log entry be $\{parcel\_id\}$ (or composite $\{student\_id, created\_at, lookup\_number\}$ when modeled as a composite-key log):
1. $parcel\_id \to lookup\_number, carrier, tracking\_number, status, notes, created\_at, updated\_at, picked\_up\_at, student\_id, logged\_by\_id$
2. $student\_id \to student\_enrollment\_no, student\_name, student\_hostel, student\_room, student\_phone, student\_email, student\_created\_at$
3. $student\_enrollment\_no \to student\_id, student\_name, student\_hostel, student\_room, student\_phone, student\_email$
4. $logged\_by\_id \to logged\_by\_name, logged\_by\_email, logged\_by\_password\_hash, logged\_by\_role, logged\_by\_created\_at, logged\_by\_updated\_at$
5. $logged\_by\_email \to logged\_by\_id, logged\_by\_name, logged\_by\_password\_hash, logged\_by\_role$

### 1NF Table (`parcel_register_1nf`):
```
parcel_register_1nf(
    parcel_id [PK], student_id [PK-part], logged_by_id [PK-part],
    lookup_number, carrier, tracking_number, status, notes, picked_up_at, created_at, updated_at,
    student_enrollment_no, student_name, student_hostel, student_room, student_phone, student_email,
    logged_by_name, logged_by_email, logged_by_password_hash, logged_by_role
)
```
*(When the composite key `(parcel_id, student_id, logged_by_id)` is used to represent the combined participation of a parcel, student, and guard, non-key attributes depend only on part of the composite key — violating 2NF.)*

---

## 4. Second Normal Form (2NF)

### Rule for 2NF:
- Must be in **1NF**, and **no non-prime attribute may have a partial functional dependency** on a proper subset of any candidate key.

### Removing Partial Dependencies:
From the composite relation `(parcel_id, student_id, logged_by_id)`:
- **Partial Dependency 1:** $student\_id \to student\_enrollment\_no, student\_name, hostel, room, phone, email, created\_at$ (depends only on `student_id`).
- **Partial Dependency 2:** $logged\_by\_id \to name, email, password\_hash, role, created\_at, updated\_at$ (depends only on `logged_by_id`).
- **Parcel-specific attributes:** depend on `parcel_id`.

Decomposing into three relations eliminates all partial dependencies:

1. **`users` (2NF):**
   - `users(id [PK], name, email [UNIQUE], passwordHash, role, createdAt, updatedAt)`
   - FDs: $id \to name, email, passwordHash, role, createdAt, updatedAt$; $\quad email \to id, name, passwordHash, role, createdAt, updatedAt$
2. **`students` (2NF):**
   - `students(id [PK], enrollmentNo [UNIQUE], name, hostel, room, phone, email, createdAt)`
   - FDs: $id \to enrollmentNo, name, hostel, room, phone, email, createdAt$; $\quad enrollmentNo \to id, name, hostel, room, phone, email, createdAt$
3. **`parcels_2nf` (2NF):**
   - `parcels_2nf(id [PK], lookupNumber, carrier, trackingNumber, status, notes, studentId [FK], studentEnrollmentNo, loggedById [FK], pickedUpAt, createdAt, updatedAt)`
   - Notice that in the initial Prisma schema (`parcels_2nf`), `parcels` stores both `studentId` and `studentEnrollmentNo`. This creates a **transitive dependency**:
     $$id \to studentId \to studentEnrollmentNo$$
     Because `studentId` is not a candidate key of `parcels`, storing `studentEnrollmentNo` inside `parcels` violates **3NF**!

---

## 5. Third Normal Form (3NF) & Boyce-Codd Normal Form (BCNF)

### Rules for 3NF & BCNF:
- **3NF:** Must be in 2NF, and for every non-trivial FD $X \to Y$, either $X$ is a superkey or $Y$ is a prime attribute (no transitive dependencies of non-key attributes on the primary key).
- **BCNF:** For every non-trivial FD $X \to Y$, **$X$ must be a superkey**.

### Step-by-Step Resolution to 3NF & BCNF:
1. **Eliminating the Transitive Dependency in `parcels` ($id \to studentId \to studentEnrollmentNo$):**
   - In pure 3NF/BCNF, `studentEnrollmentNo` is determined by `studentId` (via `students.id -> students.enrollmentNo`).
   - Removing the redundant `studentEnrollmentNo` from `parcels` (or referencing `students(id)` directly and joining `students` when querying by `enrollmentNo`) leaves `parcels` with only direct dependencies on `parcels.id`:
     $$id \to lookupNumber, carrier, trackingNumber, status, notes, studentId, loggedById, pickedUpAt, createdAt, updatedAt$$
   - *(Implementation note: In our Prisma database, `studentEnrollmentNo` is kept as a denormalized foreign copy linked to `students(enrollmentNo)` for fast barcode scanning at the gate, while in strict 3NF/BCNF `studentId` alone links `parcels` to `students`.)*

### Final 3NF / BCNF Verification of All Tables:

| Table | Candidate Key(s) | Non-Trivial Functional Dependencies | Normal Form | Why It Satisfies 3NF & BCNF |
| :--- | :--- | :--- | :---: | :--- |
| **`users`** | $\{id\}$, $\{email\}$ | $id \to name, email, passwordHash, role, createdAt, updatedAt$<br>$email \to id, name, passwordHash, role, createdAt, updatedAt$ | **BCNF** | Every determinant ($id$ and $email$) is a candidate key. |
| **`students`** | $\{id\}$, $\{enrollmentNo\}$ | $id \to enrollmentNo, name, hostel, room, phone, email, createdAt$<br>$enrollmentNo \to id, name, hostel, room, phone, email, createdAt$ | **BCNF** | Every determinant ($id$ and $enrollmentNo$) is a candidate key. (`hostel` and `room` are independent attributes of the student's residence). |
| **`parcels`** | $\{id\}$, $\{lookupNumber\}$ | $id \to lookupNumber, carrier, trackingNumber, status, notes, studentId, loggedById, pickedUpAt, createdAt, updatedAt$ | **BCNF** | Every attribute depends solely on the parcel key (`id` / `lookupNumber`), with zero partial or transitive dependencies. |
