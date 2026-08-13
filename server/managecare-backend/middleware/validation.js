/**
 * Request validation middleware for ManageCare API.
 */

/**
 * Validates that required fields are present in the request body.
 * @param {...string} fields - Field names that are required.
 * @returns {Function} Express middleware
 */
function requireFields(...fields) {
  return (req, res, next) => {
    const missing = fields.filter(f => {
      const val = req.body[f];
      return val === undefined || val === null || (typeof val === 'string' && val.trim() === '');
    });

    if (missing.length > 0) {
      return res.status(400).json({
        error: `Missing required fields: ${missing.join(', ')}`,
      });
    }
    next();
  };
}

/**
 * Validates that the businessId is present in params, query, or body.
 */
function requireBusinessId(req, res, next) {
  const businessId = req.params.businessId || req.query.businessId || req.body.businessId;
  if (!businessId) {
    return res.status(400).json({ error: 'businessId is required' });
  }
  req.businessId = businessId;
  next();
}

/**
 * Pagination middleware: parses page and limit from query params.
 * Attaches parsed values to req.pagination.
 */
function pagination(req, res, next) {
  const page = Math.max(1, parseInt(req.query.page) || 1);
  // Raised from 100: every route using this middleware does a plain
  // single-table filter/sort/limit (sales.js's item join now happens after
  // paging, not before - see that route), so a bigger page is still a cheap,
  // index-backed query. The real cost for a 1000+ row business/1000+ item
  // catalog was never per-row - it was the round-trip count: 100/page meant
  // ~11-24 sequential/batched HTTP requests just to pull one full catalog or
  // sales history. A 500 cap cuts that to ~3-5 for the same data.
  const limit = Math.min(500, Math.max(1, parseInt(req.query.limit) || 50));
  const offset = (page - 1) * limit;

  req.pagination = { page, limit, offset };
  next();
}

/**
 * Wraps an async route handler to catch errors and pass them to Express error handler.
 */
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

/**
 * Global error handler middleware.
 */
function errorHandler(err, req, res, next) {
  console.error('[API Error]', err);

  if (err.code === '23505') {
    // Unique violation
    return res.status(409).json({ error: 'A record with this value already exists' });
  }
  if (err.code === '23503') {
    // Foreign key violation
    return res.status(400).json({ error: 'Referenced record does not exist' });
  }
  if (err.code === '42P01') {
    // Undefined table
    return res.status(500).json({ error: 'Internal server configuration error' });
  }

  const statusCode = err.statusCode || 500;
  const message = err.expose ? err.message : 'Internal server error';
  res.status(statusCode).json({ error: message });
}

module.exports = {
  requireFields,
  requireBusinessId,
  pagination,
  asyncHandler,
  errorHandler,
};

