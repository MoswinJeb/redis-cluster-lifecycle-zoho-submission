# Redis Cluster Lifecycle Tool (Ansible)

CLI tool that wraps Ansible to **provision**, **operate**, and **rolling-upgrade** a 6-node Redis Cluster with zero client-visible downtime and verified data integrity.

The cluster runs as **3 masters + 3 replicas** inside containers (Docker or Podman) that simulate remote servers over SSH. All operations go through `./redis-tool` — no manual SSH or manual `redis-cli` during normal workflows.

---

## Project structure

```text
redis-cluster-lifecycle-zoho-submission/
├── redis-tool                 # Bash CLI entrypoint
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.ini
│   ├── playbooks/
│   │   ├── provision.yml
│   │   ├── create_cluster.yml
│   │   ├── data_seed.yml
│   │   ├── data_verify.yml
│   │   ├── verify_full.yml
│   │   ├── status.yml
│   │   ├── upgrade_precheck.yml
│   │   ├── upgrade_node.yml
│   │   └── failover.yml
│   └── roles/
│       └── redis/
│           ├── tasks/
│           └── templates/
├── infra/
│   ├── Dockerfile             # Ubuntu 22.04 + SSH
│   ├── compose.yml            # 6-node static network
│   ├── startup.sh             # SSH only (Redis installed by Ansible)
│   └── authorized_keys
├── logs/
│   └── operations.log         # Structured command log (stretch S5)
├── output/                    # Captured terminal outputs for submission
└── README.md
```

---

## Prerequisites

Required on the **host** (macOS or Linux):

| Tool | Version |
|------|---------|
| Docker Engine **or** Podman | Either is acceptable; **Podman is preferred** if both are installed |
| Docker Compose **or** Podman Compose | To start the 6-node lab |
| Ansible | **2.14+** (`ansible-playbook` on `PATH`) |

Validated locally with:

- Docker Engine + Docker Compose
- Ansible 2.16.3

### Prerequisite check

Every `redis-tool` command runs a prerequisite check first:

- Detects **Podman** (preferred) or **Docker**
- Verifies **Ansible** is installed and **≥ 2.14**
- Prints checkmarks and versions, then continues
- Exits non-zero with install links if anything is missing

Example:

```text
Checking prerequisites...
✓ Container runtime found: podman
✓ Ansible version found: 2.16.3
```

---

## Infrastructure setup

Containers simulate six servers on a static subnet. **Redis is not pre-installed in the image** — only OpenSSH runs at container start; Ansible installs and configures Redis.

| Container | IP |
|-----------|-----|
| redis-node-1 | 10.10.0.11 |
| redis-node-2 | 10.10.0.12 |
| redis-node-3 | 10.10.0.13 |
| redis-node-4 | 10.10.0.14 |
| redis-node-5 | 10.10.0.15 |
| redis-node-6 | 10.10.0.16 |

### Docker

```bash
cd infra
docker compose up -d --build
```

### Podman

```bash
cd infra
podman-compose up -d --build
# or: podman compose up -d --build
```

### SSH access

Place your public key in `infra/authorized_keys` (must match the private key referenced in `ansible/inventory/hosts.ini`, default `~/.ssh/id_rsa`).

Verify connectivity:

```bash
cd ansible
ansible redis -m ping
```

Make `redis-tool` executable from the project root:

```bash
chmod +x redis-tool
```

---

## `redis-tool` commands

### Phase 1 — Provision cluster

```bash
./redis-tool provision --version 7.0.15 --masters 3 --replicas-per-master 1
```

This command:

1. Installs the specified Redis version on all 6 nodes (built from source)
2. Configures cluster mode (`cluster-enabled`, `cluster-config-file`, `cluster-node-timeout`, bind/port)
3. Starts Redis on each node
4. Forms a 3-master / 3-replica cluster (`--cluster-replicas 1`)
5. Prints **final cluster topology** via `status`

Cluster creation is **idempotent**: if `cluster_state` is already `ok`, creation is skipped.

> **Note:** `--masters` and `--replicas-per-master` must be `3` and `1` respectively (fixed 6-node lab). Only `--version` changes the installed Redis tarball.

---

### Phase 2 — Seed and verify data

**Seed**

```bash
./redis-tool data seed --keys 1000
```

- Inserts deterministic keys `key:0001` … `key:1000`
- Values are **SHA256(key)** (recomputable)
- Keys hash across masters via cluster slots
- Prints total inserted and **per-master key distribution**

**Verify data**

```bash
./redis-tool data verify
```

- Reads all keys, recomputes expected values, compares
- Prints `PASS — 1000/1000 keys verified` or `FAIL — …`
- Exits non-zero on failure (used before/after upgrade)

---

### Phase 3 — Cluster status

```bash
./redis-tool status
```

Example output:

```text
Cluster State: ok
MASTERS
10.10.0.11:6379 [master] v7.0.15 slots: 0-5460 keys: 332 mem: 2.1M
10.10.0.12:6379 [master] v7.0.15 slots: 5461-10922 keys: 341 mem: 2.0M
10.10.0.13:6379 [master] v7.0.15 slots: 10923-16383 keys: 327 mem: 1.9M
REPLICAS
10.10.0.14:6379 [replica] v7.0.15 replicating: 10.10.0.11:6379 mem: 2.1M
10.10.0.15:6379 [replica] v7.0.15 replicating: 10.10.0.12:6379 mem: 2.0M
10.10.0.16:6379 [replica] v7.0.15 replicating: 10.10.0.13:6379 mem: 1.9M
```

---

### Phase 4 — Rolling upgrade (core)

