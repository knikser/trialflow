-- Organization bounded context: organizations table.

CREATE TABLE IF NOT EXISTS organization.organizations (
    id UUID NOT NULL PRIMARY KEY,
    name VARCHAR(300) NOT NULL,
    role VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);
