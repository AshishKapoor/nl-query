# Natural-Language Search over Trino with RBAC — Runbook

**Audience:** platform/data engineers implementing and operating the system.
**Goal:** Give a retail org a chat interface over federated data sources (Postgres, MSSQL, and others already wired into Trino), where every query is subject to row- and column-level access control based on the user's identity and department.

**Core principle:** RBAC is enforced at the Trino layer via Apache Ranger. The LLM sits *above* the security boundary. Nothing the LLM generates can bypass access control, because Trino rewrites every query through Ranger policies before execution.

---

## 0. Architecture recap

```
   ┌──────────────┐      OIDC/JWT      ┌────────────────┐
   │   Chat UI    │ ─────────────────▶ │    Keycloak    │
   └──────┬───────┘                    └────────────────┘
          │ user prompt + JWT                    ▲
          ▼                                      │ group/role lookup
   ┌──────────────────────────┐                  │
   │  NL-to-SQL service       │                  │
   │  (WrenAI or Vanna)       │                  │
   │   ├─ semantic layer      │                  │
   │   ├─ few-shot retriever  │                  │
   │   └─ query validator     │                  │
   └──────┬───────────────────┘                  │
          │ Trino SQL + user identity            │
          ▼                                      │
   ┌──────────────────────────┐                  │
   │  Trino coordinator       │ ◀────────────────┘
   │   └─ Ranger plugin       │  enforces row filter + column mask
   └──────┬───────────────────┘
          │
     ┌────┴──────┬────────────┬──────────┐
     ▼           ▼            ▼          ▼
  Postgres    MSSQL       Iceberg     (others)
```

Everything in this runbook assumes this topology. If you deviate (e.g., put a policy engine other than Ranger, or skip the semantic layer), re-evaluate the steps below.

---

## 1. Prerequisites

| Item | Minimum | Notes |
|---|---|---|
| Kubernetes cluster | 3-node, 16 vCPU / 64 GB each | Dev can use Docker Compose on a single VM |
| Object storage | S3 / MinIO | For Trino spill, Ranger audit (optional) |
| DNS / TLS certs | Yes | Keycloak and Ranger Admin must be HTTPS in any shared environment |
| Source DB credentials | Read-only service accounts on Postgres and MSSQL | Never use production admin creds |
| LLM access | API key for Anthropic / OpenAI, or a self-hosted model endpoint | Budget for token spend; log every call |
| Identity source | AD/LDAP or existing IdP | Will federate into Keycloak |

Before starting, confirm you have:

- [ ] A Kubernetes namespace and `kubectl` access, OR a VM with Docker + Docker Compose.
- [ ] Admin access to the source Postgres and MSSQL instances (to create read-only users).
- [ ] Network path from the Trino cluster to every source DB (test with `nc -zv <host> <port>`).
- [ ] A Git repo for config-as-code (Ranger policies, WrenAI MDL, Trino catalog files). **Everything in this runbook should live in Git.**

---

## 2. Environment layout

Three environments, same topology:

- **dev** — Docker Compose on one VM, synthetic data, permissive policies. Used for prompt engineering and semantic-layer iteration.
- **stage** — Kubernetes, mirrors prod, masked copy of prod data. Used for policy testing and evaluation harness runs.
- **prod** — Kubernetes, real data, strict policies, full audit logging.

**Promotion rule:** no change reaches prod without passing the evaluation harness in stage (see §6.4).

---

## 3. Phase 1 — Security spine (do this first)

> The goal of Phase 1 is to prove, with no LLM involved, that a test user in "accessories" cannot see electronics data even when running raw SQL. If you cannot demonstrate this, do not proceed to Phase 2.

### 3.1 Deploy Keycloak

Purpose: central identity. Issues JWTs that Trino validates. Federates your existing AD/LDAP so you don't maintain a parallel user directory.

