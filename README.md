# payrollengine-deploy

Deployable [Payroll Engine](https://github.com/Payroll-Engine/PayrollEngine) stack for Dokploy:

- **MySQL 8.0** — auto-seeded schema from `stack/init/01-Create-Model.mysql.sql`
- **Backend** — ASP.NET Core REST API, built from upstream [`Payroll-Engine/PayrollEngine.Backend`](https://github.com/Payroll-Engine/PayrollEngine.Backend) via [`Dockerfile.backend`](Dockerfile.backend) (patched for nuget.org — no GitHub Packages auth needed, see [upstream issue #8](https://github.com/Payroll-Engine/PayrollEngine.Backend/issues/8))

`Dockerfile.backend` clones upstream PE at build time, so this repo stays small (~200 KB). Regulations are imported **from your local machine** with `PayrollConsole` against the deployed HTTPS API — zero secrets in Dokploy env.

---

## 🚀 Deploy on Dokploy — step by step

### 1. Create the project

- **Dashboard → Projects → Create Project**
- **Name**: `payroll-demo-fr` (or whatever — this becomes the public slug)
- Save

### 2. Add a Compose service

In the new project:

- **Create Service → Compose**
- **Name**: `payroll`
- Save

### 3. General tab — git source

| Field | Value |
|---|---|
| Source Type | `Git` |
| Repository URL | `https://github.com/versohq/payrollengine-deploy` |
| Branch | `main` |
| Build Path | `/` |
| Compose Path | `./docker-compose.yml` |
| Compose Type | `docker-compose` |

Save.

### 4. Environment tab — variables

Paste the block below, replacing `STACK_NAME`, `STACK_HOST`, and the two secrets:

```env
STACK_NAME=payroll-demo-fr
STACK_HOST=payroll-demo-fr.catapulte.studio
MYSQL_ROOT_PASSWORD=<openssl rand -hex 16>
PAYROLL_API_KEY=pe_<openssl rand -hex 24>
PE_VERSION=0.10.0-beta.4
PE_BACKEND_REF=v0.10.0-beta.4
```

Generate the secrets in a terminal:

```bash
echo "MYSQL_ROOT_PASSWORD=$(openssl rand -hex 16)"
echo "PAYROLL_API_KEY=pe_$(openssl rand -hex 24)"
```

⚠️ **Keep the `PAYROLL_API_KEY` value** — you'll need it for every `curl` and for the PayrollConsole.

Save.

### 5. DNS

The hostname `$STACK_HOST` must resolve to the Dokploy server. A wildcard `*.catapulte.studio → <server-ip>` usually covers this — if not, add an A record.

### 6. Deploy

Click **Deploy** (top of the service page). Wait ~3 minutes:

- ~90 s — clone upstream `PayrollEngine.Backend` + `dotnet restore` + `dotnet publish`
- ~15 s — pull `mysql:8.0` + run the 4742-line schema init
- ~10 s — MySQL healthcheck green, backend boot
- ~30 s — Traefik provisions Let's Encrypt certificate

Watch progress in the **Deployments** tab.

### 7. Verify

Once the deployment status is **done**:

```bash
curl -H "Api-Key: pe_xxxx" https://payroll-demo-fr.catapulte.studio/api/tenants
# → []
```

`[]` means backend up + MySQL connected + TLS valid + API key accepted. You can also open `https://$STACK_HOST/swagger` in your browser for the Swagger UI.

### 8. Spawn additional instances

Two ways:

- **Repeat steps 1–6** with a different `STACK_NAME` / `STACK_HOST` — cleanest, each instance is fully independent.
- **Duplicate Project** action in the Dokploy UI on an existing project — clones the compose service with all its env vars, then edit `STACK_NAME` / `STACK_HOST` / the two secrets and redeploy.

---

## 📥 Import a regulation from your local machine

The stack is intentionally **regulation-agnostic**. Once an instance is up, import from your laptop with the PayrollConsole CLI:

```bash
cd ~/my-regulation/2026            # directory containing Setup.pecmd + Regulation/*.json

PayrollApiConnection="BaseUrl=https://payroll-demo-fr.catapulte.studio;Port=443;ApiKey=pe_xxxx" \
  PayrollConsole Setup.pecmd
```

The console reads `PayrollApiConnection` from the env, executes every `PayrollImport` in `Setup.pecmd` against the remote backend. Verify:

```bash
curl -H "Api-Key: pe_xxxx" https://payroll-demo-fr.catapulte.studio/api/tenants
# → [{"identifier":"FR.DirigeantSasu",...}]
```

**Why local**: the regulation source lives in a private git repo, the PayrollConsole is already on your laptop, and keeping secrets out of Dokploy env is worth the 30-second manual step. No GitHub tokens in compose env, no build-time clone of private repos, no credential rotation.

---

## 🧪 Local test (without Dokploy)

```bash
cp stack/.env.example .env            # fill in STACK_NAME, STACK_HOST, secrets
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build
curl -H "Api-Key: $PAYROLL_API_KEY" http://localhost:8090/api/tenants
```

`docker-compose.local.yml` adds the host port binding (`8090:8080`). Traefik handles all external routing on Dokploy, so the main compose file doesn't expose any host port — this is why `docker compose up` alone wouldn't give you direct access.

---

## 🆘 Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Deploy fails with "port 8080 already allocated" | You added a `ports:` directive | Make sure only `docker-compose.yml` is used on Dokploy; `docker-compose.local.yml` is for laptop only |
| `504 Gateway Timeout` on the HTTPS URL | Backend container not attached to `dokploy-network` | Check `docker-compose.yml` still has `networks: [default, dokploy-network]` on the backend service and `dokploy-network: external: true` at the bottom |
| MySQL logs "data directory has files in it" | Corrupted volume from a previous deploy | Dokploy UI → **Advanced → Volumes → delete `mysql-data`**, redeploy |
| Backend crashes with "Version table not found" | Init scripts didn't run (volume wasn't empty on first boot) | Same fix as above — delete the `mysql-data` volume and redeploy |
| `curl` returns `401 Unauthorized` | Wrong `PAYROLL_API_KEY` | Double-check the value in the **Environment** tab matches the one in your `curl -H "Api-Key: ..."` |

---

## 🔧 Required env vars

| Var | Example | Purpose |
|---|---|---|
| `STACK_NAME` | `demo-fr` | Used in Traefik router names (must be unique per Dokploy project) |
| `STACK_HOST` | `demo-fr.catapulte.studio` | Public FQDN |
| `MYSQL_ROOT_PASSWORD` | random | DB root password |
| `PAYROLL_API_KEY` | `pe_<random>` | API key the Backend accepts (`Api-Key` header on all requests) |
| `PE_VERSION` | `0.10.0-beta.4` | PayrollEngine NuGet version the `.csproj` files are pinned to |
| `PE_BACKEND_REF` | `v0.10.0-beta.4` | Git ref cloned by `Dockerfile.backend` |

---

## 🔄 Updating the MySQL seed

If upstream bumps the DB schema:

```bash
curl -sL https://raw.githubusercontent.com/Payroll-Engine/PayrollEngine.Backend/v0.10.0-beta.4/Database/Create-Model.mysql.sql \
  > stack/init/01-Create-Model.mysql.sql
```

Commit and push — next deploy picks it up. MySQL only re-runs init scripts on an empty volume, so existing stacks need their `mysql-data` volume wiped to apply schema changes.

---

## 📚 More

- [`stack/README.md`](stack/README.md) — shorter quick-reference for the stack
- [`DOKPLOY.md`](DOKPLOY.md) — Dokploy-specific operational notes (tRPC API, org isolation, known pitfalls)
