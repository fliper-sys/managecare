/**
 * Authentication middleware for ManageCare API.
 * Verifies JWT tokens issued by GoTrue (Supabase Auth).
 */
const jwt = require('jsonwebtoken');

/**
 * Express middleware: validates Bearer token and attaches user to req.
 * If using GoTrue JWTs, they use HS256 with the JWT_SECRET from env.
 */
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: 'No authorization header' });
  }

  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({ error: 'Invalid authorization format. Use: Bearer <token>' });
  }

  const token = parts[1];

  try {
    // Verify against the JWT secret configured for GoTrue
    const decoded = jwt.verify(token, process.env.JWT_SECRET, {
      algorithms: ['HS256'],
    });

    // GoTrue JWTs have `sub` (user id), `role`, `email`, and `aud`
    req.user = {
      id: decoded.sub || decoded.id,
      email: decoded.email,
      role: decoded.role || 'authenticated',
      // Support both Supabase anon key (role: 'anon') and authenticated users
      isAnon: decoded.role === 'anon',
    };

    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token has expired. Please sign in again.' });
    }
    if (err.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Invalid token' });
    }
    return res.status(500).json({ error: 'Authentication error' });
  }
}

/**
 * Middleware: requires the user to be authenticated (not anonymous/anonymous key).
 */
function requireAuth(req, res, next) {
  if (!req.user || req.user.isAnon) {
    return res.status(401).json({ error: 'Authentication required. Sign in first.' });
  }
  next();
}

/**
 * Middleware: requires the user to have a specific role.
 */
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: `Requires one of roles: ${roles.join(', ')}` });
    }
    next();
  };
}

/**
 * Middleware: requires the user to be a member of the business in the request.
 * Checks if user_id exists in business_members for the given business_id.
 * Business ID can come from req.params.businessId, req.query.businessId, or req.body.businessId.
 */
function requireBusinessMembership(pool) {
  return async (req, res, next) => {
    if (req.user.isAnon) {
      // Anonymous/anonymous key can't access business-scoped data without RLS
      return res.status(401).json({ error: 'Authentication required for business access' });
    }

    const businessId = req.params.businessId || req.query.businessId || req.body.businessId;
    if (!businessId) {
      return res.status(400).json({ error: 'businessId is required' });
    }

    try {
      const result = await pool.query(
        'SELECT id FROM business_members WHERE user_id = $1 AND business_id = $2 AND is_active = true',
        [req.user.id, businessId]
      );

      if (result.rows.length === 0) {
        return res.status(403).json({ error: 'You are not a member of this business' });
      }

      req.businessMembership = result.rows[0];
      next();
    } catch (err) {
      console.error('[AuthMiddleware] Error checking membership:', err);
      return res.status(500).json({ error: 'Failed to verify business membership' });
    }
  };
}

module.exports = {
  authMiddleware,
  requireAuth,
  requireRole,
  requireBusinessMembership,
};

