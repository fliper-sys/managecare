import "dotenv/config";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../generated/prisma/client";

const connectionString = process.env.DATABASE_URL || (() => {
  const host = process.env.DB_HOST || process.env.PGHOST;
  const database = process.env.DB_NAME || process.env.DB_DATABASE || process.env.PGDATABASE;
  const username = process.env.DB_USER || process.env.DB_USERNAME || process.env.PGUSER;
  const password = process.env.DB_PASSWORD ?? process.env.DB_PASS ?? process.env.PGPASSWORD;

  if (!host || !database || !username) return undefined;

  const credentials = `${encodeURIComponent(username)}${password == null ? "" : `:${encodeURIComponent(password)}`}`;
  const port = process.env.DB_PORT || process.env.PGPORT || "5432";
  return `postgresql://${credentials}@${host}:${port}/${encodeURIComponent(database)}`;
})();

if (!connectionString) {
  throw new Error("Set DATABASE_URL or configure DB_HOST, DB_USER, and DB_NAME");
}

const adapter = new PrismaPg({
  connectionString,
});

export const prisma = new PrismaClient({
  adapter,
});
