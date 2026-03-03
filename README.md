# PayrollEngine Deploy

Deployment configuration for [PayrollEngine](https://github.com/Payroll-Engine) on [Dokploy](https://dokploy.com/).

This repo provides a self-contained `docker-compose.yml` that builds directly from the upstream GitHub repositories — no need to clone them locally.

## Services

| Service | Description |
|---|---|
| `db` | SQL Server 2022 (Developer edition) |
| `db-init` | One-shot init container: downloads and runs `ModelCreate.sql` |
| `backend-api` | PayrollEngine Backend API (.NET) — internal only, no exposed port |
| `webapp` | PayrollEngine WebApp (Blazor) — exposed on port 8081 |

## Quick Start (Local Docker)

```bash
cp .env.example .env
# Edit .env to set a strong DB_PASSWORD
docker compose up --build
```

Access the WebApp at `http://localhost:8081`.

## Deploy on Dokploy

### 1. Create a Compose project

- Go to **Projects** > **Create Project**, name it `PayrollEngine`
- Add a **Compose** service
- Source: **GitHub**, repository: `payrollengine-deploy`
- Compose path: `docker-compose.yml`

### 2. Set environment variables

In the Dokploy environment settings, add:

| Variable | Value |
|---|---|
| `DB_PASSWORD` | A strong alphanumeric password |
| `WEBAPP_PORT` | `8081` (or your preferred port) |
| `ASPNETCORE_ENVIRONMENT` | `Production` |

### 3. Configure a domain (optional)

In the webapp service settings, add your domain (e.g. `payroll.example.com`).
Dokploy automatically configures Traefik reverse proxy and Let's Encrypt SSL.

### 4. Deploy

Click **Deploy**. The first build takes a few minutes as Docker clones and builds the upstream repos.

## Redeployment

- **Manual**: Click **Redeploy** in Dokploy to rebuild from latest upstream sources
- **Auto-deploy**: Enable the GitHub webhook in Dokploy for automatic deploys on push
- **Pin a version**: Change `SQL_SOURCE_URL` to point to a specific tag, then redeploy

## Architecture

```
                    ┌─────────────┐
  Browser ──────────►   webapp    │ :8081
                    │  (Blazor)   │
                    └──────┬──────┘
                           │ http://backend-api:8080
                    ┌──────▼──────┐
                    │ backend-api │ (internal)
                    │  (.NET API) │
                    └──────┬──────┘
                           │ SQL
                    ┌──────▼──────┐
                    │     db      │ SQL Server
                    │  (MSSQL)    │
                    └─────────────┘
```

- The backend API is **not exposed externally** — the webapp communicates with it over the internal Docker network
- The `db-init` container runs once at startup to initialize the database schema, then exits