**Deploy** (k8s, using the official Bitnami chart or Keycloak Operator):

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install keycloak bitnami/keycloak \
  --namespace identity --create-namespace \
  --set auth.adminUser=admin \
  --set auth.adminPassword='<strong-password>' \
  --set ingress.enabled=true \
  --set ingress.hostname=keycloak.internal.example.com \
  --set ingress.tls=true
```

**Configure:**

1. Create realm `retail`.
2. Create client `trino` (OpenID Connect, confidential, with service account enabled).
3. Federate AD/LDAP under **User Federation** → map `memberOf` to Keycloak groups.
4. Create groups that mirror your org hierarchy:
   - `/retail/catalog_manager/accessories`
   - `/retail/catalog_manager/electronics`
   - `/retail/merch_analyst/all_departments`
   - `/retail/data_admin` (superuser, audit-only)
5. Add a client scope `groups` that includes group membership in the JWT claim (`groups` claim).
6. Export the client config JSON into your Git repo: `identity/keycloak/realm-retail.json`.

**Verification:** Use `curl` to get a token as a test user and decode it — the `groups` claim must contain the correct group path.

```bash
TOKEN=$(curl -s -X POST \
  "https://keycloak.internal.example.com/realms/retail/protocol/openid-connect/token" \
  -d "grant_type=password" -d "client_id=trino" \
  -d "client_secret=<secret>" \
  -d "username=accessories_mgr_test" -d "password=<pwd>" \
  | jq -r .access_token)

echo $TOKEN | cut -d. -f2 | base64 -d | jq .groups
# Expect: ["/retail/catalog_manager/accessories"]
```

### 3.2 Deploy Trino (base, no plugin yet)

Use the official Trino Helm chart. Start minimal, add connectors after the base cluster is healthy.

```bash
helm repo add trino https://trinodb.github.io/charts
helm install trino trino/trino \
  --namespace data --create-namespace \
  --values trino/values.yaml
```

Key `values.yaml` settings (commit to Git):

```yaml
server:
  workers: 3
  coordinator:
    jvm:
      maxHeapSize: "8G"

additionalConfigProperties:
  - http-server.authentication.type=OAUTH2
  - http-server.authentication.oauth2.issuer=https://keycloak.internal.example.com/realms/retail
  - http-server.authentication.oauth2.client-id=trino
  - http-server.authentication.oauth2.client-secret=<from secret>
  - http-server.authentication.oauth2.principal-field=preferred_username
  - http-server.https.enabled=true
```

**Verification:** Open the Trino UI, log in via Keycloak, run `SELECT current_user`. Must return the Keycloak username.

### 3.3 Configure data-source catalogs

Create a catalog config file per source. These live under `/etc/trino/catalog/` in the pod.

**`postgres-retail.properties`:**
```properties
connector.name=postgresql
connection-url=jdbc:postgresql://pg-retail.internal:5432/retail
connection-user=trino_reader
connection-password=${ENV:PG_RETAIL_PASSWORD}
```

**`mssql-inventory.properties`:**
```properties
connector.name=sqlserver
connection-url=jdbc:sqlserver://mssql-inv.internal:1433;database=inventory
connection-user=trino_reader
connection-password=${ENV:MSSQL_INV_PASSWORD}
```

Store passwords in Kubernetes secrets; reference via env. Commit the `.properties` files (without passwords) to Git.

**Verification:** `SHOW CATALOGS` must list both. `SELECT COUNT(*) FROM postgres-retail.public.products` must succeed.

### 3.4 Deploy Apache Ranger Admin

Ranger Admin needs a backing DB (MySQL or Postgres) and Solr for audit storage (or ship audits elsewhere — Elasticsearch or S3-via-Fluentd).

The cleanest path is the Ranger Docker images plus a Helm chart (community chart, e.g., `ranger-k8s`). Minimum components:

- `ranger-admin` — policy UI/API.
- Backing DB — Postgres 14+.
- Solr (or a replacement audit sink).
- `ranger-usersync` — pulls users/groups from LDAP into Ranger.

After Ranger Admin is up:

1. Log in at `https://ranger.internal.example.com` (default creds, rotate immediately).
2. Configure **usersync** to the same AD/LDAP that Keycloak federates. Groups in Ranger must match Keycloak groups.
3. Install the **Trino service definition** (one-time):
   ```bash
   curl -u admin:<pwd> -X POST \
     -H "Content-Type: application/json" \
     -d @ranger-servicedef-trino.json \
     https://ranger.internal.example.com/service/plugins/definitions
   ```
   The service definition JSON is published by the Ranger project (search: "ranger trino service definition"). Commit it to Git.
