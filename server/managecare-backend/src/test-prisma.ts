import { prisma } from "./lib/prisma";

async function main() {
  const result = await prisma.$queryRaw`SELECT current_database() AS database`;

  console.log("Prisma connection successful:");
  console.log(result);
}

main()
  .catch((error) => {
    console.error("Prisma test failed:");
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
