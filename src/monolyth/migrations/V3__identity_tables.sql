-- Identity bounded context: accounts table.

CREATE TABLE IF NOT EXISTS identity.accounts (
    id UUID NOT NULL PRIMARY KEY,
    email VARCHAR(320) NOT NULL,
    password_hash VARCHAR(500) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_accounts_email ON identity.accounts (email);
