# 🔐 GCP Database Private Access and Connectivity

> A comprehensive field guide for designing, securing, and operating private connectivity to Google Cloud database services from Google Cloud, hybrid, and on-premises environments.

This document focuses on **how to reach GCP databases privately and securely**. It complements broader service overviews in the repository and is designed as both a learning guide and an implementation runbook.

## 📚 Table of Contents

1. [GCP Database Services Overview](#gcp-database-services-overview)
2. [Setting Up Cloud SQL (Basic to Advanced)](#setting-up-cloud-sql-basic-to-advanced)
3. [Private IP Access for Cloud SQL](#private-ip-access-for-cloud-sql)
4. [Private Service Connect](#private-service-connect)
5. [Connecting from On-Premises](#connecting-from-on-premises)
6. [Cloud SQL Auth Proxy Deep Dive](#cloud-sql-auth-proxy-deep-dive)
7. [Spanner & AlloyDB](#spanner-alloydb)
8. [Firestore & Bigtable Access](#firestore-bigtable-access)
9. [Database Security](#database-security)
10. [Database Troubleshooting](#database-troubleshooting)
11. [Reference Architectures, Scenarios, and Checklists](#reference-architectures-scenarios-and-checklists)
12. [Appendix: Command Catalog and Glossary](#appendix:-command-catalog-and-glossary)

## 1. 🗂️ GCP Database Services Overview

Google Cloud offers multiple managed database products because no single database is ideal for every workload. The best architecture starts with a clear decision about **data model**, **latency**, **consistency**, **scaling**, **connectivity**, and **operational ownership**.

### Core decision lenses
- Need for relational SQL features such as joins, stored procedures, and schema migration control.
- Need for horizontal write scale, global distribution, or strict low-latency access across regions.
- Need for serverless application development versus platform-managed database administration.
- Need for private IP-only connectivity versus internet-facing access with strong identity controls.
- Need for caching, operational data, document data, analytics, or globally distributed transactions.
- Need for compatibility with an existing engine such as MySQL, PostgreSQL, SQL Server, Redis, or Hadoop-compatible clients.

### Service comparison table
| Service | Primary model | Typical use cases | Connectivity model | Private access highlights | Strengths | Trade-offs |
|---|---|---|---|---|---|---|
| Cloud SQL | Managed relational (MySQL, PostgreSQL, SQL Server) | Traditional OLTP, web apps, ERP side systems | Private IP, public IP, Auth Proxy, connectors | Private Services Access, PSC, VPC-native access | Familiar engines, backups, HA, read replicas | Vertical scale ceilings compared with distributed systems |
| Cloud Spanner | Distributed relational SQL | Global transactional systems, SaaS control planes | Google APIs path, Private Google Access, PSC for Google APIs | Private reach to Google APIs, VPC SC, IAM | Horizontal scale, strong consistency, multi-region | Schema and cost model differ from classic RDBMS |
| Firestore | Document database | Mobile/web apps, event-driven APIs | Google APIs path, client SDKs, server libraries | Private Google Access or PSC for Google APIs from private workloads | Realtime sync, offline support, serverless | Limited relational querying semantics |
| Bigtable | Wide-column NoSQL | Time-series, IoT, ad tech, high-throughput key lookups | Google APIs path, cbt, client libraries | Private Google Access or PSC for Google APIs | Massive scale and low-latency key access | Querying is key-design driven |
| AlloyDB | PostgreSQL-compatible managed relational | High-performance PostgreSQL workloads, transactional plus analytics | Private IP within VPC, PSC patterns | VPC-native private endpoints, read pools, PSC options | High throughput, PostgreSQL compatibility | Smaller ecosystem than Cloud SQL for legacy engine variety |
| Memorystore | Managed Redis / Memcached | Caching, sessions, queues, leaderboards | Private service access in VPC | Private-only access by design, PSC for some patterns | Fast cache semantics, managed ops | Not a system of record |
| BigQuery | Analytical data warehouse | BI, ELT, ML, lakehouse analytics | Google APIs path, SQL clients, connectors | Private Google Access, PSC for Google APIs, VPC SC | Serverless analytics at scale | Not for OLTP transaction processing |

```mermaid
flowchart TD
    A[Workload requirement] --> B{Primary pattern?}
    B -->|Relational OLTP| C{Scale + compatibility?}
    B -->|Document / mobile sync| D[Firestore]
    B -->|Wide-column / time-series| E[Bigtable]
    B -->|Caching / ephemeral state| F[Memorystore]
    B -->|Analytics / BI| G[BigQuery]
    C -->|MySQL / PostgreSQL / SQL Server| H[Cloud SQL]
    C -->|PostgreSQL compatibility + higher throughput| I[AlloyDB]
    C -->|Global consistency + horizontal scale| J[Cloud Spanner]
    H --> K[Private IP or Auth Proxy]
    I --> L[VPC-native private access]
    J --> M[Private Google Access or PSC for Google APIs]
```

### Service-by-service overview
### 🐬 Cloud SQL

A fully managed relational database service for MySQL, PostgreSQL, and SQL Server.

- **Best fit:** Applications that want a familiar engine and managed backups, patching, and failover.
- **Private connectivity model:** Use **Private IP** to place the instance on a producer network reachable through your VPC via Private Services Access. Pair with the Cloud SQL Auth Proxy or language connectors for IAM-aware connectivity.
- **Operational note:** Supports HA with regional configuration.
- **Operational note:** Read replicas support scale-out reads and disaster recovery options.
- **Operational note:** Can combine private IP with authorized networks for temporary admin workflows, but private-only is preferred for production.

### 🌍 Cloud Spanner

A globally distributed relational database with strong consistency and horizontal scale.

- **Best fit:** Mission-critical OLTP systems that must scale writes beyond a single node and often across regions.
- **Private connectivity model:** Spanner is consumed through Google APIs rather than customer-managed NICs. For private reachability from private subnets, use **Private Google Access** or **Private Service Connect for Google APIs** plus VPC Service Controls as needed.
- **Operational note:** Supports regional and multi-region configs.
- **Operational note:** Strong consistency enables global correctness.
- **Operational note:** Client libraries handle session pooling and endpoint selection.

### 📄 Firestore

A serverless document database with mobile/web SDKs and real-time listeners.

- **Best fit:** Applications that need flexible JSON-like documents, event-driven behavior, and offline synchronization.
- **Private connectivity model:** Private access from private workloads is achieved over Google APIs paths via Private Google Access or PSC for Google APIs, not via a database NIC in your VPC.
- **Operational note:** Native mode is the modern default for app development.
- **Operational note:** Datastore mode is used for Datastore compatibility.
- **Operational note:** IAM and Security Rules can both contribute to access control depending on architecture.

### 📈 Bigtable

A petabyte-scale, wide-column NoSQL database designed for huge throughput.

- **Best fit:** Time-series, telemetry, clickstream, ad tech, recommendation systems, and sparse datasets.
- **Private connectivity model:** Like other Google APIs-based services, private access relies on Private Google Access or PSC for Google APIs when source workloads have no public egress.
- **Operational note:** Data modeling is row-key centric.
- **Operational note:** Low-latency access depends heavily on key design and hotspot avoidance.
- **Operational note:** GKE, Dataflow, and custom apps commonly connect through client libraries or the cbt tool.

### ⚡ AlloyDB

A PostgreSQL-compatible database service engineered for high performance and scale.

- **Best fit:** PostgreSQL workloads needing better throughput, read scaling, and analytical acceleration without leaving the PostgreSQL ecosystem.
- **Private connectivity model:** AlloyDB is VPC-native. Applications access it through private IP addresses in the selected VPC, optionally combined with PSC-based patterns or service networking controls.
- **Operational note:** Separate primary and read pool instances provide scaling flexibility.
- **Operational note:** Works well for app modernization where PostgreSQL compatibility is required.
- **Operational note:** Private by design, reducing public exposure risk.

### 🧠 Memorystore

Managed Redis and Memcached for low-latency caching and transient state.

- **Best fit:** Caching, sessions, leaderboards, queue-like workloads, and distributed coordination.
- **Private connectivity model:** Memorystore instances are reached privately from the VPC. DNS, routing, and firewall control are critical when accessing from shared VPC or hybrid networks.
- **Operational note:** Redis supports replica and failover patterns depending on tier.
- **Operational note:** Use it to offload reads from Cloud SQL or AlloyDB.
- **Operational note:** Do not treat cache-only data as durable system-of-record state.

### 📊 BigQuery

Google Cloud data warehouse for analytics, BI, ELT, and ML-enabled SQL workflows.

- **Best fit:** Reporting, historical analysis, centralized logging analytics, and large-scale SQL exploration.
- **Private connectivity model:** Private source systems can access BigQuery through Google APIs privately with Private Google Access or PSC for Google APIs, often combined with VPC Service Controls.
- **Operational note:** Storage and compute scale independently.
- **Operational note:** Excellent complement to operational databases.
- **Operational note:** Common sink target for logging and CDC analytics.

## 2. 🛠️ Setting Up Cloud SQL (Basic to Advanced)

Cloud SQL is often the first managed relational database teams adopt on GCP. A strong build process starts with a simple instance creation flow, then layers in HA, backups, maintenance windows, SSL/TLS, private IP, monitoring, and connection management.

### End-to-end setup workflow
```mermaid
flowchart LR
    A[Enable APIs] --> B[Create VPC + subnets]
    B --> C[Reserve Private Services Access range]
    C --> D[Create Cloud SQL instance]
    D --> E[Create database + users]
    E --> F[Attach backups and HA]
    F --> G[Create replica or DR replica]
    G --> H[Connect through proxy/connector]
    H --> I[Observe, secure, and automate]
```

### Prerequisites
- Enable `sqladmin.googleapis.com`, `servicenetworking.googleapis.com`, and `compute.googleapis.com`.
- Create or identify the VPC and subnet where application workloads will run.
- Decide whether the instance should be **public + controlled**, **private only**, or **dual mode during migration**.
- Establish naming conventions for project, region, instance, databases, users, and service accounts.
- Store admin passwords or generated credentials in Secret Manager instead of local files or shell history.

```bash
gcloud services enable sqladmin.googleapis.com servicenetworking.googleapis.com compute.googleapis.com
PROJECT_ID="my-project"
REGION="us-central1"
INSTANCE="orders-pg-prod"
NETWORK="app-vpc"

gcloud config set project "$PROJECT_ID"
```

### Creating instances with the Console
1. Open **Google Cloud Console → SQL → Create instance**.
2. Choose **MySQL**, **PostgreSQL**, or **SQL Server** based on application compatibility.
3. Select the **edition**, **region**, **zone preference**, machine shape, storage type, and size.
4. Set **availability** to **Regional** for production workloads that require automatic failover.
5. Configure **backups**, **binary logging / point-in-time recovery**, and **maintenance windows**.
6. Under **Connections**, enable **Private IP** and attach the correct VPC network.
7. Optionally disable public IP completely for production private-only designs.
8. Create the initial database and users or do this later with SQL client or `gcloud` commands.
9. Review flags, labels, CMEK, insights, and deletion protection before final creation.

### Creating instances with `gcloud`
### MySQL

```bash
gcloud sql instances create orders-mysql-prod   --database-version=MYSQL_8_0   --cpu=4   --memory=15360MiB   --region=us-central1   --availability-type=REGIONAL   --storage-type=SSD   --storage-size=200   --storage-auto-increase   --backup-start-time=03:00   --enable-bin-log   --deletion-protection   --network=projects/$PROJECT_ID/global/networks/$NETWORK   --no-assign-ip
```

### PostgreSQL

```bash
gcloud sql instances create orders-pg-prod   --database-version=POSTGRES_15   --cpu=4   --memory=15360MiB   --region=us-central1   --availability-type=REGIONAL   --storage-type=SSD   --storage-size=200   --storage-auto-increase   --backup-start-time=03:00   --insights-config-query-insights-enabled   --insights-config-record-application-tags   --network=projects/$PROJECT_ID/global/networks/$NETWORK   --no-assign-ip
```

### SQL Server

```bash
gcloud sql instances create finance-sqlserver-prod   --database-version=SQLSERVER_2019_STANDARD   --cpu=4   --memory=15360MiB   --region=us-central1   --availability-type=REGIONAL   --storage-type=SSD   --storage-size=500   --backup-start-time=02:00   --network=projects/$PROJECT_ID/global/networks/$NETWORK   --no-assign-ip
```

### Terraform example
```hcl
resource "google_compute_global_address" "private_service_range" {
  name          = "google-managed-services-app-vpc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.app_vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.app_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
}

resource "google_sql_database_instance" "postgres" {
  name             = "orders-pg-prod"
  database_version = "POSTGRES_15"
  region           = "us-central1"
  deletion_protection = true

  settings {
    tier              = "db-custom-4-15360"
    availability_type = "REGIONAL"
    disk_type         = "PD_SSD"
    disk_size         = 200
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = true
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.app_vpc.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    maintenance_window {
      day          = 7
      hour         = 3
      update_track = "stable"
    }

    user_labels = {
      env  = "prod"
      app  = "orders"
      tier = "database"
    }
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}
```

### Machine types and storage guidance
| Shape | Example tier | When to choose | Storage notes |
|---|---|---|---|
| Shared core | `db-f1-micro / db-g1-small` | Labs and small dev workloads only | Avoid for sustained production traffic. |
| General purpose | `db-custom-2-7680` | Balanced CPU-memory production apps | Start with SSD for OLTP. |
| Memory optimized | `db-custom-8-53248` | Read-heavy or cache-sensitive relational workloads | Watch storage throughput saturation. |
| SQL Server enterprise sizing | `db-custom-16-61440+` | License-sensitive production systems | Model storage, tempdb behavior, and HA carefully. |
| Burst migration shape | `db-custom-4-15360 to db-custom-8-30720` | Lift-and-shift migration cutovers | Scale up before migration and right-size later. |

- Choose **SSD** for transactional workloads with frequent random I/O.
- Enable **storage auto increase** to reduce outage risk from full disks, but monitor growth so surprise cost does not accumulate.
- Cloud SQL storage does not scale down automatically; plan lifecycle cleanup when temporary spikes occur.
- For PostgreSQL, memory sizing influences shared buffers and cache hit ratio; for MySQL, InnoDB buffer pool behavior matters; for SQL Server, test edition and memory constraints explicitly.

### High availability configuration
A regional Cloud SQL instance keeps a **primary** and a **standby** in different zones. Writes go to the primary. Synchronous replication keeps the standby ready for automatic failover when the primary zone or node fails.

```mermaid
sequenceDiagram
    participant App as Application
    participant P as Primary instance
    participant S as Standby instance
    participant B as Automated backup/PITR
    App->>P: Read/write traffic
    P->>S: Synchronous replication
    P->>B: Backup logs and snapshots
    Note over P,S: Zone outage triggers automatic failover
    S-->>App: Becomes new primary endpoint
```

Key HA design notes:
- Regional instances cost more but materially improve resilience.
- HA does not replace backups, PITR, or cross-region DR.
- Failover changes the serving node, but the instance connection name remains stable for proxy and connector usage.
- Test application retry logic even when using managed failover.

### Read replicas and cross-region replicas
Read replicas are asynchronous. They help with read scaling and can support disaster recovery or reporting isolation.

```bash
gcloud sql instances create orders-pg-replica-east   --master-instance-name=orders-pg-prod   --region=us-east1

gcloud sql instances create orders-pg-replica-eu   --master-instance-name=orders-pg-prod   --region=europe-west1
```

| Replica pattern | Best use case | Notes |
|---|---|---|
| Same-region replica | Offload reports and read APIs | Lower replication latency, limited DR value. |
| Cross-region replica | Regional DR and regional read locality | Asynchronous lag must be measured. |
| Cascading read architecture at app level | Many consumers with distinct read semantics | Use connection pools and route reads explicitly. |
| Promote replica during disaster | Manual failover or controlled DR drill | Validate app config, DNS, and write redirection steps. |

### Step-by-step instance creation flow diagram
```mermaid
flowchart TD
    A[Choose engine] --> B[Select region + HA]
    B --> C[Choose machine shape]
    C --> D[Configure storage + backups]
    D --> E[Attach private network]
    E --> F[Create database + users]
    F --> G[Test connectivity]
    G --> H[Enable Query Insights + alerts]
    H --> I[Add read replicas / DR]
```

### Creating databases and users
```bash
gcloud sql databases create appdb --instance=orders-pg-prod

gcloud sql users create appuser   --instance=orders-pg-prod   --password="REPLACE_ME"

gcloud sql users list --instance=orders-pg-prod
```

### Connection strings for common languages
The safest production pattern is typically one of the following:
- Use the **Cloud SQL Auth Proxy** or a **language connector** with IAM-aware authorization.
- Prefer **private IP** for source workloads inside Google Cloud or hybrid private networks.
- Use **Secret Manager** for passwords and rotate them on a predictable schedule.
- Parameterize instance connection name, private IP, database name, and pool settings through environment variables.

### Python (`psycopg`)

```python
import os
import psycopg

conn = psycopg.connect(
    host=os.environ.get("DB_HOST", "10.20.0.3"),
    port=5432,
    dbname="appdb",
    user="appuser",
    password=os.environ["DB_PASSWORD"],
    sslmode="require"
)
```

### Python with Cloud SQL Python Connector

```python
from google.cloud.sql.connector import Connector
import sqlalchemy

connector = Connector(ip_type="PRIVATE")

def getconn():
    return connector.connect(
        "my-project:us-central1:orders-pg-prod",
        "pg8000",
        user="appuser",
        password="REPLACE_ME",
        db="appdb"
    )

engine = sqlalchemy.create_engine("postgresql+pg8000://", creator=getconn)
```

### Node.js (`pg`)

```javascript
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || '10.20.0.3',
  port: 5432,
  database: 'appdb',
  user: 'appuser',
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});
```

### Node.js with Cloud SQL Connector

```javascript
const {Connector} = require('@google-cloud/cloud-sql-connector');
const {Pool} = require('pg');

const connector = new Connector();
const clientOpts = await connector.getOptions({
  instanceConnectionName: 'my-project:us-central1:orders-pg-prod',
  ipType: 'PRIVATE'
});

const pool = new Pool({
  ...clientOpts,
  user: 'appuser',
  password: process.env.DB_PASSWORD,
  database: 'appdb'
});
```

### Java (JDBC PostgreSQL)

```java
String jdbcUrl = "jdbc:postgresql://10.20.0.3:5432/appdb?sslmode=require";
Properties props = new Properties();
props.setProperty("user", "appuser");
props.setProperty("password", System.getenv("DB_PASSWORD"));
Connection conn = DriverManager.getConnection(jdbcUrl, props);
```

### Java with SocketFactory

```java
String jdbcUrl = "jdbc:postgresql://google/appdb" +
    "?cloudSqlInstance=my-project:us-central1:orders-pg-prod" +
    "&socketFactory=com.google.cloud.sql.postgres.SocketFactory" +
    "&ipTypes=PRIVATE";
```

### Go (`pgx`)

```go
config, _ := pgxpool.ParseConfig("postgres://appuser:" + os.Getenv("DB_PASSWORD") + "@10.20.0.3:5432/appdb?sslmode=require")
pool, err := pgxpool.NewWithConfig(context.Background(), config)
if err != nil { panic(err) }
```

### Go with Cloud SQL Connector

```go
d, err := cloudsqlconn.NewDialer(ctx, cloudsqlconn.WithIAMAuthN())
config, _ := pgxpool.ParseConfig("user=appuser dbname=appdb sslmode=disable")
config.ConnConfig.DialFunc = func(ctx context.Context, network, _ string) (net.Conn, error) {
    return d.Dial(ctx, "my-project:us-central1:orders-pg-prod", cloudsqlconn.WithPrivateIP())
}
```

### C# (`Npgsql`)

```csharp
var cs = "Host=10.20.0.3;Port=5432;Database=appdb;Username=appuser;Password=" +
         Environment.GetEnvironmentVariable("DB_PASSWORD") + ";SSL Mode=Require;Trust Server Certificate=true";
using var conn = new NpgsqlConnection(cs);
await conn.OpenAsync();
```

### PHP (`PDO`)

```php
$dsn = 'pgsql:host=10.20.0.3;port=5432;dbname=appdb;sslmode=require';
$pdo = new PDO($dsn, 'appuser', getenv('DB_PASSWORD'));
```

### Ruby (`pg`)

```ruby
conn = PG.connect(
  host: ENV.fetch('DB_HOST', '10.20.0.3'),
  port: 5432,
  dbname: 'appdb',
  user: 'appuser',
  password: ENV['DB_PASSWORD'],
  sslmode: 'require'
)
```

### MySQL DSN examples

```text
# SQLAlchemy / PyMySQL
mysql+pymysql://appuser:${DB_PASSWORD}@10.30.0.5:3306/appdb

# JDBC
jdbc:mysql://10.30.0.5:3306/appdb?useSSL=true&requireSSL=true

# Go DSN
appuser:${DB_PASSWORD}@tcp(10.30.0.5:3306)/appdb?tls=true
```

### SQL Server connection strings

```text
# ADO.NET
Server=tcp:10.40.0.8,1433;Initial Catalog=appdb;Persist Security Info=False;User ID=appuser;Password=${DB_PASSWORD};Encrypt=True;TrustServerCertificate=False;

# JDBC
jdbc:sqlserver://10.40.0.8:1433;databaseName=appdb;encrypt=true;trustServerCertificate=false;
```

### Real-world Cloud SQL setup scenarios
### Lift-and-shift web app

- **Recommended design:** Use Cloud SQL PostgreSQL with private IP and a Compute Engine or GKE app tier in the same VPC.
- **Primary caution:** Enable PITR, use Secret Manager, and test failover before cutover.
- **Validation checklist:** Confirm route reachability, database user creation, pool sizing, and monitoring before production cutover.

### Cloud Run API with private database

- **Recommended design:** Use serverless VPC access or direct VPC egress with a Cloud SQL connector in private IP mode.
- **Primary caution:** Keep connection pool sizes low because serverless instances can scale rapidly.
- **Validation checklist:** Confirm route reachability, database user creation, pool sizing, and monitoring before production cutover.

### Reporting replica

- **Recommended design:** Create one or more read replicas and route BI/reporting jobs to them.
- **Primary caution:** Measure replica lag before using replicas for user-facing read-after-write requirements.
- **Validation checklist:** Confirm route reachability, database user creation, pool sizing, and monitoring before production cutover.

### Cross-region DR

- **Recommended design:** Pair HA in the primary region with a cross-region replica and documented promotion steps.
- **Primary caution:** Automate connection reconfiguration and verify DNS cutover runbooks.
- **Validation checklist:** Confirm route reachability, database user creation, pool sizing, and monitoring before production cutover.

### Shared VPC enterprise platform

- **Recommended design:** Create the instance in the service project or host project as required by governance, and ensure Service Networking and routes are approved centrally.
- **Primary caution:** Coordinate with network teams early because private service ranges and DNS choices affect many projects.
- **Validation checklist:** Confirm route reachability, database user creation, pool sizing, and monitoring before production cutover.

## 3. 🔒 Private IP Access for Cloud SQL

Private IP is the recommended default for production Cloud SQL connectivity when source workloads are inside GCP or connected privately through hybrid networking. With private IP, traffic stays on Google’s backbone rather than relying on public internet paths.

### How private IP works
- Cloud SQL uses **Private Services Access (PSA)** to allocate producer-side IP space reachable through your VPC.
- You reserve an internal address range in your VPC and create a peering connection to `servicenetworking.googleapis.com`.
- The Cloud SQL instance receives a private address from the producer range and becomes reachable from authorized networks attached to that VPC design.
- Firewall rules do not directly target Cloud SQL in the same way as a VM NIC, but routing, DNS, source subnets, and hybrid path control still matter.

### Private IP architecture diagram
```mermaid
flowchart LR
    subgraph Consumer[Consumer VPC]
      A[GKE / GCE / Cloud Run via VPC] --> B[Private route]
      C[On-prem] --> D[VPN / Interconnect]
      D --> B
    end
    B --> E[Private Services Access peering]
    E --> F[Cloud SQL private IP]
    G[Cloud SQL Auth Proxy / connectors] --> A
    H[Secret Manager + IAM] --> G
```

### Configuring Private Services Access and Private IP
```bash
NETWORK="app-vpc"
RANGE_NAME="google-managed-services-app-vpc"

gcloud compute addresses create "$RANGE_NAME"   --global   --purpose=VPC_PEERING   --addresses=10.200.0.0   --prefix-length=16   --network="$NETWORK"

gcloud services vpc-peerings connect   --service=servicenetworking.googleapis.com   --ranges="$RANGE_NAME"   --network="$NETWORK"

gcloud sql instances patch orders-pg-prod   --network=projects/$PROJECT_ID/global/networks/$NETWORK   --no-assign-ip
```

### Validation checklist for private IP
- [ ] Confirm the allocated PSA range does not overlap with existing or future hybrid CIDRs.
- [ ] Confirm the peering connection exists and is in `ACTIVE` state.
- [ ] Confirm the Cloud SQL instance shows a **private IP address** in the instance details.
- [ ] Confirm the source subnet has routes toward Google-managed services via VPC peering.
- [ ] Confirm source workloads can resolve the correct private address if DNS indirection is used.
- [ ] Confirm applications use the private IP or connector setting `ip_type=PRIVATE` rather than public endpoints.

### VPC peering considerations for Cloud SQL private access
| Topic | Why it matters | Guidance |
|---|---|---|
| IP overlap | Peering fails or future growth becomes hard | Reserve generous RFC1918 space for managed services early. |
| Shared VPC | Application and network ownership are separated | Coordinate host/service project permissions and service networking setup. |
| Route export/import | Hybrid access may depend on custom route visibility | Validate route propagation when on-prem reaches private services through the VPC. |
| DNS naming | Applications often prefer stable hostnames | Publish internal DNS names that map to private endpoints and can be changed during failover. |
| Change control | PSA ranges are foundational network resources | Treat them like core infrastructure with review and version control. |

### Private Service Connect for Cloud SQL
Private Service Connect (PSC) can be used to expose Google-managed services or selected service producer endpoints privately into consumer VPCs. For Cloud SQL, PSC is useful when you want consumer VPC endpoint semantics, especially across project boundaries or when standard PSA reachability alone does not align with the operating model.

### Authorized networks
Authorized networks allow public-IP clients to reach Cloud SQL from specific source IP ranges. They are useful for short-term administration or transitional migration patterns, but they are **not the preferred steady-state** for production workloads that can use private IP.

- Use authorized networks only when public IP is enabled.
- Restrict entries to narrow source ranges and set expiration reminders.
- Prefer bastion or admin workstations over broad office CIDRs when possible.
- Keep SSL/TLS enabled even when authorized networks are configured.

```bash
gcloud sql instances patch orders-pg-prod   --authorized-networks=203.0.113.10/32,198.51.100.0/24
```

### Cloud SQL Auth Proxy with private IP
```bash
./cloud-sql-proxy   --private-ip   --address 127.0.0.1   --port 5432   my-project:us-central1:orders-pg-prod
```

When the proxy runs with `--private-ip`, it still performs IAM and certificate-based authorization, but the network path from the runtime to the database uses the instance private address rather than the public IP path.

### Decision guide: public IP vs private IP vs proxy
| Option | Best when | Benefits | Cautions |
|---|---|---|---|
| Public IP + authorized networks | Short-term admin access or migration | Fast to set up | Broader exposure and external IP dependence. |
| Private IP only | Apps run in GCP or hybrid private networks | Stays on private network path | Requires PSA planning and hybrid route design. |
| Auth Proxy + private IP | You want both IAM-aware auth and private path | Excellent default for secure production apps | Requires sidecar or local process management. |
| Language connector + private IP | Modern runtimes with supported libraries | Less operational overhead than standalone proxy | Language/library support varies by stack. |
| PSC endpoint | Consumer VPC endpoint model or strict network segmentation | Cleaner producer-consumer abstraction | Operational model differs from simple PSA reachability. |

## 4. 🔌 Private Service Connect

Private Service Connect (PSC) lets consumers reach services privately by connecting to an internal endpoint in their own VPC. It is valuable when you want **service producer/consumer isolation**, predictable endpoint ownership, and cleaner cross-project or cross-organization boundaries.

### What is PSC?
- A service producer publishes a service or Google API endpoint.
- A service consumer creates a PSC endpoint in its subnet.
- Traffic from the consumer goes to the local internal IP, then is privately forwarded to the producer service.
- DNS often maps a friendly internal hostname to the PSC endpoint IP.
- PSC reduces the need to expose broad producer networks directly to consumers.

```mermaid
flowchart LR
    subgraph ConsumerVPC[Consumer VPC]
      A[App VM / Pod / Cloud Run via VPC] --> B[PSC endpoint IP]
      D[Internal DNS] --> B
    end
    B --> C[Service attachment / Google-managed service]
    C --> E[Cloud SQL / AlloyDB / Memorystore]
```

### PSC architecture overview
| Component | Description |
|---|---|
| PSC endpoint | An internal IP in the consumer subnet that applications target. |
| Service attachment / producer service | The producer-side object that accepts PSC connections. |
| Internal DNS | Maps stable names to PSC endpoint addresses. |
| Consumer firewall / routing | Controls which clients can reach the endpoint inside the VPC. |
| Observability | Use flow logs, DNS logs, app logs, and service metrics to validate traffic paths. |

### Setting up PSC for Cloud SQL
High-level sequence:
1. Confirm the Cloud SQL service and region support the desired PSC topology.
2. Create or identify the consumer VPC subnet where the PSC endpoint IP will live.
3. Provision the PSC endpoint and bind DNS to it.
4. Restrict clients to the intended subnet, namespace, or service account pattern.
5. Test connectivity using the app runtime, proxy, or connector settings expected in production.

### Setting up PSC for AlloyDB
AlloyDB is already VPC-native, but PSC can still help when producer and consumer environments are separated by network governance or when a private endpoint abstraction is preferred over exposing producer routing broadly.

### Setting up PSC for Memorystore
For Redis-centric designs, the goal is usually to keep cache traffic private and low-latency. PSC patterns can simplify how shared consumer networks access managed producer services while keeping internal IP-based addressing.

### DNS configuration for PSC
```bash
# Example Cloud DNS private zone record
# Replace the IP with the PSC endpoint internal address.
gcloud dns managed-zones create db-private-zone   --description="Private zone for database endpoints"   --dns-name="db.internal."   --visibility=private   --networks="$NETWORK"

gcloud dns record-sets transaction start --zone=db-private-zone
gcloud dns record-sets transaction add 10.10.20.15   --name=orders-pg.db.internal.   --ttl=30   --type=A   --zone=db-private-zone
gcloud dns record-sets transaction execute --zone=db-private-zone
```

### Network flow diagram
```mermaid
sequenceDiagram
    participant Client as Client in consumer VPC
    participant DNS as Private DNS
    participant PSC as PSC endpoint
    participant Producer as Producer service attachment
    participant DB as Managed database
    Client->>DNS: Resolve orders-pg.db.internal
    DNS-->>Client: 10.10.20.15
    Client->>PSC: TCP session to endpoint IP
    PSC->>Producer: Private service forwarding
    Producer->>DB: Service-internal connection
    DB-->>Client: Response over private path
```

### PSC design recommendations
- Use private DNS so applications rely on names, not endpoint IP literals.
- Version-control endpoint, subnet, and DNS records with Terraform.
- Keep endpoint subnets dedicated when many services share the same VPC.
- Document ownership boundaries: network team, platform team, and application team responsibilities should be explicit.
- Test failover and change procedures because some PSC changes require endpoint recreation or DNS updates.

## 5. 🏢 Connecting from On-Premises

Hybrid connectivity is common when applications or administrative tooling remain in a datacenter while databases move to GCP. The private path choices usually revolve around **HA VPN** for quick secure connectivity and **Cloud Interconnect** for high-throughput or predictable-latency enterprise links.

### Hybrid connectivity options
| Option | Best for | Characteristics |
|---|---|---|
| HA VPN | Fast deployment, lower throughput needs, encrypted tunnels | Two interfaces, SLA-backed design when configured correctly, BGP recommended. |
| Dedicated Interconnect | High throughput, stable enterprise connectivity | Physical connectivity into Google network with VLAN attachments. |
| Partner Interconnect | Enterprise connectivity through a service provider | Useful when direct colocation with Google is not available. |
| Cross-Cloud via partner or SD-WAN | Complex multi-cloud topologies | Requires careful route, MTU, and DNS design. |
| Admin-only bastion path | Temporary transitional operations | Simpler, but not ideal for application data planes. |

### HA VPN setup summary
1. Create a Cloud Router in the target region.
2. Create an HA VPN gateway with two interfaces.
3. Create external VPN gateway definitions for the on-prem device pair.
4. Create tunnels between each pair of interfaces.
5. Enable BGP on each tunnel and advertise the on-prem and VPC prefixes.
6. Validate route exchange and failover by disabling one tunnel at a time.

```bash
gcloud compute routers create hybrid-router   --region=us-central1   --network=app-vpc   --asn=64514

gcloud compute vpn-gateways create hybrid-ha-vpn   --region=us-central1   --network=app-vpc
```

### Cloud Interconnect (Dedicated / Partner)
- Use **Dedicated Interconnect** when you need high-capacity private links and can meet colocation requirements.
- Use **Partner Interconnect** when a provider offers connectivity at your site or metro and you prefer managed last-mile integration.
- Use **VLAN attachments** and **Cloud Router** to exchange routes with your on-premises network.
- For database traffic, validate MTU assumptions, asymmetric routing risks, and DNS resolver placement before production cutover.

### Cloud Router and BGP
Cloud Router dynamically exchanges prefixes between your VPC and on-premises network. This reduces static route drift and helps hybrid database endpoints remain reachable after topology changes.

| BGP topic | Guidance |
|---|---|
| ASN planning | Use private ASNs unless enterprise policy dictates otherwise. |
| Advertised routes | Advertise only necessary prefixes to reduce accidental reachability. |
| Redundancy | Use multiple tunnels or VLAN attachments and test failover paths regularly. |
| Custom route export/import | Required in some peering and shared VPC designs to surface private service reachability. |
| Monitoring | Alert on session state, route drops, and tunnel throughput anomalies. |

### DNS forwarding for private resources
A hybrid design often fails not because routing is wrong, but because names do not resolve correctly across environments. Treat DNS as a first-class part of the private access design.

```bash
# Example: create an inbound forwarding policy for Cloud DNS
gcloud dns policies create hybrid-inbound-policy   --description="Inbound DNS forwarding for hybrid clients"   --networks="$NETWORK"   --enable-inbound-forwarding

# Example: create a forwarding zone toward on-prem resolvers
gcloud dns managed-zones create corp-forward-zone   --dns-name="corp.example.com."   --description="Forward corp DNS to on-prem"   --visibility=private   --forwarding-targets=192.168.10.10,192.168.10.11   --networks="$NETWORK"
```

### Hybrid network topology diagram
```mermaid
flowchart LR
    subgraph OnPrem[On-premises]
      A[App servers]
      B[DNS resolvers]
      C[Edge routers]
    end
    subgraph GCP[Google Cloud]
      D[HA VPN / Interconnect]
      E[Cloud Router + BGP]
      F[Consumer VPC]
      G[Cloud DNS private zones]
      H[Cloud SQL / AlloyDB / Memorystore]
    end
    A --> C --> D --> E --> F --> H
    B --> G
    A --> B
    F --> G
```

### Real-world hybrid scenarios
### On-prem app to Cloud SQL

Prefer private IP over PSA, route through HA VPN or Interconnect, and use the Auth Proxy if IAM-aware access is needed.

### DBA workstation in datacenter

Provide a controlled bastion or workstation subnet with access to private endpoints and audited SQL client usage.

### Shared services DNS hub

Centralize private DNS records for managed databases and forward selectively to branch sites.

### Multi-region hybrid failover

Publish low-TTL internal DNS names and practice regional failover with route validation and replica promotion.

## 6. 🧰 Cloud SQL Auth Proxy Deep Dive

The Cloud SQL Auth Proxy creates a secure, authorized connection to Cloud SQL without exposing database credentials directly on the network path. It uses IAM and ephemeral certificates to establish connectivity, and can target either private or public IP depending on runtime placement and flags.

### How it works
```mermaid
flowchart LR
    A[Application] --> B[Local proxy listener 127.0.0.1 or sidecar]
    B --> C[Cloud SQL Admin API auth flow]
    C --> D[Ephemeral cert + IAM authorization]
    D --> E[Private IP or public IP path]
    E --> F[Cloud SQL instance]
```

### Proxy value proposition
- Removes the need to manage long-lived client certificates manually in many cases.
- Works well with service accounts and workload identity.
- Supports local development, CI jobs, bastions, and in-cluster sidecars.
- Can target **private IP** with the `--private-ip` option.

### Installation
```bash
# Linux AMD64 example
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.11.4/cloud-sql-proxy.linux.amd64
chmod +x cloud-sql-proxy
sudo mv cloud-sql-proxy /usr/local/bin/
```

### Local usage
```bash
cloud-sql-proxy my-project:us-central1:orders-pg-prod

# Explicit port and private IP
cloud-sql-proxy   --private-ip   --port=5432   my-project:us-central1:orders-pg-prod
```

### Example: Compute Engine systemd service
```ini
[Unit]
Description=Cloud SQL Auth Proxy
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/cloud-sql-proxy --private-ip --structured-logs --port=5432 my-project:us-central1:orders-pg-prod
Restart=always
User=appuser
Environment=GOOGLE_APPLICATION_CREDENTIALS=/etc/google/service-account.json

[Install]
WantedBy=multi-user.target
```

### Example: GKE sidecar
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-with-cloudsql
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-with-cloudsql
  template:
    metadata:
      labels:
        app: api-with-cloudsql
    spec:
      serviceAccountName: api-ksa
      containers:
      - name: app
        image: us-docker.pkg.dev/my-project/apps/api:latest
        env:
        - name: DB_HOST
          value: 127.0.0.1
        - name: DB_PORT
          value: "5432"
      - name: cloud-sql-proxy
        image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.11.4
        args:
        - "--private-ip"
        - "--structured-logs"
        - "--port=5432"
        - "my-project:us-central1:orders-pg-prod"
```

### Example: Cloud Run
- Cloud Run can use built-in Cloud SQL integration or language connectors.
- For private IP, ensure the service has VPC connectivity through Direct VPC egress or Serverless VPC Access as required by the chosen pattern.
- Keep pool size conservative because Cloud Run instances can scale out quickly and overwhelm database connection limits.

```bash
gcloud run deploy orders-api   --image=us-docker.pkg.dev/my-project/apps/orders-api:latest   --region=us-central1   --set-env-vars=INSTANCE_CONNECTION_NAME=my-project:us-central1:orders-pg-prod   --set-env-vars=DB_NAME=appdb   --vpc-connector=serverless-apps   --add-cloudsql-instances=my-project:us-central1:orders-pg-prod
```

### IAM-based authentication
- Use service accounts to authorize the proxy or connector to connect to the instance.
- Grant the minimum required roles, typically including `roles/cloudsql.client` and any Secret Manager roles needed for password retrieval.
- For PostgreSQL and MySQL IAM database authentication patterns, map IAM identities to database users where the engine and feature set support it.
- Audit both Cloud IAM access and in-database actions; they answer different security questions.

### Private IP mode vs public IP mode
| Mode | Network path | When to use | Security posture |
|---|---|---|---|
| Proxy + private IP | Private VPC/hybrid route to private address | Preferred for production private environments | Best balance of private routing and IAM-aware authorization. |
| Proxy + public IP | Google-managed public endpoint path | Useful when private routing is not yet available | Strong auth, but broader network exposure. |
| Connector + private IP | Same as private proxy pattern | Modern app stacks with supported libraries | Very strong and operationally simple. |
| Direct TCP + private IP | Direct socket to private address | Legacy apps or constrained environments | Requires manual handling of TLS, passwords, and pools. |
| Direct TCP + public IP | Public internet path or public Google ingress | Only for tightly controlled exceptions | Least preferred for production. |

### Operational guidelines for the proxy
- Monitor proxy logs for certificate refresh and connection errors.
- Pin a known-good proxy major/minor version and plan upgrades.
- Use structured logs so proxy events can be correlated with application logs.
- Do not run unbounded connection pools behind autoscaling systems.
- Prefer workload identity over distributing JSON keys when running on GKE or Compute Engine.

## 7. 🌐 Spanner & AlloyDB

### Cloud Spanner setup and connectivity

Spanner is consumed through API endpoints rather than a customer-managed NIC. The main connectivity question is usually how private workloads reach Google APIs without public internet egress.

```bash
gcloud services enable spanner.googleapis.com

gcloud spanner instances create global-orders   --config=regional-us-central1   --description="Regional Spanner for orders"   --processing-units=1000

gcloud spanner databases create appdb   --instance=global-orders
```

Private access recommendations for Spanner:
- Use **Private Google Access** from private subnets so workloads without external IPs can still reach Google APIs.
- Use **Private Service Connect for Google APIs** when you want private endpoints for Google API access inside the VPC.
- Use **VPC Service Controls** to limit data exfiltration paths for high-sensitivity projects.
- Use client libraries with session pools, retries, and regional endpoint guidance aligned to the chosen config.

### AlloyDB setup (primary + read pool)

```bash
gcloud services enable alloydb.googleapis.com

gcloud alloydb clusters create orders-alloydb   --region=us-central1   --network=projects/$PROJECT_ID/global/networks/app-vpc   --password=REPLACE_ME

gcloud alloydb instances create orders-alloydb-primary   --cluster=orders-alloydb   --instance-type=PRIMARY   --cpu-count=4

gcloud alloydb instances create orders-alloydb-readpool   --cluster=orders-alloydb   --instance-type=READ_POOL   --cpu-count=4
```

AlloyDB private access notes:
- AlloyDB is private-first and attaches to the selected VPC.
- Use internal DNS names for primary and read pool endpoints.
- Design connection pools so read traffic can be shifted to read pools without application rewrite where practical.
- Observe primary lag, replica health, and planned failover behavior during DR drills.

### Cross-region access patterns
| Service | Pattern | Why teams choose it |
|---|---|---|
| Spanner | Multi-region configuration | Global strongly consistent systems with high availability. |
| Spanner | Regional config + edge services | When one region owns writes but apps run globally. |
| AlloyDB | Regional primary + read pools | Low-latency reads with PostgreSQL compatibility. |
| Cloud SQL | Primary + cross-region read replica | DR and localized reporting, but not global strongly consistent writes. |
| Bigtable | Cluster replication across zones/regions | Low-latency reads for large datasets and resilience. |
| Firestore | Multi-region database | Serverless document workloads requiring stronger availability characteristics. |

## 8. 📚 Firestore & Bigtable Access

### Firestore modes

| Mode | Description | When to use |
|---|---|---|
| Native mode | Modern document database behavior with Firestore capabilities | New app development, mobile/web backends, event-driven systems. |
| Datastore mode | Compatibility mode for legacy Datastore-style applications | Existing apps migrating from or remaining compatible with Datastore semantics. |

```bash
gcloud services enable firestore.googleapis.com
# Firestore databases are commonly created via console or API depending on mode and region selection.
```

### Firestore client library setup
```python
from google.cloud import firestore

db = firestore.Client(project="my-project")
doc_ref = db.collection("orders").document("1001")
doc_ref.set({"status": "PLACED", "total": 100.25})
```

```javascript
const {Firestore} = require('@google-cloud/firestore');
const db = new Firestore({projectId: 'my-project'});
await db.collection('orders').doc('1001').set({status: 'PLACED', total: 100.25});
```

Private access note: server workloads in private subnets typically reach Firestore through **Private Google Access** or **PSC for Google APIs** so they do not require public egress.

### Bigtable instance and cluster setup

```bash
gcloud services enable bigtableadmin.googleapis.com

gcloud bigtable instances create telemetry-bt   --display-name="Telemetry Bigtable"   --cluster=telemetry-bt-c1   --cluster-zone=us-central1-b   --cluster-num-nodes=3   --cluster-storage-type=SSD
```

### `cbt` CLI usage
```bash
# Install cbt and configure environment variables
export CBT_PROJECT=my-project
export CBT_INSTANCE=telemetry-bt

cbt createtable metrics families=cf1
cbt set metrics r1 cf1:cpu=0.92
cbt read metrics
```

### Access from GKE pods
- Use **Workload Identity** so pods call Bigtable and Firestore without long-lived service account keys.
- Ensure node or pod networking has private access to Google APIs if cluster nodes have no external IPs.
- Use namespace/service-account mapping so least privilege can be enforced per workload.
- Monitor client latency and retry behavior because Bigtable throughput depends heavily on row-key design and batching.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: analytics-api
  annotations:
    iam.gke.io/gcp-service-account: analytics-api@my-project.iam.gserviceaccount.com
```

### Practical guidance
- Use Firestore for app-centric document access patterns, not for ad hoc analytical scans across huge collections.
- Use Bigtable when throughput and scale are dominant and you can design around row-key access.
- For private worker nodes, validate Google APIs reachability before troubleshooting IAM or client library issues.
- Keep cbt only for operations and testing; production apps should use maintained client libraries.

## 9. 🛡️ Database Security

Database security is layered. A strong design uses identity, network segmentation, encryption, logging, and operational discipline together rather than relying on a single control.

```mermaid
flowchart TD
    A[Client workload identity] --> B[IAM authorization]
    B --> C[Proxy / connector / TLS]
    C --> D[Private network path]
    D --> E[Managed database]
    E --> F[CMEK / storage encryption]
    E --> G[Audit logs]
    E --> H[Query insights + metrics]
    I[Secret Manager] --> A
    J[VPC Service Controls] --> E
```

### IAM database authentication
- Use IAM roles such as `roles/cloudsql.client` for connection authorization to Cloud SQL through the proxy or connectors.
- Separate infrastructure admins, database admins, and application runtimes into different service accounts.
- Where supported, map IAM identities to in-database auth patterns so short-lived identity replaces shared static passwords.
- Review effective permissions periodically; inherited IAM in shared projects is a common source of overreach.

### Secret Manager for credentials
```bash
echo -n 'REPLACE_ME' | gcloud secrets create db-password --data-file=-

gcloud secrets add-iam-policy-binding db-password   --member=serviceAccount:orders-api@my-project.iam.gserviceaccount.com   --role=roles/secretmanager.secretAccessor
```

### CMEK encryption
- Use **Customer-Managed Encryption Keys (CMEK)** where compliance or key ownership requirements demand it.
- Plan key rotation, separation of duties, and break-glass procedures before enabling CMEK in production.
- Test recovery procedures because key disablement or IAM mistakes can make databases unavailable.

### SSL/TLS connections
- Require encrypted connections whenever direct TCP is used.
- For Cloud SQL, connectors and the Auth Proxy simplify secure transport and certificate handling.
- Do not disable certificate validation in production except for tightly controlled temporary testing.
- Rotate server and client certificates according to the service guidance if using manual certificate approaches.

### VPC Service Controls
VPC Service Controls are particularly useful for API-based managed data services such as Spanner, BigQuery, Firestore, and Bigtable, where controlling data exfiltration across project boundaries matters as much as network routing.

### Audit logging
| Log type | What it tells you |
|---|---|
| Admin Activity | Who changed instance configuration, IAM, backups, networking, or settings. |
| Data Access | Who accessed data or APIs where supported and enabled. |
| System Event | Service-side events such as maintenance or automated actions. |
| Database engine logs | Engine-level authentication failures, slow queries, and SQL diagnostics. |
| VPC Flow Logs / DNS logs | Whether the source runtime attempted to reach the intended endpoint and how traffic moved. |

### Security best-practice checklist
- [ ] Disable public IP unless there is a documented reason to keep it.
- [ ] Use private DNS names and avoid embedding raw IP addresses in app configs.
- [ ] Grant the minimum IAM roles to runtime service accounts.
- [ ] Rotate database passwords and service credentials on a schedule.
- [ ] Centralize secrets in Secret Manager.
- [ ] Enable backups, PITR, deletion protection, and audit logging.
- [ ] Review TLS, proxy, and connector settings during every major release.
- [ ] Protect analytics and admin projects with VPC Service Controls when sensitive datasets are involved.

## 10. 🧯 Database Troubleshooting

Troubleshooting private database access is easiest when you work in layers: **identity → DNS → routing → endpoint reachability → database auth → application pool behavior**.

### Connection failure runbook
1. Verify the application is using the expected hostname or instance connection name.
2. Verify DNS resolves to the intended private endpoint or proxy listener.
3. Verify route reachability from the source subnet or hybrid path.
4. Verify the service account or user has the required IAM and database permissions.
5. Verify the proxy or connector logs show successful certificate refresh and authorized connections.
6. Verify the database is healthy, not undergoing failover or maintenance, and has not exhausted connection limits.

### Performance diagnostics with Query Insights
- Enable **Query Insights** on supported Cloud SQL engines to see high-latency queries, execution fingerprints, and client/application tags.
- Correlate query spikes with deployment windows, pool changes, or replica lag.
- Use Query Insights with CPU, memory, disk, and connection metrics to decide whether the problem is SQL, application behavior, or instance sizing.
- For PostgreSQL and MySQL, pair service-level insights with engine-native explain plans and index analysis.

### Common errors and solutions
| Symptom | Likely cause | Immediate checks | Resolution |
|---|---|---|---|
| Connection timeout | Missing route, wrong private IP, PSC DNS issue | Ping/traceroute equivalents, DNS lookup, VPC Flow Logs | Fix routing, DNS, or hybrid path and retest. |
| Proxy says permission denied | Missing `roles/cloudsql.client` or wrong service account | Check active identity and IAM bindings | Grant minimum required role and restart runtime if needed. |
| Too many connections | Autoscaling app and oversized pools | Review connection metrics and pool settings | Reduce pool size, add pooling layer, or scale database appropriately. |
| SSL required error | Client not using TLS or connector | Inspect client connection string | Enable TLS or move to proxy/connector pattern. |
| Replica lag too high | Read-heavy pressure or network distance | Check replica metrics and heavy queries | Tune workload, resize, or route fewer reads to the replica. |
| Hybrid clients can route but not resolve | DNS forwarding or private zone mismatch | Run `nslookup` / `dig` from client side | Fix forwarding rules or zone bindings. |
| Spanner from private subnet fails | No Private Google Access or PSC for Google APIs | Check subnet settings and endpoint route | Enable PGA or configure PSC for Google APIs. |
| Bigtable client high latency | Poor row-key design or hotspotting | Review key distribution and cluster CPU | Redesign row keys, add nodes, or rebalance access patterns. |
| Auth works locally, not in GKE | Workload Identity mapping missing | Inspect KSA↔GSA binding and pod identity | Fix annotations and IAM binding. |
| Cloud Run bursts overload DB | Too many concurrent instances and connections | Review max instances and DB connection count | Cap concurrency, add pooling, or use read replicas. |

### Troubleshooting heuristics
- If **DNS fails**, fix naming before testing ports.
- If **routing fails**, proxy and credentials are irrelevant until packets can reach the endpoint.
- If **IAM fails**, network tests may still succeed because TCP reachability is not the same as authorized database access.
- If **query latency** rises after an app deploy, inspect connection reuse and ORM behavior before resizing the database.
- If **replica lag** spikes, verify new analytics jobs or batch exports were not redirected unexpectedly.

## 11. 🧭 Reference Architectures, Scenarios, and Checklists

The following scenario cards summarize common designs teams implement in real environments. They are intentionally short so they can be reused in architecture reviews and migration runbooks.

### Scenario 1: GKE microservice to private Cloud SQL

- **Primary service:** Cloud SQL PostgreSQL
- **Connectivity pattern:** GKE sidecar proxy with Workload Identity and private IP
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Use namespace-level service accounts and per-service pools.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 2: Cloud Run API to Cloud SQL

- **Primary service:** Cloud SQL MySQL/PostgreSQL
- **Connectivity pattern:** Cloud SQL connector plus VPC access in private mode
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Cap Cloud Run instances during peak bursts.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 3: Shared VPC app teams

- **Primary service:** Cloud SQL / AlloyDB
- **Connectivity pattern:** Host project networking with service project runtimes
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Centralize PSA ranges and private DNS governance.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 4: Datacenter ERP to SQL Server

- **Primary service:** Cloud SQL for SQL Server
- **Connectivity pattern:** HA VPN or Interconnect to private IP
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Test SQL client driver encryption settings early.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 5: Global SaaS control plane

- **Primary service:** Cloud Spanner
- **Connectivity pattern:** Private Google Access or PSC for Google APIs
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Model instance config and leader placement around user write geography.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 6: Gaming cache tier

- **Primary service:** Memorystore Redis
- **Connectivity pattern:** Private VPC access from GKE
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Set eviction policy and persistence expectations explicitly.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 7: IoT telemetry ingest

- **Primary service:** Bigtable
- **Connectivity pattern:** GKE/Dataflow private Google APIs access
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Design row keys for evenly distributed writes.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 8: Mobile backend

- **Primary service:** Firestore
- **Connectivity pattern:** Serverless SDKs with backend jobs in private subnets using PGA
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Balance IAM and Firestore Security Rules responsibilities.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 9: Analytics export

- **Primary service:** BigQuery
- **Connectivity pattern:** Private Google APIs with VPC SC
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Separate analytics project boundaries from production OLTP networks.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 10: DR-ready regional retail app

- **Primary service:** Cloud SQL + cross-region replica
- **Connectivity pattern:** Regional HA in primary region plus cross-region read replica
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Practice manual promotion and app failover quarterly.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 11: PostgreSQL modernization

- **Primary service:** AlloyDB
- **Connectivity pattern:** Primary + read pools on private VPC
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Benchmark extension compatibility before migration.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 12: Admin bastion pattern

- **Primary service:** Any relational DB
- **Connectivity pattern:** Bastion host or admin workstation subnet plus proxy
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Do not open broad office CIDRs through authorized networks.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 13: M&A temporary hybrid integration

- **Primary service:** Cloud SQL or AlloyDB
- **Connectivity pattern:** Short-term VPN and transitional public admin path
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Track every temporary exception with expiration dates.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 14: Branch office report readers

- **Primary service:** Read replica
- **Connectivity pattern:** Hybrid route to regional read replica
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Keep writes pinned to the primary and communicate lag expectations.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 15: Event processor on Compute Engine

- **Primary service:** Cloud SQL
- **Connectivity pattern:** Systemd-managed proxy on VM
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Rotate service identity and monitor proxy restarts.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 16: Anthos or multicloud app

- **Primary service:** Spanner / Firestore / Bigtable
- **Connectivity pattern:** PSC for Google APIs or secure egress routing
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Validate policy controls across multiple network domains.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 17: Internal platform DB-as-a-service

- **Primary service:** Cloud SQL / AlloyDB
- **Connectivity pattern:** PSC endpoints and internal DNS abstraction
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Expose golden paths, not raw service details, to app teams.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 18: Compliance-bound finance workload

- **Primary service:** Cloud SQL / Spanner
- **Connectivity pattern:** Private path, CMEK, VPC SC, audit logging
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Separate key administration from database administration.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 19: Batch ETL worker farm

- **Primary service:** Cloud SQL read replica or BigQuery sink
- **Connectivity pattern:** Jobs on GKE/Dataflow with private API access
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Protect primary OLTP latency from heavy read jobs.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Scenario 20: Multi-region API read locality

- **Primary service:** AlloyDB / Cloud SQL replicas
- **Connectivity pattern:** Direct region-local reads and region-central writes
- **Security controls:** Private DNS, IAM-minimized runtime identity, secret management, and monitoring are mandatory.
- **Availability posture:** Use HA, retries, and backup/restore testing appropriate to the service.
- **Primary caution:** Document consistency semantics per endpoint.
- **Validation:** Run DNS, route, auth, and failover tests before go-live.

### Production readiness checklist
- [ ] Reserved PSA ranges reviewed for overlap and future growth.
- [ ] Private DNS names created and documented.
- [ ] Backups, PITR, and restore drills completed.
- [ ] Application connection pool sizes validated under autoscaling conditions.
- [ ] Read/write split documented if replicas or read pools exist.
- [ ] IAM runtime roles reviewed by security or platform engineering.
- [ ] Metrics, alerts, and logs integrated into team dashboards.
- [ ] Hybrid route failover tested for HA VPN or Interconnect if used.
- [ ] DBA/admin emergency access documented with approval process.
- [ ] Engine upgrade and maintenance window strategy documented.

## 12. 📎 Appendix: Command Catalog and Glossary

### Quick command catalog
| Purpose | Command |
|---|---|
| List Cloud SQL instances | `gcloud sql instances list` |
| Describe Cloud SQL instance | `gcloud sql instances describe orders-pg-prod` |
| Create read replica | `gcloud sql instances create orders-pg-replica-east --master-instance-name=orders-pg-prod --region=us-east1` |
| Enable authorized networks | `gcloud sql instances patch orders-pg-prod --authorized-networks=203.0.113.10/32` |
| Create Spanner instance | `gcloud spanner instances create global-orders --config=regional-us-central1 --processing-units=1000` |
| Create Bigtable instance | `gcloud bigtable instances create telemetry-bt --display-name="Telemetry" --cluster=telemetry-c1 --cluster-zone=us-central1-b --cluster-num-nodes=3 --cluster-storage-type=SSD` |
| Create DNS private zone | `gcloud dns managed-zones create db-private-zone --dns-name=db.internal. --visibility=private --networks=app-vpc` |
| Create HA VPN gateway | `gcloud compute vpn-gateways create hybrid-ha-vpn --region=us-central1 --network=app-vpc` |
| Run Cloud SQL proxy | `cloud-sql-proxy --private-ip --port=5432 my-project:us-central1:orders-pg-prod` |
| Create AlloyDB cluster | `gcloud alloydb clusters create orders-alloydb --region=us-central1 --network=projects/$PROJECT_ID/global/networks/app-vpc --password=REPLACE_ME` |

### Glossary
- **PSA:** Private Services Access; VPC peering-based connectivity for managed services such as Cloud SQL private IP.
- **PSC:** Private Service Connect; private endpoints for producer/consumer service connectivity.
- **PGA:** Private Google Access; lets private workloads reach Google APIs without external IPs.
- **PITR:** Point-in-time recovery; restore database state to a chosen point within retention.
- **Read replica:** Asynchronous copy of a primary instance used for reads or DR patterns.
- **Read pool:** AlloyDB reader capacity pool used to scale reads.
- **VPC SC:** VPC Service Controls; service perimeter feature to reduce data exfiltration risk.
- **BGP:** Border Gateway Protocol; dynamic route exchange used with Cloud Router in hybrid networking.
- **Workload Identity:** GKE mechanism for mapping Kubernetes service accounts to Google service accounts.
- **Connector:** Language-specific library that simplifies secure connectivity to Cloud SQL.

### Reference note 1: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 2: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 3: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 4: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 5: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 6: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 7: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 8: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 9: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 10: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 11: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 12: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 13: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 14: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 15: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 16: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 17: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 18: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 19: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 20: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 21: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 22: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 23: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 24: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 25: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 26: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 27: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 28: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 29: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 30: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 31: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 32: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 33: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 34: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 35: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 36: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 37: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 38: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 39: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 40: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 41: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 42: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 43: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 44: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 45: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 46: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 47: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 48: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 49: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 50: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 51: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 52: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 53: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 54: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 55: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 56: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 57: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 58: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 59: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 60: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 61: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 62: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 63: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 64: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 65: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 66: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 67: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 68: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 69: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 70: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 71: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 72: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 73: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 74: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 75: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 76: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 77: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 78: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 79: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 80: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 81: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 82: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 83: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 84: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 85: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 86: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 87: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 88: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 89: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 90: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 91: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 92: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 93: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 94: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 95: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 96: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 97: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 98: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 99: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 100: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 101: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 102: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 103: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 104: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 105: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 106: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 107: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 108: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 109: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 110: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 111: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 112: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 113: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 114: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 115: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 116: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 117: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 118: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 119: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 120: Cost checkpoint

- **Why it matters:** Model HA, replicas, storage growth, and inter-region traffic before production approval.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 121: Migration checkpoint

- **Why it matters:** Confirm source engine version, extension compatibility, collation behavior, and cutover rollback options.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 122: DNS checkpoint

- **Why it matters:** Use low TTLs for endpoint hostnames that may move during failover or DR promotion.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 123: Networking checkpoint

- **Why it matters:** Keep a diagram of source subnets, PSA ranges, PSC endpoints, VPN/Interconnect links, and DNS zones.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 124: Security checkpoint

- **Why it matters:** Separate runtime identities from human admin identities and audit both.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 125: Operations checkpoint

- **Why it matters:** Document restore steps, not just backup schedules.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 126: Performance checkpoint

- **Why it matters:** Track connections, CPU, memory, disk throughput, and query latency together.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 127: Hybrid checkpoint

- **Why it matters:** Validate return routing from Google Cloud to on-prem before opening the change window.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 128: Application checkpoint

- **Why it matters:** Tune connection pooling for autoscaling services to avoid overwhelming the database.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.

### Reference note 129: Compliance checkpoint

- **Why it matters:** Pair CMEK with key rotation, break-glass access, and evidence collection plans.
- **Recommended action:** Review this item during design review, before cutover, and after major topology changes.
- **Evidence to capture:** Screenshots or IaC references, validation commands, and alert coverage.
- **Owner:** Platform engineering, networking, security, and application teams must agree on accountability.
