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

-- @R5
-- READ: Student parcel history feed (all parcels for a student ordered newest first, with logging guard) (JOIN)
SELECT p.id, p."lookupNumber", p.carrier, p."trackingNumber", p.status, p.notes,
       p."createdAt", p."pickedUpAt",
       s.name AS student_name, s."enrollmentNo",
       u.name AS logged_by_name
FROM parcels p
JOIN students s ON s.id = p."studentId"
JOIN users u    ON u.id = p."loggedById"
WHERE s."enrollmentNo" = 'RU2025CS001'
ORDER BY p."createdAt" DESC;

-- @R6
-- READ: Guard search for students by partial name or enrollment number with their awaiting parcel count (LEFT JOIN)
SELECT s.id, s."enrollmentNo", s.name, s.hostel, s.room, s.phone,
       count(p.id) FILTER (WHERE p.status = 'RECEIVED') AS awaiting_pickup
FROM students s
LEFT JOIN parcels p ON p."studentId" = s.id
WHERE s.name ILIKE '%Sharma%' OR s."enrollmentNo" ILIKE '%CS001%'
GROUP BY s.id, s."enrollmentNo", s.name, s.hostel, s.room, s.phone
ORDER BY s.name ASC
LIMIT 20;

-- @R7
-- READ: Admin audit log — parcels logged by each guard/admin with received vs picked-up breakdown (LEFT JOIN)
SELECT u.id AS user_id, u.name AS staff_name, u.email, u.role,
       count(p.id) AS total_logged,
       count(p.id) FILTER (WHERE p.status = 'RECEIVED')  AS currently_holding,
       count(p.id) FILTER (WHERE p.status = 'PICKED_UP') AS handed_over
FROM users u
LEFT JOIN parcels p ON p."loggedById" = u.id
GROUP BY u.id, u.name, u.email, u.role
ORDER BY total_logged DESC;

-- @R8
-- READ: Hostel-wise parcel summary and average pickup turnaround time in hours (JOIN)
SELECT s.hostel,
       count(p.id) AS total_parcels,
       count(p.id) FILTER (WHERE p.status = 'RECEIVED')  AS pending_pickup,
       count(p.id) FILTER (WHERE p.status = 'PICKED_UP') AS completed_pickup,
       round(avg(EXTRACT(EPOCH FROM (p."pickedUpAt" - p."createdAt")) / 3600.0)::numeric, 2) AS avg_pickup_hours
FROM students s
JOIN parcels p ON p."studentId" = s.id
GROUP BY s.hostel
ORDER BY total_parcels DESC;

-- @R9
-- READ: Overdue parcels alert — uncollected parcels waiting at the gate for more than 48 hours (JOIN)
SELECT p.id, p."lookupNumber", p.carrier, p."createdAt",
       s."enrollmentNo", s.name AS student_name, s.hostel, s.room, s.phone, s.email,
       u.name AS logged_by_guard
FROM parcels p
JOIN students s ON s.id = p."studentId"
JOIN users u    ON u.id = p."loggedById"
WHERE p.status = 'RECEIVED'
  AND p."createdAt" < CURRENT_TIMESTAMP - interval '48 hours'
ORDER BY p."createdAt" ASC;

-- @R10
-- READ: Courier carrier volume and completion rate breakdown across campus hostels (JOIN)
SELECT p.carrier,
       count(p.id) AS deliveries,
       count(DISTINCT s.id) AS unique_students,
       count(p.id) FILTER (WHERE p.status = 'PICKED_UP') AS picked_up_count
FROM parcels p
JOIN students s ON s.id = p."studentId"
GROUP BY p.carrier
ORDER BY deliveries DESC;


-- @END
ROLLBACK;
