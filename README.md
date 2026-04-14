# payrollengine-deploy

Deployable Payroll Engine stack for Dokploy:

- **MySQL 8.0** — auto-seeded schema from `stack/init/01-Create-Model.mysql.sql`
- **Backend** — ASP.NET Core REST API, built from [Payroll-Engine/PayrollEngine.Backend](https://github.com/Payroll-Engine/PayrollEngine.Backend) with `Dockerfile.backend` (patched for nuget.org, no GitHub Packages auth — see [upstream issue #8](https://github.com/Payroll-Engine/PayrollEngine.Backend/issues/8))

`Dockerfile.backend` clones upstream Payroll Engine at build time — this repo stays small (~200 KB).

**Regulations are imported from your local machine**, not bundled in the stack. See [`stack/README.md`](stack/README.md) for the full Dokploy UI walkthrough and the `PayrollConsole` import workflow.

## Quick start

1. On Dokploy: Create Project → Compose service → Git provider → `https://github.com/versohq/payrollengine-deploy` → Deploy
2. Paste env vars (`STACK_NAME`, `STACK_HOST`, `MYSQL_ROOT_PASSWORD`, `PAYROLL_API_KEY`, `PE_VERSION`, `PE_BACKEND_REF`)
3. Locally: `PayrollApiConnection="BaseUrl=https://$STACK_HOST;Port=443;ApiKey=$PAYROLL_API_KEY" PayrollConsole Setup.pecmd`

## Local test

```bash
cp stack/.env.example .env    # fill in values
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build
curl -H "Api-Key: $PAYROLL_API_KEY" http://localhost:8090/api/tenants
```

## Operational docs

- [`stack/README.md`](stack/README.md) — full Dokploy UI walkthrough, env vars reference, regulation import
- [`DOKPLOY.md`](DOKPLOY.md) — Dokploy tRPC notes and known pitfalls
