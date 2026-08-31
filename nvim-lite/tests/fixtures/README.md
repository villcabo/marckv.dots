# Runbook

Restore procedure for the payment gateway.

## Steps

1. Stop the consumer: `dcdown paymentms`
2. Restore the dump:

   ```bash
   gunzip -c backup.sql.gz | psql -U postgres gpgw
   ```

3. Bring it back with `dcup -r paymentms`

> **Careful:** step 2 is not reversible.

| Service | Port |
|---|---|
| gateway | 8080 |
