/**
 * File upload / MinIO storage API routes for ManageCare.
 */
const express = require('express');
const router = express.Router();
const multer = require('multer');
const { requireBusinessId, requireFields, asyncHandler } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

// Configure multer for memory storage (we'll forward to MinIO)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB max
  fileFilter: (req, file, cb) => {
    const allowedMimes = [
      'image/jpeg', 'image/png', 'image/gif', 'image/webp',
      'application/pdf',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'text/csv',
    ];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`File type ${file.mimetype} not allowed`), false);
    }
  },
});

module.exports = function(pool, minioClient, minioPublicClient = minioClient) {
  router.use('/:businessId', requireBusinessMembership(pool));

  // POST /api/upload/:businessId - Upload file
  router.post('/:businessId', upload.single('file'), asyncHandler(async (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const { businessId } = req.params;
    const { folder } = req.body;

    // Generate unique filename
    const timestamp = Date.now();
    const ext = req.file.originalname.split('.').pop();
    const filename = `${businessId}/${folder || 'uploads'}/${timestamp}-${Math.random().toString(36).substring(2, 8)}.${ext}`;

    if (minioClient) {
      // Upload to MinIO
      await minioClient.putObject(
        process.env.MINIO_BUCKET || 'managecare-files',
        filename,
        req.file.buffer,
        req.file.size,
        { 'Content-Type': req.file.mimetype }
      );

      // Return a URL clients can actually reach even when MinIO is private or
      // its endpoint is only visible inside the server network.
      const url = await minioPublicClient.presignedGetObject(
        process.env.MINIO_BUCKET || 'managecare-files',
        filename,
        7 * 24 * 60 * 60,
      );

      return res.status(201).json({
        url,
        filename,
        originalName: req.file.originalname,
        size: req.file.size,
        mimetype: req.file.mimetype,
      });
    }

    // Fallback: return base64 for direct use (useful during transition)
    const base64 = req.file.buffer.toString('base64');
    const dataUrl = `data:${req.file.mimetype};base64,${base64}`;

    return res.status(201).json({
      url: dataUrl,
      filename,
      originalName: req.file.originalname,
      size: req.file.size,
      mimetype: req.file.mimetype,
      note: 'Stored as base64. Configure MinIO for production file storage.',
    });
  }));

  // GET /api/upload/:businessId/:filename - Get file metadata
  router.get('/:businessId/:filename', asyncHandler(async (req, res) => {
    const { businessId, filename } = req.params;

    if (minioClient) {
      try {
        const stat = await minioClient.statObject(
          process.env.MINIO_BUCKET || 'managecare-files',
          `${businessId}/uploads/${filename}`
        );
        return res.json({
          filename,
          size: stat.size,
          mimetype: stat.metaData?.['content-type'],
          lastModified: stat.lastModified,
        });
      } catch (err) {
        if (err.code === 'NotFound') {
          return res.status(404).json({ error: 'File not found' });
        }
        throw err;
      }
    }

    res.status(501).json({ error: 'MinIO not configured' });
  }));

  return router;
};

