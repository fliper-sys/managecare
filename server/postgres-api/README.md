# ManageCare PostgreSQL API

This backend service provides a PostgreSQL API for the Manage Care app. It can run locally, in Docker, or on an Ubuntu VPS.

## Folder structure

- `src/` - Node.js Express API source code
- `migration/` - Firestore to PostgreSQL migration script
- `schema.sql` - PostgreSQL schema for core tables
- `docker-compose.yml` - Local Docker deployment for API + PostgreSQL

## Ubuntu PostgreSQL setup commands

Run these commands on your Ubuntu VPS to install PostgreSQL, create the database, and enable a service user:

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo -u postgres createuser --interactive
# enter: managecare
# no superuser, no createdb, no createrole, no replication
sudo -u postgres psql -c "ALTER USER managecare WITH ENCRYPTED PASSWORD 'YOUR_STRONG_PASSWORD';"
sudo -u postgres createdb managecare --owner=managecare
```

For remote access, edit `/etc/postgresql/16/main/postgresql.conf` and set:

```text
listen_addresses = '*'
```

Then add this line to `/etc/postgresql/16/main/pg_hba.conf`:

```text
host    managecare    managecare    0.0.0.0/0    md5
```

Restart PostgreSQL:

```bash
sudo systemctl restart postgresql
```

## Environment variables

Create `.env` from the example and set values:

```bash
cp .env.example .env
```

Required variables:

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `FIREBASE_SERVICE_ACCOUNT_PATH`
- `PORT`

## Install dependencies

```bash
npm install
```

## Create the database schema

```bash
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f schema.sql
```

## Run the API locally

```bash
npm start
```

## Run the API with Docker

```bash
docker compose up --build
```

## Firestore migration

1. Install required dependencies:

```bash
npm install
```

2. Set `FIREBASE_SERVICE_ACCOUNT_PATH` in `.env` to your Firebase service account JSON path.

3. Run the migration script:

```bash
npm run migrate
```

## Endpoints

- GET /health
- GET /products
- POST /products
- PUT /products/:id
- DELETE /products/:id
- GET /businesses
- POST /businesses
- PUT /businesses/:id
- DELETE /businesses/:id
- GET /users
- POST /users
- PUT /users/:id
- DELETE /users/:id
- GET /sales
- POST /sales
- PUT /sales/:id
- PATCH /sales/:id
- DELETE /sales/:id
- PATCH /sale-items/:id
- GET /procurements
- POST /procurements
- PUT /procurements/:id
- PATCH /procurements/:id
- DELETE /procurements/:id
- PATCH /procurement-items/:id
 - DELETE /sale-items/:id
 - DELETE /procurement-items/:id

## Notes

- The migration script assumes Firestore collections named `businesses`, `inventory`, `sales`, and `procurements`.
- Adjust field mappings if your Firestore document structure differs.
- Use a secure password and restrict access when deploying to production.
