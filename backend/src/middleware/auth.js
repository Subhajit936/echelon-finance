const jwt = require('jsonwebtoken');

/**
 * Auth middleware: accepts either
 *   1. A valid JWT signed with JWT_SECRET, or
 *   2. The raw PERSONAL_TOKEN (admin / legacy bypass)
 */
function authMiddleware(req, res, next) {
  const authHeader = req.headers['authorization'] || '';
  const parts = authHeader.split(' ');

  if (parts.length !== 2 || parts[0].toLowerCase() !== 'bearer') {
    return res.status(401).json({ error: 'Authorization required' });
  }

  const token = parts[1];

  // PERSONAL_TOKEN bypass (admin / testing)
  if (process.env.PERSONAL_TOKEN && token === process.env.PERSONAL_TOKEN) {
    req.userId = 'admin';
    return next();
  }

  // JWT verification
  const secret = process.env.JWT_SECRET || 'echelon-dev-secret-change-in-prod';
  try {
    const decoded = jwt.verify(token, secret);
    req.userId = decoded.userId;
    next();
  } catch {
    res.status(401).json({ error: 'Session expired. Please log in again.' });
  }
}

module.exports = authMiddleware;
