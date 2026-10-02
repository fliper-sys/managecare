/**
 * Administrative management API routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const { requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function(pool){
    router.use('/:businessId', requireBusinessMembership(pool));

    router.get('/:businessId/dashboard', pagination, asyncHandler(async (req, res) => {
        
    }));
    router.get('/:businessId/clients', pagination, asyncHandler(async (req, res) => {
            const result = await pool.query(
      'SELECT * FROM clients WHERE business_id = $1 ORDER BY name ASC',
      [req.params.businessId]
    );
    res.json({ data: result.rows });
    }));
    router.post('/:businessId/clients', asyncHandler(async (req, res) => {
        
    }));
    router.get('/:businessId/clients/:clientId', pagination, asyncHandler(async (req, res) => {}));
    router.patch('/:businessId/clients/:clientId', pagination, asyncHandler(async (req, res) => {}));
    router.delete('/:businessId/clients/:clientId', pagination, asyncHandler(async (req, res) => {}));
    router.put('/:businessId/clients/:clientId', pagination, asyncHandler(async (req, res) => {}));
    router.delete('/:businessId/clients/:clientId', pagination, asyncHandler(async (req, res) => {}));
    router.get('/:businessId/clients/:clientId/folders', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/clients/:clientId/folders', pagination, asyncHandler(async (req, res) => {}));
    router.get('/:businessId/clients/:clientId/documents', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/clients/:clientId/documents', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/documents/:documentId/assignments', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/tasks/:taskId/submit', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/tasks/:taskId/review', pagination, asyncHandler(async (req, res) => {}));
    router.get('/:businessId/obligations', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/obligations', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/obligations/:id/complete', pagination, asyncHandler(async (req, res) => {}));
    router.get('/:businessId/tasks', pagination, asyncHandler(async (req, res) => {}));
    router.post('/:businessId/tasks', pagination, asyncHandler(async (req, res) => {}));




}