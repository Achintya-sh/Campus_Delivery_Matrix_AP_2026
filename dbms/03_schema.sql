-- =====================================================================
-- Campus Delivery Matrix (AP Project) — PostgreSQL Schema (dbms/03_schema.sql)
-- Runs cleanly on PostgreSQL 15+
-- =====================================================================

DROP TABLE IF EXISTS parcels CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TYPE IF EXISTS "ParcelStatus" CASCADE;
DROP TYPE IF EXISTS "Role" CASCADE;

-- 1. Domain Enumerations
CREATE TYPE "Role" AS ENUM ('GUARD', 'ADMIN');
CREATE TYPE "ParcelStatus" AS ENUM ('RECEIVED', 'PICKED_UP');

-- 2. users: Security guards and administrators who manage campus parcels
CREATE TABLE users (
    id             TEXT          PRIMARY KEY,
    name           VARCHAR(100)  NOT NULL,
    email          VARCHAR(120)  NOT NULL UNIQUE,
    "passwordHash" TEXT          NOT NULL,
    role           "Role"        NOT NULL DEFAULT 'GUARD',
    "createdAt"    TIMESTAMP(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"    TIMESTAMP(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_users_email CHECK (email LIKE '%_@_%.__%')
);

-- 3. students: Campus residents who receive parcels
CREATE TABLE students (
    id             TEXT          PRIMARY KEY,
    "enrollmentNo" VARCHAR(30)   NOT NULL UNIQUE,
    name           VARCHAR(100)  NOT NULL,
    hostel         VARCHAR(60),
    room           VARCHAR(20),
    phone          VARCHAR(15),
    email          VARCHAR(120)  UNIQUE,
    "createdAt"    TIMESTAMP(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_students_phone CHECK (phone IS NULL OR phone ~ '^[0-9+\-() ]{7,15}$')
);

-- 4. parcels: Incoming courier packages logged at the campus gate
CREATE TABLE parcels (
    id                    TEXT           PRIMARY KEY,
    "lookupNumber"        VARCHAR(30)    NOT NULL UNIQUE,
    carrier               VARCHAR(60)    NOT NULL,
    "trackingNumber"      VARCHAR(80),
    status                "ParcelStatus" NOT NULL DEFAULT 'RECEIVED',
    notes                 TEXT,
    "studentId"           TEXT           NOT NULL REFERENCES students(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    "studentEnrollmentNo" VARCHAR(30)    NOT NULL REFERENCES students("enrollmentNo") ON UPDATE CASCADE ON DELETE RESTRICT,
    "loggedById"          TEXT           NOT NULL REFERENCES users(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    "pickedUpAt"          TIMESTAMP(3),
    "createdAt"           TIMESTAMP(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"           TIMESTAMP(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_parcels_pickup_status CHECK (
        (status = 'RECEIVED' AND "pickedUpAt" IS NULL) OR
        (status = 'PICKED_UP' AND "pickedUpAt" IS NOT NULL AND "pickedUpAt" >= "createdAt")
    )
);

-- Indexes for operational queries
CREATE INDEX "parcels_createdAt_idx"           ON parcels ("createdAt");
CREATE INDEX "parcels_lookupNumber_idx"        ON parcels ("lookupNumber");
CREATE INDEX "parcels_status_idx"              ON parcels (status);
CREATE INDEX "parcels_studentEnrollmentNo_idx" ON parcels ("studentEnrollmentNo");
CREATE INDEX "students_enrollmentNo_idx"       ON students ("enrollmentNo");
CREATE INDEX "students_name_idx"               ON students (name);