4. In the Ranger UI, create a service instance named `trino-prod` (or per-env).

### 3.5 Install the Ranger plugin on Trino

The plugin is what actually enforces policies. It runs inside the Trino coordinator as an access-control plugin.

1. Download the Ranger Trino plugin matching your Ranger and Trino versions.
2. Mount the plugin JAR into the Trino coordinator pod under `/usr/lib/trino/plugin/ranger/`.
3. Add `access-control.properties`:
   ```properties
   access-control.name=ranger
   ranger.plugin.service.name=trino-prod
   ranger.plugin.policy.rest.url=https://ranger.internal.example.com
   ranger.plugin.policy.cache.dir=/var/lib/trino/ranger-cache
   ranger.plugin.policy.pollIntervalMs=30000
   ```
4. Restart the coordinator.

**Verification:** coordinator log must contain `RangerAccessControl` initialization without errors. In the Ranger UI under the `trino-prod` service, the plugin must show as "active" with a recent heartbeat.

### 3.6 Define the policy model

This is the step teams skip or rush — don't. Design before clicking.

**Resource hierarchy in Ranger for Trino:**
```
catalog  →  schema  →  table  →  column
```

**Minimum policies for the retail use case:**

1. **Baseline allow:** `data_admin` group → all-access on all catalogs (for ops and debugging). Log every access.
2. **Row filter on `products` table** (in whichever catalog it lives):
   - Groups: `catalog_manager/accessories`
   - Filter expression: `department = 'accessories'`
   - Repeat per department group.
   - **Better pattern for scale:** maintain a `user_department_map` table and filter via `department IN (SELECT dept FROM ref.user_department_map WHERE user_name = current_user)`. One policy, many users.
3. **Column mask on PII columns** (e.g., `customers.phone`, `customers.email`):
   - Mask type: "partial" or "hash" depending on column.
   - Applies to all groups except `data_admin`.
4. **Deny by default:** any catalog/schema not explicitly granted is denied. Ranger supports this with a catch-all deny policy at the bottom.

**Design rules:**
- Prefer fine-grained resource sets over wildcards. Wildcards + multiple matching policies = unpredictable behavior.
- Tag sensitive columns (`PII`, `FINANCE`) and use tag-based policies so new tables inherit protections automatically.
- Every policy must have an owner (a group, not a person) and a review date.

**Commit policies as JSON to Git.** Ranger has export/import APIs — never edit policies only in the UI; always round-trip through Git.

```bash
# Export
curl -u admin:<pwd> \
  "https://ranger.internal.example.com/service/plugins/policies/service/trino-prod" \
  -o ranger/policies/trino-prod.json

# Import (in CI/CD)
curl -u admin:<pwd> -X POST \
  -H "Content-Type: application/json" \
  -d @ranger/policies/trino-prod.json \
  "https://ranger.internal.example.com/service/plugins/policies/importPoliciesFromFile?serviceName=trino-prod&isOverride=true"
```

### 3.7 Phase 1 verification — the critical demo

Run this as the gate before moving to Phase 2. Put it in a script and run it on every deploy.

