const { getPrisma } = require('./lib/prisma-bridge');

async function main() {
  const prisma = await getPrisma();

  const result = await prisma.$queryRaw`
    SELECT current_database() AS database
  `;

  console.log('Prisma bridge successful:');
  console.log(result);

  await prisma.$disconnect();
}

main().catch((error) => {
  console.error('Prisma bridge failed:');
  console.error(error);
  process.exit(1);
});
