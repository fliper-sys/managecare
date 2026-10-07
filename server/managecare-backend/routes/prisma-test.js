const express = require('express');
const router = express.Router();
const { getPrisma } = require('../src/lib/prisma-bridge');

router.get('/businesses', async (req, res) => {
  try {
    const prisma = await getPrisma();

    const businesses = await prisma.businesses.findMany({
      select: {
        id: true,
        name: true,
      },
      take: 10,
      orderBy: {
        created_at: 'desc',
      },
    });

    res.json({
      success: true,
      count: businesses.length,
      businesses,
    });
  } catch (error) {
    console.error('[Prisma Test]', error);

    res.status(500).json({
      success: false,
      message: 'Prisma query failed',
      error: error.message,
    });
  }
});

module.exports = router;