```bash
./redis-tool upgrade --target-version 7.2.6 --strategy rolling
```

End-to-end orchestration with **fail-fast** (`set -e`): any Ansible or sub-command failure stops the upgrade immediately.

**Flow:**

1. **Pre-flight** (`precheck`): reachability, `cluster_state:ok`, SHA256 data verify, version check
2. **Replicas first** (one at a time): upgrade `redis-node-4`, `5`, `6` — health check after each via `upgrade_node.yml`
3. **Master promotion**: for each upgraded replica still in `slave` role, run `CLUSTER FAILOVER` to promote it; skip if already master
4. **Remaining nodes**: upgrade former masters `redis-node-1`, `2`, `3` as replicas
5. **Post-upgrade**: `verify --full`, then `status`
6. Print: `UPGRADE COMPLETE — all nodes upgraded to Redis 7.2.6`

If all nodes already run the target version, upgrade steps are skipped cleanly (idempotent).

**Auxiliary commands** (used internally and for debugging):

```bash
./redis-tool precheck
./redis-tool failover <replica-node>          # e.g. redis-node-5
./redis-tool upgrade-node <node> <ip> <ver>   # e.g. redis-node-5 10.10.0.15 7.2.6
```

#### Rolling upgrade strategy (why)

- **Replica-first** keeps hash slots served by an upgraded or syncing replica while the old master binary is replaced.
- **Controlled failover** moves mastership to an already-upgraded replica before upgrading the old master node, avoiding slot downtime.
- **Per-step health checks** ensure `cluster_state:ok` before continuing.
- **Data verify** before and after guarantees the 1000 deterministic keys survive the process.

This matches the assignment’s zero-downtime goal for a 3+3 lab cluster without external load balancers.

---

### Phase 5 — Full verification

```bash
./redis-tool verify --full
```

Runs `verify_full.yml` and prints pass/fail per category:

| Check | Description |
|-------|-------------|
| Cluster state | `cluster_state:ok` |
| Slot coverage | All **16384** slots assigned |
| Replica health | All replicas `master_link_status:up` |
| Version consistency | Same Redis version on all 6 nodes |
| Data integrity | SHA256 verification of all 1000 keys |

Ends with: `FULL VERIFICATION COMPLETE`

---

## Recommended end-to-end workflow

```bash
# 1. Infrastructure
cd infra && docker compose up -d --build && cd ..

# 2. Provision
./redis-tool provision --version 7.0.15 --masters 3 --replicas-per-master 1

# 3. Data
./redis-tool data seed --keys 1000
./redis-tool data verify
./redis-tool status

# 4. Upgrade
./redis-tool upgrade --target-version 7.2.6 --strategy rolling

# 5. Final check
./redis-tool verify --full
```

Capture terminal output into `output/` for submission if re-running for fresh logs.

---

## Operation logging (stretch S5)

Each `redis-tool` invocation appends to:

```text
logs/operations.log
```

Format: `ISO8601-timestamp | full command | SUCCESS|FAILED`

Failures are recorded via an `ERR` trap before exit.

---

## Submission outputs

Example captures under `output/`:

| File | Contents |
|------|----------|
| `provision_output.txt` | Provision + topology |
| `data_seed_output.txt` | Seed + distribution |
| `status_output.txt` | Pre/post status snapshot |
| `upgrade_output.txt` | Full rolling upgrade run |
| `verify_output.txt` | `verify --full` results |

---

## Assumptions and trade-offs

**Assumptions**

- Fixed 6-node topology (3 masters, 1 replica each)
- Static IPs in `compose.yml` and `hosts.ini`
- Host is the Ansible control node with SSH key access as user `ansible`
- Redis built from official source tarballs
- Lab environment — TLS and AUTH disabled

**Trade-offs**

- Shell/`redis-cli` parsing instead of Redis modules or APIs (simpler, faster to implement)
- Upgrade orchestration assumes initial roles: nodes 4–6 replicas, 1–3 masters (fits default cluster create order)
- `--masters` / `--replicas-per-master` flags validate but only 3/1 is implemented
- No automatic rollback on failed upgrade (stretch S3 not implemented)

---

## Known limitations

- **No persistent volumes** — `docker compose up --build` recreates empty nodes unless cluster data survives in container layer
- **Podman** — Prereq detects Podman; primary validation used Docker Compose
- **Scale out/in** (stretch S1/S2) — not implemented
- **Rollback command** (stretch S3) — not implemented
- **Dynamic cluster sizing** — not supported; 6 nodes only
- **Auto-install prerequisites** (`--auto-install`) — not implemented

---

## Stretch goals status

| Goal | Status |
|------|--------|
| S1 — Scale out | Not implemented |
| S2 — Scale in | Not implemented |
| S3 — Rollback | Not implemented |
| S4 — Idempotency | **Implemented** (provision cluster create, upgrade skip at target version) |
| S5 — Structured logging | **Partial** — `logs/operations.log` with timestamp, command, outcome |

---

## Validation performed

- Redis cluster provisioning (7.0.15 from source)
- Cluster topology creation (3 masters + 3 replicas)
- Deterministic seeding and SHA256 verification
- Cluster status reporting
- Replica-first rolling upgrade to 7.2.6
- Controlled failover and replica promotion
- Full post-upgrade verification (slots, links, versions, data)
- Prerequisite checks on every command

---

## Rules compliance

- Custom Ansible playbooks/roles only (no Ansible Galaxy Redis roles)
- No managed cloud Redis services
- CLI orchestrates Ansible; does not replace it
- Docker and Podman supported at prereq level; compose files work with both compose variants
