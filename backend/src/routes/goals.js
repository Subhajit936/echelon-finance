const express = require('express');
const { body, param, validationResult } = require('express-validator');
const Goal = require('../models/Goal');

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

// ─── GET /api/goals ───────────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  const goals = await Goal.find().sort({ createdAt: -1 }).lean();
  res.json(goals);
});

// ─── GET /api/goals/active ────────────────────────────────────────────────────
router.get('/active', async (req, res) => {
  const goals = await Goal.find({ status: 'active' }).sort({ createdAt: -1 }).lean();
  res.json(goals);
});

// ─── POST /api/goals ──────────────────────────────────────────────────────────
router.post(
  '/',
  [
    body('_id').notEmpty().withMessage('_id is required'),
    body('name').notEmpty().withMessage('name is required'),
    body('targetAmount').isFloat({ min: 0 }).withMessage('targetAmount must be a non-negative number')
  ],
  validate,
  async (req, res) => {
    const { _id, name, emoji, targetAmount, currentAmount, targetDate, dailyTarget, status, currency } = req.body;

    const goal = new Goal({
      _id,
      name,
      emoji: emoji || '',
      targetAmount: Number(targetAmount),
      currentAmount: currentAmount != null ? Number(currentAmount) : 0,
      targetDate: targetDate ? new Date(Number(targetDate)) : null,
      dailyTarget: dailyTarget != null ? Number(dailyTarget) : 0,
      status: status || 'active',
      currency: currency || 'INR'
    });

    await goal.save();
    res.status(201).json(goal);
  }
);

// ─── PUT /api/goals/:id ───────────────────────────────────────────────────────
router.put(
  '/:id',
  [param('id').notEmpty().withMessage('id is required')],
  validate,
  async (req, res) => {
    const { name, emoji, targetAmount, currentAmount, targetDate, dailyTarget, status, currency } = req.body;

    const update = {};
    if (name !== undefined) update.name = name;
    if (emoji !== undefined) update.emoji = emoji;
    if (targetAmount !== undefined) update.targetAmount = Number(targetAmount);
    if (currentAmount !== undefined) update.currentAmount = Number(currentAmount);
    if (targetDate !== undefined) update.targetDate = targetDate ? new Date(Number(targetDate)) : null;
    if (dailyTarget !== undefined) update.dailyTarget = Number(dailyTarget);
    if (status !== undefined) update.status = status;
    if (currency !== undefined) update.currency = currency;

    const goal = await Goal.findByIdAndUpdate(req.params.id, { $set: update }, { new: true, runValidators: true });
    if (!goal) {
      return res.status(404).json({ error: 'Goal not found' });
    }
    res.json(goal);
  }
);

// ─── DELETE /api/goals/:id ────────────────────────────────────────────────────
router.delete(
  '/:id',
  [param('id').notEmpty().withMessage('id is required')],
  validate,
  async (req, res) => {
    const deleted = await Goal.findByIdAndDelete(req.params.id);
    if (!deleted) {
      return res.status(404).json({ error: 'Goal not found' });
    }
    res.json({ deleted: true, id: req.params.id });
  }
);

// ─── POST /api/goals/:id/contribute ───────────────────────────────────────────
router.post(
  '/:id/contribute',
  [
    param('id').notEmpty().withMessage('id is required'),
    body('amount').isFloat({ min: 0.01 }).withMessage('amount must be a positive number')
  ],
  validate,
  async (req, res) => {
    const { amount } = req.body;

    const goal = await Goal.findById(req.params.id);
    if (!goal) {
      return res.status(404).json({ error: 'Goal not found' });
    }

    goal.currentAmount = (goal.currentAmount || 0) + Number(amount);

    // Auto-complete if target reached
    if (goal.currentAmount >= goal.targetAmount) {
      goal.status = 'completed';
    }

    await goal.save();
    res.json(goal);
  }
);

module.exports = router;
