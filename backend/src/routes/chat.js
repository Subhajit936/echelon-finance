const express = require('express');
const { body, validationResult } = require('express-validator');
const ChatMessage = require('../models/ChatMessage');

const router = express.Router();

function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const err = new Error('Validation failed');
    err.status = 422;
    err.details = errors.array();
    return next(err);
  }
  next();
}

// ─── GET /api/chat ────────────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  const limit = Math.max(1, Math.min(500, parseInt(req.query.limit) || 50));

  // Retrieve in ascending order for chat display (oldest first)
  const messages = await ChatMessage.find()
    .sort({ timestamp: -1 })
    .limit(limit)
    .lean();

  // Return in chronological order
  messages.reverse();

  res.json(messages);
});

// ─── POST /api/chat ───────────────────────────────────────────────────────────
router.post(
  '/',
  [
    body('_id').notEmpty().withMessage('_id is required'),
    body('role').isIn(['user', 'assistant']).withMessage('role must be user or assistant'),
    body('content').notEmpty().withMessage('content is required')
  ],
  validate,
  async (req, res) => {
    const { _id, role, content, intent, timestamp, parsedTransactionId, isError } = req.body;

    const message = new ChatMessage({
      _id,
      role,
      content,
      intent: intent || '',
      timestamp: timestamp ? new Date(Number(timestamp)) : new Date(),
      parsedTransactionId: parsedTransactionId || null,
      isError: isError || false
    });

    await message.save();
    res.status(201).json(message);
  }
);

// ─── DELETE /api/chat ─────────────────────────────────────────────────────────
router.delete('/', async (req, res) => {
  const result = await ChatMessage.deleteMany({});
  res.json({ deleted: true, count: result.deletedCount });
});

module.exports = router;