```bash
# Log in as accessories manager
TOKEN=$(get_token accessories_mgr_test)

# Attempt to read electronics
trino-cli --server https://trino.internal --access-token $TOKEN \
  --execute "SELECT COUNT(*) FROM postgres-retail.public.products WHERE department='electronics'"
# EXPECT: 0  (row filter silently drops electronics rows)

# Attempt to read accessories
trino-cli --server https://trino.internal --access-token $TOKEN \
  --execute "SELECT COUNT(*) FROM postgres-retail.public.products WHERE department='accessories'"
# EXPECT: non-zero, matches known count

# Attempt to see a PII column
trino-cli --server https://trino.internal --access-token $TOKEN \
  --execute "SELECT phone FROM postgres-retail.public.customers LIMIT 5"
# EXPECT: masked values, not raw phone numbers
```

If any of these fail, fix before proceeding. Check: (a) JWT contains correct group, (b) Ranger plugin sees the group, (c) policy priority ordering.

---

## 4. Phase 2 — Semantic layer (WrenAI)

Purpose: give the LLM a stable, business-meaningful view of your schema. Without this, NL accuracy across federated Postgres + MSSQL schemas will sit below 60%.

### 4.1 Deploy WrenAI

WrenAI ships as a set of containers: `wren-ui`, `wren-engine` (the SQL generator), `wren-ai-service` (LLM orchestration), `qdrant` (vector store), and optionally an Ibis server.

```bash
git clone https://github.com/Canner/WrenAI
cd WrenAI/deployment/kustomizations/wren
# edit values: Trino endpoint, LLM provider/key, Qdrant storage class
kubectl apply -k .
```

Point WrenAI at Trino (not directly at Postgres/MSSQL) — this is critical. All queries must flow through Trino so Ranger policies apply.

Trino connection config in WrenAI:
```yaml
data_source:
  type: trino
  host: trino.internal.example.com
  port: 443
  catalog: postgres-retail   # default; queries can cross catalogs
  user: ${WREN_SERVICE_USER}
  # Auth: pass through the end-user's JWT, NOT a service account
```

**Identity propagation — the critical config:**

WrenAI must forward the end user's identity to Trino. Two options:

- **Preferred:** use Trino's `X-Trino-User` header with impersonation, and have WrenAI act as a trusted proxy that Trino permits to impersonate authenticated users. Configure Trino with a user mapping rule that validates the incoming JWT and sets `current_user` accordingly.
- **Simpler (dev):** WrenAI forwards the raw JWT to Trino; Trino validates it via OAUTH2 as in §3.2.

**Never** let WrenAI run queries as a single service account — that would collapse all users into one identity and defeat Ranger.

### 4.2 Define the MDL (Modeling Definition Language)

MDL is WrenAI's semantic layer — YAML that defines models (logical tables), relationships, and metrics.

Start with the 10-20 most-queried entities. Example skeleton:

```yaml
models:
  - name: product
    refSql: SELECT * FROM postgres-retail.public.products
    columns:
      - name: sku
        type: varchar
        isPrimaryKey: true
      - name: name
        type: varchar
      - name: department
        type: varchar
        description: "Department the product belongs to (e.g., accessories, electronics)"
      - name: price
        type: decimal
      - name: launched_at
        type: timestamp
    primaryKey: sku

  - name: sale
    refSql: SELECT * FROM mssql-inventory.dbo.sales
    columns:
      - name: sale_id
        type: bigint
      - name: sku
        type: varchar
      - name: quantity
        type: integer
      - name: sold_at
        type: timestamp

relationships:
  - name: sale_product
    models: [sale, product]
    joinType: many_to_one
    condition: sale.sku = product.sku

metrics:
  - name: revenue
    baseModel: sale
    dimension:
      - name: department
        expression: product.department
    measure:
      - name: total_revenue
        type: decimal
        expression: SUM(sale.quantity * product.price)
    timeGrain:
      - name: sold_at
        refColumn: sale.sold_at
        dateParts: [day, week, month, quarter, year]
```

