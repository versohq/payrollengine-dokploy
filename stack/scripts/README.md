# Payroll Engine — one-click stack

Spawn a blank Payroll Engine instance (Backend API + MySQL with pre-seeded schema) on Dokploy. Regulations are imported **from your local machine** via `PayrollConsole` against the deployed HTTPS API — no secrets inside the stack.

## What's in the stack

| Service | Image | Role |
|---|---|---|
| `mysql` | `mysql:8.0` | Database, auto-seeded from `stack/init/01-Create-Model.mysql.sql` on first boot |
| `backend` | built locally from upstream `Payroll-Engine/PayrollEngine.Backend` via `Dockerfile.backend` | REST API, exposed via Traefik on `${STACK_HOST}` |

Both images are built with `NUGET_SOURCE=nuget.org` only — no GitHub Packages auth needed. See [`Dockerfile.backend`](../Dockerfile.backend) for the `.csproj` version patching.

## Environment variables

See [`.env.example`](./.env.example). Required:

- `STACK_NAME` — used for Traefik router names (must be unique per Dokploy project)
- `STACK_HOST` — public FQDN (e.g. `demo-fr.catapulte.studio`)
- `MYSQL_ROOT_PASSWORD` — DB password
- `PAYROLL_API_KEY` — API key the Backend accepts (`Api-Key` header on all requests)
- `PE_VERSION` / `PE_BACKEND_REF` — NuGet version + git ref the Dockerfile builds against

## Spawn on Dokploy

One-time template bootstrap:
```bash
./stack/scripts/spawn-stack.sh bootstrap
```

Spawn a new instance by duplicating the template (random credentials generated):
```bash
./stack/scripts/spawn-stack.sh spawn demo-fr
```

After ~3 minutes the instance is live at `https://<name>.catapulte.studio`. The script prints the generated `PAYROLL_API_KEY` and a ready-to-copy `PayrollConsole` invocation for the next step.

## Importing a regulation from your local machine

The stack is intentionally **regulation-agnostic**. Once the instance is up, you import a regulation locally with the PayrollConsole CLI:

```bash
cd ~/my-regulation/2026            # contains Setup.pecmd + Regulation/*.json

PayrollApiConnection="BaseUrl=https://demo-fr.catapulte.studio;Port=443;ApiKey=pe_xxxx" \
  PayrollConsole Setup.pecmd
```

The console reads `PayrollApiConnection` from the env, executes every `PayrollImport` in `Setup.pecmd` against the remote backend, and you can immediately `curl -H "Api-Key: pe_xxxx" https://demo-fr.catapulte.studio/api/tenants` to confirm.

**Why local**: the regulation source lives in a private git repo, the PayrollConsole is already on your laptop, and keeping secrets out of Dokploy env is worth the 30-second manual step. No GitHub tokens in compose env, no build-time clone of private repos, no credential rotation.

## Local test

```bash
cd verso-dokploy
cp stack/.env.example .env    # fill in values
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build
curl -H "Api-Key: $PAYROLL_API_KEY" http://localhost:8090/api/tenants
```

## Regenerating the MySQL seed

If the Backend bumps its schema version:
```bash
./stack/scripts/sync-init.sh
```
Copies `PayrollEngine.Backend/Database/Create-Model.mysql.sql` to `stack/init/01-Create-Model.mysql.sql` (self-contained — tables, functions, stored procs).
