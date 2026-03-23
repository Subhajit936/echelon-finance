/**
 * Global error handler middleware.
 * Returns structured JSON error responses.
 */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  // Mongoose validation errors
  if (err.name === 'ValidationError') {
    const messages = Object.values(err.errors).map((e) => e.message);
    return res.status(400).json({ error: 'Validation error', details: messages });
  }

  // Mongoose duplicate key
  if (err.code === 11000) {
    return res.status(409).json({ error: 'Duplicate key', details: err.message });
  }

  // Mongoose cast errors (bad ObjectId / type mismatch)
  if (err.name === 'CastError') {
    return res.status(400).json({ error: 'Invalid field type', details: err.message });
  }

  // Express-validator errors forwarded manually
  if (err.status === 422) {
    return res.status(422).json({ error: 'Unprocessable entity', details: err.details });
  }

  const status = err.status || err.statusCode || 500;
  const message = err.message || 'Internal server error';

  if (process.env.NODE_ENV !== 'test') {
    console.error('[ErrorHandler]', err);
  }

  return res.status(status).json({ error: message });
}

module.exports = errorHandler;