**MDL authoring rules:**
- Every column gets a `description`. This is what the LLM reads — vague descriptions produce wrong SQL.
- Business synonyms go in descriptions: *"department (also called 'category' or 'vertical')"*.
- Commit MDL to Git. Review changes like code.

### 4.3 Few-shot example library

Curate 30-50 real NL→SQL pairs from actual catalog managers. WrenAI uses these for in-context examples at inference time.

Store in Git: `wrenai/examples/catalog_manager.yaml`:
```yaml
- question: "What were my top 10 best-selling items last month?"
  sql: |
    SELECT p.name, SUM(s.quantity) AS units_sold
    FROM sale s JOIN product p ON s.sku = p.sku
    WHERE s.sold_at >= date_trunc('month', current_date - interval '1' month)
      AND s.sold_at <  date_trunc('month', current_date)
    GROUP BY p.name ORDER BY units_sold DESC LIMIT 10;
```

Note: the example does **not** filter by department. Ranger does that automatically. Never hard-code RBAC into examples.

### 4.4 Phase 2 verification

- Same user as §3.7 asks in natural language: *"What were my top-selling items last month?"*
- WrenAI generates Trino SQL. Trino executes it. Ranger filters to accessories rows.
- Result must contain only accessories products. If electronics appear, stop — identity propagation is broken.

---

## 5. Phase 3 — NL-to-SQL service wiring

Most of the NL-to-SQL logic lives inside WrenAI. This phase is about the guardrails and integration around it.

### 5.1 Query validation pipeline

Every LLM-generated SQL statement must pass this pipeline before Trino executes it:

1. **Parse check** — use `trino-parser` or the Trino `EXPLAIN` statement. If it's not valid SQL, return to the LLM with the error and retry (max 2 retries).
2. **Statement-type allowlist** — only `SELECT` and `EXPLAIN` are permitted. `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `CREATE`, `GRANT`, `REVOKE`, `CALL` are rejected *before* reaching Trino. (Even though Ranger will also deny these, reject early to save cost and give cleaner errors.)
3. **Row-limit injection** — if the query has no `LIMIT`, append `LIMIT 10000`. Tune per use case.
4. **Cost check** — run `EXPLAIN (TYPE IO)` or `EXPLAIN ANALYZE VERBOSE` on a sample, reject if estimated scan > threshold.
5. **Execute** — send to Trino with the user's JWT.

### 5.2 LLM configuration

- Pin model versions. Do not let "latest" drift into production.
- Log every `(user, question, generated_sql, executed_sql, rows_returned, latency_ms)` tuple. This is your evaluation and audit trail.
- Rate-limit per user and per department to contain runaway costs.
- Separate LLM credentials per environment. Dev key can never hit prod.

### 5.3 Prompt hygiene

- The system prompt includes the MDL and few-shot examples — **not** any access-control rules. RBAC is not the LLM's job; repeating it in the prompt is an anti-pattern because it creates a false sense of security and invites prompt injection.
- Never include raw user data in the system prompt. The LLM gets schema only.

---

## 6. Phase 4 — Observability, guardrails, evaluation

### 6.1 Audit logging

Three layers of audit, all shipped to the same log store (Elasticsearch, Loki, or a SIEM):

| Layer | What it logs | Retention |
|---|---|---|
| Keycloak | Logins, token issuance, group membership changes | 1 year |
| Ranger | Every access decision (allow/deny), policy evaluations | 1+ year (compliance) |
| NL-to-SQL service | User question, generated SQL, Trino query ID, row count | 90 days minimum |

Correlate by Trino query ID and user ID.

### 6.2 Metrics to monitor

- **NL-to-SQL accuracy** — from the eval harness (see §6.4), tracked as a time series.
- **Query latency p50/p95/p99** — end-to-end (user prompt → rows returned).
- **Trino queue depth and worker CPU** — standard Trino metrics.
- **Ranger policy evaluation latency** — the plugin exposes JMX metrics.
- **LLM token spend per user per day** — cost control.
- **Rejected queries by category** — parse fail, statement-type fail, cost-cap fail, Ranger deny.

### 6.3 Alerting

- Any Ranger "deny" event for the `data_admin` group (likely misconfiguration).
- Spike in Ranger denies for a single user (possible probing or broken JWT).
- NL accuracy drop > 5 points week-over-week.
- Any DDL/DML statement rejected at the NL-to-SQL layer (should never occur; if it does, a model is misbehaving or a guardrail is bypassed).

### 6.4 Evaluation harness

Build this before go-live. Without it, you have no way to tell if a model change, an MDL edit, or a prompt tweak made things better or worse.

Structure:
```
evals/
  golden_set.yaml         # 100-200 real questions + expected SQL OR expected row set
  run_eval.py             # runs each question through NL-to-SQL as a test user
  scorer.py               # compares results: exact match, row-set match, or LLM-as-judge
  report.md               # latest run's accuracy, per-category breakdown
