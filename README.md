# Redis Cluster Lifecycle Automation

This project provisions, manages, validates, and upgrades a 6-node Redis Cluster using Ansible and Docker Compose.

The environment consists of:

- 3 Redis master nodes
- 3 Redis replica nodes

The project includes:

- Automated Redis provisioning
- Redis Cluster creation
- Deterministic data seeding
- Full cluster verification
- Cluster status reporting
- Controlled failover
- Replica-first rolling upgrades
- Full cluster upgrade validation
- Persistent container startup automation

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
│   │   ├── verify_full.yml
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
Prerequisites

The following tools are required:

Docker Engine or Podman
Docker Compose or Podman Compose
Ansible 2.14+

Validated environment:

Docker Engine
Docker Compose
Ansible 2.16.3
Infrastructure Startup
Start the container infrastructure
cd infra
docker compose up -d
Verify SSH connectivity to all nodes
cd ../ansible
ansible redis -m ping
redis-tool Commands
Provision Redis Cluster
./redis-tool provision --version 7.0.15 --masters 3 --replicas-per-master 1

This command:

installs Redis on all nodes
configures Redis Cluster mode
starts Redis services
creates the Redis Cluster topology
validates final cluster status

The cluster creation step is idempotent and safely skips execution if the cluster is already initialized.

Seed Cluster Data
./redis-tool data seed --keys 1000

This command:

inserts deterministic SHA256-based key/value pairs
distributes keys automatically across cluster masters
prints per-master key distribution summary
Verify Seeded Data
./redis-tool data verify

This command validates deterministic key integrity across the cluster.

Expected output:

PASS — 1000/1000 keys verified

The playbook exits with a non-zero status if validation fails.

Full Cluster Verification
./redis-tool verify --full

This command validates:

cluster_state health
full 16384 slot coverage
replica link health
Redis version consistency
deterministic SHA256 data integrity

Expected output:

FULL VERIFICATION COMPLETE
Cluster Status
./redis-tool status

Displays:

cluster state
master/replica topology
Redis versions
hash slot ownership
memory usage
key distribution
Upgrade Precheck
./redis-tool precheck

Performs:

node reachability validation
cluster health validation
deterministic data verification
Redis version inspection
Controlled Failover
./redis-tool failover <replica-node>

Example:

./redis-tool failover redis-node-6

Promotes the specified replica to master.

Upgrade Individual Node
./redis-tool upgrade-node <node> <ip> <version>

Example:

./redis-tool upgrade-node redis-node-5 10.10.0.15 7.2.6

Performs:

Redis binary upgrade
node restart
cluster health validation
version verification
Rolling Upgrade Strategy

The rolling upgrade was implemented using a replica-first strategy to maintain cluster availability during upgrades.

Upgrade flow:

Execute cluster precheck validation
Upgrade replica nodes individually
Verify cluster health after every upgrade
Trigger controlled failover
Promote upgraded replicas to master
Upgrade remaining replica nodes
Perform full-cluster validation after completion

This strategy ensures:

cluster availability during upgrades
no slot unavailability
deterministic data integrity
controlled topology transitions
safe mixed-version operation during rolling upgrades

The final validated cluster state contains all six nodes running Redis 7.2.6.

Assumptions and Trade-offs

Assumptions:

The environment runs inside isolated Docker containers
Redis nodes communicate through Docker bridge networking
Redis binaries are compiled from source
The environment is intended for operational demonstration and testing

Trade-offs:

Simplicity and reproducibility were prioritized over production-grade hardening
Redis CLI shell parsing was used instead of structured APIs for observability
Cluster topology is currently fixed to 3 masters and 1 replica per master
Rolling upgrades are orchestrated through redis-tool workflows
Known Limitations
Persistent Docker volumes were not configured, so full container rebuilds recreate cluster state
TLS and AUTH were intentionally not configured for local operational testing
Podman support was not fully validated, although the infrastructure is compose-compatible
Cluster topology and upgrade orchestration are currently designed for the fixed 6-node lab environment
Validation Performed

Successfully validated:

Redis cluster provisioning
Cluster topology creation
Deterministic data seeding
Strict SHA256 data verification
Cluster status reporting
Replica-first rolling upgrades
Controlled failover
Replica promotion
Mixed-version cluster operation during upgrade
Full cluster upgrade to Redis 7.2.6
Full cluster verification
Cluster recovery after restart
Persistent container auto-start
Output Files

Execution outputs are available under:

output/

Files include:

provision_output.txt
data_seed_output.txt
status_output.txt
upgrade_output.txt
verify_output.txt
