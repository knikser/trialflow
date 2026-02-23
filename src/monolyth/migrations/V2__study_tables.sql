-- Study bounded context: studies table (catalog entry, sponsor_id optional).

CREATE TABLE IF NOT EXISTS study.studies (
    id UUID NOT NULL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    description VARCHAR(4000),
    status VARCHAR(20) NOT NULL,
    sponsor_id UUID,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);
