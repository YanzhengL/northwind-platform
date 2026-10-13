# Runbook: <alert name>

- **Alert:** `<AlertName>` in Alertmanager
- **Severity:** page | ticket
- **Owner:** platform team
- **Dashboard:** <Grafana link>

## What it means
One sentence: which SLO is burning and how fast.

## First 5 minutes
1. Acknowledge in Slack.
2. Open the dashboard; confirm scope (one service, one AZ, everything?).
3. Check recent deploys: Argo CD history for the app.

## Diagnose
- Metrics:
- Logs (Loki query):
- Traces (Tempo):

## Mitigate
- Roll back: `git revert <gitops commit>` and let Argo CD sync.
- Scale:
- Other:

## After
Open a postmortem from `docs/postmortems/_template.md` if the SLO budget burn exceeded 5%.
