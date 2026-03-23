/**
 * Bearer token auth middleware.
 * If PERSONAL_TOKEN is not set in env, auth is skipped (dev mode).
 * Otherwise, the request must carry: Authorization: Bearer <token>
 */
function authMiddleware(req, res, next) {
  const token = process.env.PERSONAL_TOKEN;

  // Dev mode – no token configured, skip auth
  if (!token) {
    return next();
  }

  const authHeader = req.headers['authorization'] || '';
  const parts = authHeader.split(' ');

  if (parts.length !== 2 || parts[0].toLowerCase() !== 'bearer') {
    return res.status(401).json({ error: 'Unauthorized: missing or malformed Authorization header' });
  }

  if (parts[1] !== token) {
    return res.status(401).json({ error: 'Unauthorized: invalid token' });
  }

  next();
}

module.exports = authMiddleware;
