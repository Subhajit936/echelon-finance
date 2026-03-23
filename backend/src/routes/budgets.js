const express = require('express');
const { body, param, validationResult } = require('express-validator');
const Budget = require('../models/Budget');
const Transaction = require('../models/Transaction');
const { v4: uuidv4 } = require('uuid');

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

// ─── GET /api/budgets/current ─────────────────────────────────────────────────
// Returns budgets whose period contains today, with spent amount from transactions
router.get('/current', async (req, res) => {
  const now = new Date();

  const budgets = await Budget.find({
    periodStart: { $lte: now },
    periodEnd: { $gte: now }
  }).lean();

  if (budgets.length === 0) {
    return res.json([]);
  }

  // Find the overall date range that covers all budgets
  const earliestStart = budgets.reduce((min, b) => b.periodStart < min ? b.periodStart : min, budgets[0].periodStart);
  const latestEnd = budgets.reduce((max, b) => b.periodEnd > max ? b.periodEnd : max, budgets[0].periodEnd);

  // Aggregate expense totals per category within the widest period
  const spentAgg = await Transaction.aggregate([
    {
      $match: {
        type: 'expense',
        date: { $gte: new Date(earliestStart), $lte: new Date(latestEnd) }
      }
    },
    {
      $group: {
        _id: '$category',
        spent: { $sum: '$amount' }
      }
    }
  ]);

  const spentMap = {};
  spentAgg.forEach((s) => {
    spentMap[s._id] = s.spent;
  });

  // Attach spent to each budget — only count transactions within that budget's period
  const budgetsWithSpent = await Promise.all(
    budgets.map(async (b) => {
      const [agg] = await Transaction.aggregate([
        {
          $match: {
            type: 'expense',
            category: b.category,
            date: { $gte: new Date(b.periodStart), $lte: new Date(b.periodEnd) }
          }
        },
        { $group: { _id: null, spent: { $sum: '$amount' } } }
      ]);
      return { ...b, spent: agg ? agg.spent : 0 };
    })
  );

  res.json(budgetsWithSpent);
});

// ─── POST /api/budgets ────────────────────────────────────────────────────────
// Upsert budget by category (replaces existing budget for same category)
router.post(
  '/',
  [
    body('category')
      .isIn(['food', 'transport', 'housing', 'utilities', 'entertainment', 'healthcare', 'education', 'shopping', 'salary', 'freelance', 'investment', 'other'])
      .withMessage('invalid category'),
    body('limitAmount').isFloat({ min: 0 }).withMessage('limitAmount must be a non-negative number'),
    body('periodStart').notEmpty().withMessage('periodStart is required'),
    body('periodEnd').notEmpty().withMessage('periodEnd is required')
  ],
  validate,
  async (req, res) => {
    const { _id, category, limitAmount, periodStart, periodEnd, currency } = req.body;

    const id = _id || uuidv4();

    // Upsert: if a budget for this category already exists, update fields only.
    // _id must not be included in $set on an existing doc — use $setOnInsert.
    const budget = await Budget.findOneAndUpdate(
      { category },
      {
        $set: {
          category,
          limitAmount: Number(limitAmount),
          periodStart: new Date(Number(periodStart)),
          periodEnd: new Date(Number(periodEnd)),
          currency: currency || 'INR'
        },
        $setOnInsert: { _id: id }
      },
      { upsert: true, new: true, runValidators: true }
    );

    res.status(201).json(budget);
  }
);

// ─── PUT /api/budgets/:id ─────────────────────────────────────────────────────
router.put(
  '/:id',
  [
    param('id').notEmpty().withMessage('id is required'),
    body('limitAmount').optional().isFloat({ min: 0 }).withMessage('limitAmount must be a non-negative number'),
    body('category').optional().isIn(['food', 'transport', 'housing', 'utilities', 'entertainment', 'healthcare', 'education', 'shopping', 'salary', 'freelance', 'investment', 'other']).withMessage('invalid category'),
  ],
  validate,
  async (req, res) => {
    const { category, limitAmount, periodStart, periodEnd, currency } = req.body;
    const updates = {};
    if (category !== undefined) updates.category = category;
    if (limitAmount !== undefined) updates.limitAmount = Number(limitAmount);
    if (periodStart !== undefined) updates.periodStart = new Date(Number(periodStart));
    if (periodEnd !== undefined) updates.periodEnd = new Date(Number(periodEnd));
    if (currency !== undefined) updates.currency = currency;

    const updated = await Budget.findByIdAndUpdate(req.params.id, updates, { new: true });
    if (!updated) return res.status(404).json({ error: 'Budget not found' });
    res.json(updated);
  }
);

// ─── DELETE /api/budgets/:id ──────────────────────────────────────────────────
router.delete(
  '/:id',
  [param('id').notEmpty().withMessage('id is required')],
  validate,
  async (req, res) => {
    const deleted = await Budget.findByIdAndDelete(req.params.id);
    if (!deleted) {
      return res.status(404).json({ error: 'Budget not found' });
    }
    res.json({ deleted: true, id: req.params.id });
  }
);

module.exports = router;
