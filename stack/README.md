# Payroll Engine — Dokploy stack

Blank Payroll Engine instance (Backend API + MySQL with pre-seeded schema). Regulations are imported **from your local machine** via `PayrollConsole` against the deployed HTTPS API — no secrets inside the stack.

## What's in the stack

| Service | Image | Role |
|---|---|---|
| `mysql` | `mysql:8.0` | Database, auto-seeded from `stack/init/01-Create-Model.mysql.sql` on first boot |
| `backend` | built from upstream `Payroll-Engine/PayrollEngine.Backend` via `Dockerfile.backend` | REST API, exposed via Traefik on `${STACK_HOST}` |

The Dockerfile builds with `NUGET_SOURCE=nuget.org` only — no GitHub Packages auth needed. `.csproj` PackageReferences are rewritten to the pinned version at build time (see [upstream issue #8](https://github.com/Payroll-Engine/PayrollEngine.Backend/issues/8)).

## Spawn an instance (Dokploy UI)

1. **Dashboard → Projects → Create Project** (e.g. `payroll-demo-fr`)
2. In the project, **Create Service → Compose**
3. **General tab**:
   - Provider: **Git**
   - Repository URL: `https://github.com/versohq/payrollengine-deploy`
   - Branch: `main`
   - Compose Path: `./docker-compose.yml`
4. **Environment tab** — paste (replacing values):
   ```
   STACK_NAME=payroll-demo-fr
   STACK_HOST=payroll-demo-fr.catapulte.studio
   MYSQL_ROOT_PASSWORD=<openssl rand -hex 16>
   PAYROLL_API_KEY=pe_<openssl rand -hex 24>
   PE_VERSION=0.10.0-beta.4
   PE_BACKEND_REF=v0.10.0-beta.4
   ```
5. **Deploy** → wait ~3 min (build + MySQL schema init + backend boot)
6. Verify: `curl -H "Api-Key: $PAYROLL_API_KEY" https://payroll-demo-fr.catapulte.studio/api/tenants` → `[]`

### Spawning additional instances

Either repeat the steps above with a different `STACK_NAME`/`STACK_HOST`, or use Dokploy's **Duplicate Project** action on the environment to clone an existing one and override `STACK_NAME`/`STACK_HOST` in the env tab before redeploying.

## Importing a regulation from your local machine

The stack is intentionally **regulation-agnostic**. Once the instance is up, import from your laptop with the PayrollConsole CLI:

```bash
cd ~/my-regulation/2026            # contains Setup.pecmd + Regulation/*.json

PayrollApiConnection="BaseUrl=https://payroll-demo-fr.catapulte.studio;Port=443;ApiKey=pe_xxxx" \
  PayrollConsole Setup.pecmd
```

The console reads `PayrollApiConnection` from the env, executes every `PayrollImport` in `Setup.pecmd` against the remote backend. Verify with `curl -H "Api-Key: pe_xxxx" https://payroll-demo-fr.catapulte.studio/api/tenants`.

**Why local**: the regulation source lives in a private git repo, the PayrollConsole is already on your laptop, and keeping secrets out of Dokploy env is worth the 30-second manual step.

## Local test

```bash
cp stack/.env.example .env    # fill in values
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build
curl -H "Api-Key: $PAYROLL_API_KEY" http://localhost:8090/api/tenants
```

`docker-compose.local.yml` adds the host port binding (Traefik handles routing on Dokploy).

## Regenerating the MySQL seed

If the Backend bumps its schema version:
```bash
./stack/scripts/sync-init.sh
```
Copies `PayrollEngine.Backend/Database/Create-Model.mysql.sql` to `stack/init/01-Create-Model.mysql.sql` (self-contained — tables, functions, stored procs).
