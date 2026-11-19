-- =====================================================================
-- Campus Delivery Matrix (AP Project) — Application SQL Workload (dbms/04_queries.sql)
-- Database: PostgreSQL 15+ (Schema: public)
--   R1–R10 : READ queries  (10) — using JOINs across parcels, students, and users
--   W1–W5  : WRITE queries (5)  — wrapped in BEGIN ... ROLLBACK for safe benchmarking
-- =====================================================================

SET search_path TO public;
BEGIN;

-- @R1
-- READ: Staff authentication login lookup by email
SELECT u.id, u.name, u.email, u."passwordHash", u.role, u."createdAt"
FROM users u
WHERE u.email = 'guard1@campus.edu';

-- @R2
-- READ: Student lookup by enrollment number with pending and total parcel counts (LEFT JOIN)
SELECT s.id, s."enrollmentNo", s.name, s.hostel, s.room, s.phone, s.email,
       count(p.id) AS total_parcels,
       count(p.id) FILTER (WHERE p.status = 'RECEIVED') AS pending_parcels
FROM students s
LEFT JOIN parcels p ON p."studentId" = s.id
WHERE s."enrollmentNo" = 'RU2025CS001'
GROUP BY s.id, s."enrollmentNo", s.name, s.hostel, s.room, s.phone, s.email;

-- @R3
-- READ: Guard gate lookup of a parcel by pickup token (lookupNumber) with student & guard details (JOIN)
SELECT p.id, p."lookupNumber", p.carrier, p."trackingNumber", p.status, p.notes,
       p."createdAt", p."pickedUpAt",
       s."enrollmentNo", s.name AS student_name, s.hostel, s.room, s.phone AS student_phone,
       u.name AS logged_by_guard, u.role AS logged_by_role
FROM parcels p
JOIN students s ON s.id = p."studentId"
JOIN users u    ON u.id = p."loggedById"
WHERE p."lookupNumber" = 'P-101';

-- @R4
-- READ: Live mailroom queue — all uncollected (RECEIVED) parcels with student hostel/room and logging guard (JOIN)
SELECT p.id, p."lookupNumber", p.carrier, p."trackingNumber", p.status, p."createdAt",
       s."enrollmentNo", s.name AS student_name, s.hostel, s.room, s.phone,
       u.name AS guard_name
FROM parcels p
JOIN students s ON s.id = p."studentId"
JOIN users u    ON u.id = p."loggedById"
WHERE p.status = 'RECEIVED'
ORDER BY p."createdAt" ASC
LIMIT 50;


-- @END
ROLLBACK;
