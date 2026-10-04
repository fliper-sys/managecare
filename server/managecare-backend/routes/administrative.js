/**
 * Administrative management API routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');
const { getPrisma } = require('../src/lib/prisma-bridge');
    
    router.get('/:businessId/dashboard', pagination, asyncHandler(async (req, res) => {
        const prisma = await getPrisma();
        const result = await prisma.business.findUnique({
            where: {
                id: req.params.businessId
            },
            include: {
                clients: true,
                obligations: true,
                tasks: true
            }
        });
        res.json({ data: result });
    }));

    router.get('/:businessId/clients', pagination, asyncHandler(async (req, res) => {
            const prisma = await getPrisma();
            const result = await prisma.client.findMany({
                where: {
                    businessId: req.params.businessId
                },
                orderBy: {
                    name: 'asc'
                }
            });
            res.json({ data: result });
    }));

    router.post('/:businessId/clients', asyncHandler(async (req, res) => {

    }));
    router.get('/:businessId/clients/:clientId', pagination, asyncHandler(async (req, res) => {
        const prisma = await getPrisma();
        const result = await prisma.client.find({
            where:{
                businessId: req.params.businessId,
                clientId: req.params.clientId
            }
        })
        res.json({data:result})
    }));
    router.patch('/:businessId/clients/:clientId', pagination, asyncHandler(async (req, res) => {}));
    router.delete('/:businessId/clients/:clientId', pagination, asyncHandler(async (req, res) => {}));
    router.put('/:businessId/clients/:clientId', pagination, asyncHandler(async (req, res) => {}));
    router.delete('/:businessId/clients/:clientId', pagination, asyncHandler(async (req, res) => {}));
    router.get('/:businessId/clients/:clientId/folders', pagination, asyncHandler(async (req, res) => {
        const prisma = await getPrisma();
        const result = await prisma.folder.findMany({
            where: {
                businessId: req.params.businessId,
                clientId: req.params.clientId
            }
        });
        res.json({ data: result });
    }));
    router.post('/:businessId/clients/:clientId/folders', pagination, asyncHandler(async (req, res) => {}));
    router.get('/:businessId/clients/:clientId/documents', pagination, asyncHandler(async (req, res) => {
        const prisma = await getPrisma();
        const result = await prisma.document.findMany({
            where: {
                businessId: req.params.businessId,
                clientId: req.params.clientId
            }
        });
        res.json({ data: result });
    }));
    router.post('/:businessId/clients/:clientId/documents', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/documents/:documentId/assignments', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/tasks/:taskId/submit', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/tasks/:taskId/review', pagination, asyncHandler(async (req, res) => {}));
    router.get('/:businessId/obligations', pagination, asyncHandler(async (req, res) => {
        const prisma = await getPrisma();
        const result = await prisma.obligation.findMany({
            where: {
                businessId: req.params.businessId
            }
        });
        res.json({ data: result });
    }));
    router.post('/:businessId/obligations', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/obligations/:id/complete', pagination, asyncHandler(async (req, res) => {}));
    router.get('/:businessId/tasks', pagination, asyncHandler(async (req, res) => {
        const prisma = await getPrisma();
        const result = await prisma.task.findMany({
            where: {
                businessId: req.params.businessId
            }
        });
        res.json({ data: result });
    }));
    router.post('/:businessId/tasks', pagination, asyncHandler(async (req, res) => {}));

module.exports = router;