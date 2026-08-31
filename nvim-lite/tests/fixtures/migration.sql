-- Restore-time checks, the kind you paste into psql over SSH
BEGIN;

CREATE TABLE IF NOT EXISTS payment_attempt (
    id            BIGSERIAL PRIMARY KEY,
    external_id   VARCHAR(64) NOT NULL,
    amount        NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    status        TEXT NOT NULL DEFAULT 'PENDING',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_payment_external UNIQUE (external_id)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_created
    ON payment_attempt (created_at DESC)
    WHERE status <> 'SETTLED';

WITH stale AS (
    SELECT id FROM payment_attempt
    WHERE status = 'PENDING' AND created_at < now() - INTERVAL '7 days'
)
UPDATE payment_attempt SET status = 'EXPIRED'
WHERE id IN (SELECT id FROM stale);

COMMIT;
