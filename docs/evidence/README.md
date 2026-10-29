# Evidence

Screenshots and recordings captured from real runs. They back up the claims in the README and postmortems.

**Naming:** `YYYY-MM-DD-<what>.png`, e.g. `2026-11-20-drill1-slack-alert.png`.

**Before committing:** blur AWS account IDs, emails, webhook URLs and anything secret.

| File | Shows | Used in |
| --- | --- | --- |
| | | |
| [2026-10-29-scp-region-deny.png](2026-10-29-scp-region-deny.png) | `s3 mb` in us-east-1 from workloads-dev denied by the region-lock SCP; IAM (exempt) still works | [ADR 0021](../adr/0021-deny-list-scps.md) |
| [2026-10-29-cloudtrail-scp-deny-event.png](2026-10-29-cloudtrail-scp-deny-event.png) | The denied CreateBucket recorded by the org trail in S3 | [ADR 0021](../adr/0021-deny-list-scps.md) |
