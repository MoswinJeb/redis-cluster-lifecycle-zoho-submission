````markdown
# Redis Cluster Automation using Ansible

This project provisions, manages, monitors, and upgrades a 6-node Redis Cluster using Ansible and Docker Compose.

The cluster consists of:

* 3 Redis master nodes
* 3 Redis replica nodes

The solution includes:

* Automated Redis provisioning
* Cluster creation
* Data seeding and verification
* Cluster status reporting
* Rolling upgrades with controlled failover
* Replica promotion and topology transition
* Persistent Redis auto-start inside containers

---

# Project Structure

```text
submission/
├── redis-tool
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.ini
│   ├── playbooks/
│   │   ├── provision.yml
│   │   ├── create_cluster.yml
│   │   ├── data_seed.yml
│   │   ├── data_verify.yml
│   │   ├── status.yml
│   │   ├── upgrade_precheck.yml
│   │   ├── upgrade_node.yml
│   │   └── failover.yml
│   └── roles/
│       └── redis/
├── infra/
│   ├── Dockerfile
│   ├── compose.yml
│   ├── startup.sh
│   └── authorized_keys
├── output/
└── README.md
````

---

# Prerequisites

The following tools are required:

* Docker Engine or Podman
* Docker Compose or Podman Compose
* Ansible 2.14+

This implementation was validated using Docker Compose.

---

# Infrastructure Startup

## Start container infrastructure

```bash
cd infra
docker compose up -d
```

## Verify SSH connectivity to all nodes

```bash
cd ../ansible

ansible redis -m ping
```

---

# redis-tool Commands

## Provision Redis Cluster

```bash
./redis-tool provision
```

This command:

* installs Redis on all nodes
* configures Redis cluster mode
* starts Redis services
* creates the Redis Cluster topology

The cluster creation step is idempotent and safely skips execution if the cluster is already initialized.

---

## Seed Cluster Data

```bash
./redis-tool seed
```

Seeds 1000 deterministic key-value pairs into the cluster.

---

## Verify Cluster Data

```bash
./redis-tool verify
```

Reads all seeded keys and validates data integrity.

Expected output:

```text
PASS — 1000/1000 keys verified
```

The verification playbook exits with a non-zero status if validation fails.

---

## Check Cluster Status

```bash
./redis-tool status
```

Displays:

* cluster state
* master/replica topology
* Redis versions
* hash slot ownership
* memory usage
* key distribution

---

## Upgrade Precheck

```bash
./redis-tool precheck
```

Performs:

* cluster health validation
* node reachability checks
* Redis version checks
* data verification baseline

---

## Trigger Controlled Failover

```bash
./redis-tool failover <replica-node>
```

Example:

```bash
./redis-tool failover redis-node-6
```

Promotes the specified replica to master.

---

## Upgrade Individual Node

```bash
./redis-tool upgrade-node <node> <ip> <version>
```

Example:

```bash
./redis-tool upgrade-node redis-node-5 10.10.0.15 7.2.6
```

Performs rolling node upgrade with post-upgrade cluster health validation.

---

# Rolling Upgrade Strategy

The rolling upgrade was implemented using a replica-first strategy to maintain cluster availability and avoid downtime.

Upgrade flow:

1. Run pre-flight validation checks
2. Upgrade replica nodes one at a time
3. Verify cluster health after each replica upgrade
4. Trigger controlled failover to promote upgraded replicas
5. Previous masters automatically become replicas
6. Upgrade the remaining replica nodes safely
7. Verify cluster topology and data integrity after every stage

This strategy ensures:

* zero client-visible downtime
* no slot unavailability
* safe rolling upgrades
* preserved data integrity throughout the process

The final validated cluster state contains all six nodes running Redis 7.2.6.

---

# Assumptions and Trade-offs

Assumptions:

* The environment runs inside isolated Docker containers
* Redis nodes communicate over Docker bridge networking
* Redis binaries are installed from source
* The environment is intended for local testing and operational demonstration

Trade-offs:

* Simplicity and reproducibility were prioritized over production-grade hardening
* Redis CLI shell parsing was used instead of structured APIs for faster implementation
* Rolling upgrades are orchestrated through redis-tool commands rather than a single end-to-end automated workflow

---

# Known Limitations

* Cluster topology and data are not persisted across full container rebuilds (`docker compose up --build`) because persistent Docker volumes were not configured
* Redis CLI output parsing is shell-based and may not be as robust as API-driven observability solutions
* TLS and AUTH were intentionally not configured because the environment is designed for local development/testing
* Podman runtime was not fully validated, although the compose-based infrastructure can be adapted for Podman Compose

---

# Validation Performed

Successfully validated:

* Redis cluster provisioning
* Cluster topology creation
* Deterministic data seeding
* Strict data integrity verification
* Cluster status reporting
* Replica-first rolling upgrades
* Controlled failover
* Replica promotion
* Mixed-version cluster operation during upgrade
* Full cluster upgrade to Redis 7.2.6
* Cluster recovery after restart
* Persistent Redis auto-start inside containers

---

# Output Files

Execution outputs are available under:

```text
output/
```

Files include:

* provision_output.txt
* data_seed_output.txt
* status_output.txt
* upgrade_output.txt
* verify_output.txt

```
```
