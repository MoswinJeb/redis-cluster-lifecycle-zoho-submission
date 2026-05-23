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
```

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
* version validation
* data verification baseline

---

## Trigger Controlled Failover

```bash
./redis-tool failover <replica-node>
```

Example:

```bash
./redis-tool failover redis-node-5
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

Performs rolling node upgrade.

---

# Rolling Upgrade Strategy

The rolling upgrade was implemented using a replica-first strategy to maintain cluster availability and avoid downtime.

Upgrade flow:

1. Run pre-flight checks
2. Upgrade replica nodes one at a time
3. Verify cluster health after each replica upgrade
4. Trigger controlled failover to promote upgraded replicas
5. Demote old masters into replicas
6. Upgrade old masters safely
7. Verify cluster topology and data integrity after every step

This strategy ensures:

* zero client-visible downtime
* no slot unavailability
* safe rolling upgrades
* preserved data integrity throughout the process

---

# Assumptions and Trade-offs

* The environment runs inside isolated Docker containers
* Redis nodes communicate over Docker bridge networking
* Redis binaries are installed from source
* Authentication and TLS were not enabled because the environment is intended for local testing and demonstration
* Redis auto-start is configured inside containers using a startup script

Trade-offs:

* Simplicity and reproducibility were prioritized over production-grade hardening
* Shell-based Redis CLI parsing was used instead of structured APIs for faster implementation

---

# Known Limitations

* Cluster topology and data are not persisted across full container rebuilds (`docker compose up --build`) because persistent Docker volumes were not configured
* Redis CLI output parsing is shell-based and may not be as robust as API-driven observability solutions
* Podman runtime was not fully validated, although the compose-based infrastructure can be adapted for Podman Compose

---

# Validation Performed

Successfully validated:

* Redis cluster provisioning
* Cluster topology creation
* Data seeding and verification
* Cluster status reporting
* Rolling upgrades
* Controlled failover
* Replica promotion
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
