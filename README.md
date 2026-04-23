# NL-Query: Natural Language Search over Trino with RBAC

Natural language search over federated retail data sources (Postgres + MySQL) using [Trino](https://trino.io/) for distributed queries and [WrenAI](https://getwren.ai/) for NL-to-SQL translation. Includes department-level RBAC — a catalog manager in the Accessories department cannot see items in Electronics.

## Architecture

```
┌──────────────────┐
│   WrenAI UI      │ :3000     ← Ask questions in plain English
└──────┬───────────┘
       │
       ▼
┌──────────────────┐     ┌──────────────┐
│  WrenAI AI Svc   │────▶│   Qdrant     │  (vector store for semantic search)
└──────┬───────────┘     └──────────────┘
       │ Generated SQL
       ▼
┌──────────────────┐
│  WrenAI Engine   │     ← Semantic layer (MDL models, relationships, metrics)
└──────┬───────────┘
       │
       ▼
┌────────────────────────────────────────┐
│          Trino Coordinator             │ :8080
│  ├─ Password-file authentication       │
│  ├─ File-based access control (RBAC)   │
│  │   ├─ Row filters by department      │
│  │   └─ Column masks for PII           │
│  ├─ Catalog: postgres_retail           │
│  └─ Catalog: mysql_inventory           │
└────┬──────────────────┬────────────────┘
     │                  │
     ▼                  ▼
┌─────────┐      ┌──────────┐
│ Postgres│:5432 │  MySQL   │:3306
│ (retail)│      │(inventory)│
└─────────┘      └──────────┘
```

## Quick Start

### Prerequisites

- Docker & Docker Compose v2+
- OpenAI API key (for WrenAI NL-to-SQL)

### 1. Configure environment

```bash
cp .env.example .env
# Edit .env and set your OPENAI_API_KEY
```

### 2. Start the stack

```bash
docker compose up -d
```

This starts 9 services: Postgres, MySQL, Trino, and the full WrenAI stack (bootstrap, engine, ibis-server, qdrant, ai-service, ui).

### 3. Wait for services to be healthy

```bash
docker compose ps
# All services should show "healthy" or "running"
```

### 4. Verify seed data

```bash
./scripts/seed-check.sh
```

### 5. Verify RBAC

```bash
./scripts/verify-rbac.sh
```

### 6. Open WrenAI

Open [http://localhost:3000](http://localhost:3000) and connect to Trino as your data source.

## Test Users

All passwords are `test123`.

| Username | Role | Department | What they see |
|---|---|---|---|
| `accessories_mgr` | Catalog Manager | Accessories | Only accessories products, sales, stock |
| `electronics_mgr` | Catalog Manager | Electronics | Only electronics products, sales, stock |
| `apparel_mgr` | Catalog Manager | Apparel | Only apparel products, sales, stock |
| `home_garden_mgr` | Catalog Manager | Home & Garden | Only home_garden products, sales, stock |
| `merch_analyst` | Analyst | All | All products, sales, stock (PII masked) |
| `data_admin` | Admin | All | Everything, including unmasked PII |

## RBAC Model

### Row Filtering
Department-scoped users only see rows matching their department:
- `accessories_mgr` querying `products` → only rows where `department = 'accessories'`
- Same filtering applies to `sales`, `warehouse_stock`, and `suppliers`

### Column Masking
PII columns in the `customers` table are masked for non-admin users:
- `email` → `'***@***.***'`
- `phone` → `'XXX-XXXX'`
- `address` → `'[REDACTED]'`

### How it works
Trino's [file-based access control](https://trino.io/docs/current/security/file-system-access-control.html) enforces RBAC at the query engine layer. See `trino/etc/rules.json` for the full policy definition.

## Data Model

### Postgres — Retail Database
| Table | Rows | Description |
|---|---|---|
| `departments` | 4 | Department definitions |
| `products` | 40 | Product catalog (10 per department) |
| `customers` | 20 | Customer records with PII |
| `user_department_map` | 12 | RBAC reference mapping |

### MySQL — Inventory Database
| Table | Rows | Description |
|---|---|---|
| `sales` | 100 | Sale transactions (25 per department) |
| `suppliers` | 10 | Product suppliers |
| `warehouse_stock` | 40 | Inventory levels per warehouse |

## WrenAI Semantic Layer

The MDL (Modeling Definition Language) in `wrenai/mdl.json` defines:
- **5 models**: product, customer, sale, supplier, warehouse_stock
- **3 relationships**: sale→product, sale→customer, stock→product
- **Revenue metrics**: total revenue, units sold, transaction count (by department, channel, time)

## Project Structure

```
nl-query/
├── docker-compose.yml          # All 9 services
├── .env.example                # Environment template
├── db/
│   ├── postgres/init.sql       # Retail DB schema + seed data
│   └── mysql/init.sql          # Inventory DB schema + seed data
├── trino/etc/
│   ├── config.properties       # Coordinator config
│   ├── password.db             # User credentials (bcrypt)
│   ├── group.db                # User → group mappings
│   ├── rules.json              # RBAC: row filters + column masks
│   ├── access-control.properties
│   └── catalog/
│       ├── postgres_retail.properties
│       └── mysql_inventory.properties
├── wrenai/
│   ├── config.yaml             # AI service config (LLM + embeddings)
│   ├── mdl.json                # Semantic layer definition
│   └── .env                    # WrenAI environment
├── scripts/
│   ├── verify-rbac.sh          # RBAC test suite
│   └── seed-check.sh           # Data integrity checks
└── PLAN.md                     # Full production runbook
```

## Production Path

This dev environment uses simplified mechanisms suitable for local Docker development. For production, see `PLAN.md` for the full runbook covering:

| Dev (this repo) | Production |
|---|---|
| Trino file-based access control | Apache Ranger (centralized policy mgmt) |
| Password-file auth | Keycloak OIDC + JWT |
| File-based group mapping | LDAP/AD federation |
| Docker Compose | Kubernetes (Helm charts) |
| Synthetic data | Real data sources |

## Troubleshooting

| Issue | Solution |
|---|---|
| Trino can't connect to DBs | Check health: `docker compose ps`. DBs may need 10-15s to initialize. |
| RBAC test fails | Check `trino/etc/rules.json` syntax. Trino logs: `docker logs nlq-trino` |
| WrenAI UI not loading | Ensure `OPENAI_API_KEY` is set. Check: `docker logs nlq-wren-ai` |
| Empty query results | Verify seed data: `./scripts/seed-check.sh` |
| Password auth fails | Password is `test123` for all users. Use bcrypt-compatible hash. |

## License

MIT
