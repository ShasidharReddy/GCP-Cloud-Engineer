
# Database Migration Service (DMS) — MySQL to Cloud SQL

This guide walks through setting up a MySQL source database on a GCE VM, then migrating it to Cloud SQL using Google's Database Migration Service.

---

## Prerequisites

- A GCE VM instance (Debian/Ubuntu) for the MySQL source
- A GCP project with billing enabled

```bash
gcloud services enable compute.googleapis.com
gcloud services enable datamigration.googleapis.com
gcloud services enable sqladmin.googleapis.com
```

---

## Step-by-Step Instructions

### Step 1. Install MySQL Server

```bash
sudo apt update
sudo apt install mysql-server -y
```

---

### Step 2. Secure MySQL (Optional but Recommended)

```bash
sudo mysql_secure_installation
```

You can skip this or configure:

* Press `Enter` to skip root password setup (or set if prompted)
* Remove anonymous users → Yes
* Disallow remote root login → No
* Remove test DB → Yes
* Reload privilege tables → Yes

---

### Step 3. Log in to MySQL as Root

```bash
sudo mysql
```

Then inside the MySQL shell, run:

```sql
-- Create user 'siva' with password
CREATE USER 'siva'@'%' IDENTIFIED BY 'YOUR_OWN_PASSWORD';

-- Grant all permissions
GRANT ALL PRIVILEGES ON *.* TO 'siva'@'%' WITH GRANT OPTION;

-- Save changes
FLUSH PRIVILEGES;

-- Exit MySQL
EXIT;
```

---

### Step 4. Allow Remote Connections

Edit the MySQL config:

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Look for:

```
bind-address = 127.0.0.1
```

Change it to:

```
bind-address = 0.0.0.0
```

Save and exit: `Ctrl+O`, `Enter`, `Ctrl+X`

---

### Step 5. Restart MySQL

```bash
sudo systemctl restart mysql
```

---

### Step 6. Allow Port 3306 in Cloud Firewall

Open **port 3306** in your cloud firewall:

**GCP:**
```bash
gcloud compute firewall-rules create allow-mysql \
    --allow=tcp:3306 --source-ranges=0.0.0.0/0 \
    --network=default --priority=1000
```

> ⚠️ **Security**: In production, restrict `--source-ranges` to specific IPs (e.g., Cloud SQL's outbound IP) instead of `0.0.0.0/0`.

---

### Step 7. Test Remote Connection

From your local or any remote machine:

```bash
mysql -u siva -p -h <your-server-ip>
# Enter password: YOUR_OWN_PASSWORD
```

---

### Step 8. Create Database, Table & Insert Records

#### 🔹 Log in to MySQL as User `siva`

```bash
mysql -u siva -p -h <your-server-ip>
```

#### 🔹 Create a Database

```sql
CREATE DATABASE i27academy;
```

#### 🔹 Use the Database

```sql
USE i27academy;
```

#### 🔹 Create a Table

```sql
CREATE TABLE students (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(100),
  course VARCHAR(100)
);
```

#### 🔹 Insert Records

```sql
INSERT INTO students (name, email, course)
VALUES 
('John Doe', 'john@example.com', 'DevOps'),
('Sita Rani', 'sita@example.com', 'GCP'),
('Ravi Kumar', 'ravi@example.com', 'Terraform');
```

#### 🔹 View All Records

```sql
SELECT * FROM students;
```

Expected Output:

```
+----+------------+------------------+------------+
| id | name       | email            | course     |
+----+------------+------------------+------------+
|  1 | John Doe   | john@example.com | DevOps     |
|  2 | Sita Rani  | sita@example.com | GCP        |
|  3 | Ravi Kumar | ravi@example.com | Terraform  |
+----+------------+------------------+------------+
```

---
### Step 9. Implement DMS (Database Migration Service)

Once the source MySQL is running with data, set up DMS to migrate to Cloud SQL:

#### 9a. Create a Cloud SQL Destination Instance

```bash
gcloud sql instances create mysql-destination \
    --database-version=MYSQL_8_0 \
    --tier=db-n1-standard-1 \
    --region=us-central1
```

#### 9b. Create a Connection Profile for the Source

In the GCP Console:
1. Navigate to **Database Migration** → **Connection profiles**
2. Click **Create profile**
3. Select **MySQL** as the database engine
4. Enter the source VM's **external IP**, port `3306`, username `siva`, and password
5. Test the connection and save

#### 9c. Create a Migration Job

1. Go to **Database Migration** → **Migration jobs** → **Create migration job**
2. Select:
   - **Source**: the connection profile created above
   - **Destination**: `mysql-destination` Cloud SQL instance
   - **Migration type**: Continuous (CDC) or One-time
3. Test the job, then **Start** it

#### 9d. Verify Migration

```bash
# Connect to Cloud SQL
gcloud sql connect mysql-destination --user=root

# Check the data
USE i27academy;
SELECT * FROM students;
```

#### 9e. Promote the Destination (for cutover)

Once replication is caught up:
1. Go to the migration job in Console
2. Click **Promote** to make Cloud SQL the primary

---

### Step 10. Insert Additional Records After Migration

The records below are useful to test read/write transactions after DMS is completed:

```sql
INSERT INTO students (name, email, course)
VALUES 
('Amit Sharma', 'amit.sharma@example.com', 'Docker & Kubernetes'),
('Priya Nair', 'priya.nair@example.com', 'Cloud Security'),
('Rahul Verma', 'rahul.verma@example.com', 'Azure DevOps'),
('Neha Singh', 'neha.singh@example.com', 'Python for Automation'),
('Karthik Reddy', 'karthik.reddy@example.com', 'Linux Fundamentals');
```
