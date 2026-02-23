-- Forward-only migration: create schemas for bounded contexts.
-- No down migration.

CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS organization;
CREATE SCHEMA IF NOT EXISTS study;
CREATE SCHEMA IF NOT EXISTS phi;
CREATE SCHEMA IF NOT EXISTS notification;
