let prismaPromise;

function getPrisma() {
  if (!prismaPromise) {
    prismaPromise = import('./prisma.ts').then((module) => {
      return module.prisma || module.default?.prisma;
    });
  }

  return prismaPromise;
}

module.exports = {
  getPrisma,
};