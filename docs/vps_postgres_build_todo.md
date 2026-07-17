# VPS PostgreSQL Build To-Do Plan

## Environment
- VPS OS: Ubuntu
- Database: PostgreSQL
- Host: 127.0.0.1
- Port: 5432
- Database: managecare
- User: managecare
- Password: BqHjAf8aMMmhHhOlW0j6bYIj4T7Owrya

## Phase 1 - Server Preparation
- [ ] Update Ubuntu packages
  ```bash
  sudo apt update
  sudo apt upgrade -y
  ```
- [ ] Install PostgreSQL and PostgreSQL client tools
  ```bash
  sudo apt install -y postgresql postgresql-contrib
  ```
- [ ] Create the database `managecare`
  ```bash
  sudo -u postgres createdb managecare
  ```
- [ ] Create the user `managecare`
  ```bash
  sudo -u postgres createuser --interactive
  # choose managecare, no superuser, no createdb, no createrole, no replication
  ```
- [ ] Set the password for the database user
  ```bash
  sudo -u postgres psql -c "ALTER USER managecare WITH ENCRYPTED PASSWORD 'YOUR_STRONG_PASSWORD';"
  ```
- [ ] Grant privileges on the database to the user
  ```bash
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE managecare TO managecare;"
  ```
- [ ] Confirm PostgreSQL is listening on port 5432
  ```bash
  sudo systemctl status postgresql
  ss -tunlp | grep 5432
  ```

## Phase 2 - Database Schema
- [ ] Create `businesses` table
- [ ] Create `users` table
- [ ] Create `products` table
- [ ] Create `sales` table
- [ ] Create `sale_items` table
- [ ] Create `procurements` table
- [ ] Create `procurement_items` table
- [ ] Add primary keys and foreign keys
- [ ] Add indexes for lookup performance
- [ ] Add timestamps and audit fields

## Phase 3 - Backend API
- [ ] Create a backend project folder
- [ ] Install PostgreSQL driver dependency
- [ ] Create environment config using the provided DB values
- [ ] Create health check endpoint
- [ ] Create GET /products endpoint
- [ ] Create POST /products endpoint
- [ ] Create GET /sales endpoint
- [ ] Create POST /sales endpoint
- [ ] Create GET /procurements endpoint
- [ ] Create POST /procurements endpoint
- [ ] Add input validation
- [ ] Add error handling

## Phase 4 - Firestore Migration
- [ ] Export data from Firestore for one collection
- [ ] Transform the data into the PostgreSQL schema
- [ ] Insert the data into PostgreSQL
- [ ] Validate record counts
- [ ] Validate sample records
- [ ] Repeat for the next collection

## Phase 5 - Flutter Integration
- [ ] Create a private API client in the Flutter app
- [ ] Replace one inventory screen to read from the API
- [ ] Replace one sales flow to write to the API
- [ ] Add loading and error states
- [ ] Test the flow end to end

## Phase 6 - Security and Production Readiness
- [ ] Restrict PostgreSQL access to trusted IPs
- [ ] Use environment variables in the backend
- [ ] Add authentication to the API
- [ ] Add HTTPS and reverse proxy if needed
- [ ] Add backups for PostgreSQL
- [ ] Add logging and monitoring

## Phase 7 - Rollout
- [ ] Run migration in staging mode
- [ ] Compare Firebase and PostgreSQL data
- [ ] Switch one module to the private database
- [ ] Monitor for issues
- [ ] Expand to the next module

## Suggested First Milestone
Build and verify this first:
1. PostgreSQL running on Ubuntu
2. Database and user created
3. One products table populated
4. One API endpoint returning products
5. One Flutter screen reading from the API