```

Scoring strategies:
- **Exact SQL match** — too strict, avoid.
- **Result-set match** — run expected SQL and generated SQL, compare row sets. Best for deterministic questions.
- **LLM-as-judge** — for fuzzy questions ("summarize Q3 trends"), use a second LLM call to grade. Use sparingly.

Run the harness in CI on every change to: MDL, few-shot examples, LLM version, guardrails.

---

## 7. Operational runbooks

Standard procedures. Each should be a separate page in your wiki; summarized here.

### 7.1 Onboard a new user

1. Add user to AD/LDAP in the correct department OU.
2. Wait for Keycloak federation sync (usually < 5 min) or trigger manually.
3. Wait for Ranger usersync (next interval, typically 5 min).
4. Smoke test: user logs into chat UI, asks a question, sees only their department's data.

**If user sees nothing:** check group mapping in Keycloak token (§3.1 verification), then check Ranger UI → user exists and has group.

### 7.2 Add a new data source

1. Create read-only DB user on the source. Document credentials in vault.
2. Add a new Trino catalog file (§3.3). Deploy via Helm/GitOps.
3. `SHOW CATALOGS` to confirm visibility.
4. In Ranger, the new catalog appears automatically. Add policies **before** any user queries it. Default to deny-all, then add explicit allows.
5. Update WrenAI MDL with models for the new source.
6. Add few-shot examples that reference the new source.
7. Add eval questions that cover the new source.
8. Run eval harness in stage. Promote to prod only if accuracy holds.

### 7.3 Add or modify a Ranger policy

1. Edit the policy JSON in Git. Open PR.
2. CI runs a policy linter: no wildcards without justification, every policy has an owner, no policy grants `data_admin` outside the allowed set.
3. Merge → CI imports to Ranger **stage**.
4. Eval harness runs against stage with test users for the affected departments.
5. If evals pass, import to prod via the same API (§3.6).
6. Monitor Ranger deny rate for 30 minutes post-deploy.

**Never edit policies directly in the Ranger UI in prod.** Emergency exception: if you must, export immediately afterward and commit to Git, then open a retroactive PR.

### 7.4 Rotate a compromised credential

- **LLM API key:** rotate in secrets manager, restart NL-to-SQL pods. Check logs for usage from unknown sources in the prior 24h.
- **Trino service credentials to source DBs:** rotate on the source DB, update Kubernetes secret, restart Trino workers (rolling). Queries in flight will fail; users retry.
- **Keycloak client secret for Trino:** rotate in Keycloak, update Trino config, restart coordinator. User sessions persist (JWTs don't need re-issuance) but any component using client-credentials flow reconnects.

### 7.5 "User says they can't see data they should see"

Diagnosis flow:

1. Get the Trino query ID from the NL-to-SQL log.
2. In Ranger audit UI, find the decision for that query ID.
   - **Denied:** which policy caused it? Is the user in the expected group?
   - **Allowed but empty:** row filter is working but filtering too aggressively. Check the filter expression against the user's group.
3. Check the JWT: decode and confirm `groups` claim matches what Ranger expects.
4. Check usersync freshness: when did Ranger last pull from LDAP?
5. If none of the above: reproduce with raw SQL (bypass NL layer) to isolate whether the problem is in NL-to-SQL translation or in access control.

### 7.6 "User sees data they should NOT see" (security incident)

Treat as a P1 incident.

1. Immediately disable the user's access (Keycloak: disable user).
2. Capture the Trino query ID and full Ranger audit entry.
3. Review the responsible policy. Most common causes:
   - Wildcard policy overriding a deny.
   - User accidentally in the wrong group.
   - Recent policy change not yet rolled to prod (stale cache — check `ranger.plugin.policy.pollIntervalMs`).
4. Fix the policy or group membership.
5. Post-mortem: add an eval-harness case that covers this scenario so it can't regress.

---

## 8. Go-live checklist

Use this as the final gate before opening the system to real users.

- [ ] All three Phase 1 verification queries (§3.7) pass for at least 3 distinct department-scoped test users.
- [ ] Ranger policies exported to Git; CI can round-trip import without diff.
- [ ] WrenAI MDL covers all entities expected in the go-live scope; every column has a description.
- [ ] Few-shot library has ≥ 30 curated examples; none hard-code RBAC.
- [ ] NL-to-SQL guardrails (§5.1) unit-tested for each rejection category.
- [ ] Audit log pipeline delivering Keycloak + Ranger + NL-to-SQL events to the central store, queryable by user and by query ID.
- [ ] Eval harness baseline ≥ 75% accuracy on golden set in stage.
- [ ] Runbook §7.1 through §7.6 walked through with the on-call team.
- [ ] Credential rotation rehearsed in stage.
- [ ] Load test: 50 concurrent users, p95 latency ≤ 8s end-to-end.
- [ ] Rollback plan documented: a single kill switch (LB rule) that removes the chat UI while leaving Trino + Ranger untouched.

---

## 9. Troubleshooting matrix

| Symptom | Likely cause | Where to look |
|---|---|---|
| User logs in, Trino returns `Access Denied` | Ranger policy missing or JWT group mapping wrong | Ranger audit UI → decode JWT |
| Empty result where data expected | Row filter too restrictive, or identity collapsed to service account | Ranger audit UI; WrenAI → Trino auth config |
| LLM generates invalid SQL | MDL column descriptions vague, or schema drift | Test the same question in WrenAI UI directly; check MDL |
| PII column appears unmasked | Mask policy not applied to this group, or column not tagged | Ranger → column-level policies; tag assignments |
| Queries slow only for some users | Row filter requires expensive subquery (e.g., `user_department_map` lookup) | Materialize the mapping table; add index on source |
| Trino rejects all authenticated requests after restart | OAUTH2 config mismatch, clock skew | Trino coordinator logs; verify issuer URL exactly matches |
| Ranger plugin shows inactive in UI | Plugin can't reach Ranger Admin, or service name mismatch | Coordinator logs for `RangerAdminClient`; `access-control.properties` |
| Policies take too long to apply | Cache interval too high | `ranger.plugin.policy.pollIntervalMs` (default 30s, can lower to 10s for stage) |
| LLM cost spiking | A few users asking open-ended questions repeatedly | Per-user token metrics; add caching on (user, question_hash) |
| Eval accuracy drops after MDL edit | Description change changed LLM's interpretation | Git diff the MDL; revert specific column |

---

## 10. References

- Trino documentation — access control and OAuth 2.0.
- Apache Ranger — row-level filtering, column masking, Trino service definition.
- WrenAI documentation — MDL spec, Trino connector, deployment.
- Keycloak — OIDC client config, LDAP federation, group mappers.

---

*Last updated: keep this line current in Git. Owner: the platform/data engineering team. Review cadence: quarterly, or after any Phase-level change.*
