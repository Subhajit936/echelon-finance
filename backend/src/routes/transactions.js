const express = require('express');
const { body, query, param, validationResult } = require('express-validator');
const Transaction = require('../models/Transaction');

const router = express.Router();

// Helper – throw a 422 if express-validator found errors
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

// ─── POST /api/transactions ───────────────────────────────────────────────────
router.post(
  '/',
  [
    body('_id').notEmpty().withMessage('_id is required'),
    body('merchant').notEmpty().withMessage('merchant is required'),
    body('category')
      .isIn(['food', 'transport', 'housing', 'utilities', 'entertainment', 'healthcare', 'education', 'shopping', 'salary', 'freelance', 'investment', 'other'])
      .withMessage('invalid category'),
    body('type').isIn(['income', 'expense']).withMessage('type must be income or expense'),
    body('amount').isFloat({ min: 0 }).withMessage('amount must be a non-negative number'),
    body('date').notEmpty().withMessage('date is required')
  ],
  validate,
  async (req, res) => {
    const { _id, merchant, category, type, amount, date, status, note, currency } = req.body;

    const transaction = new Transaction({
      _id,
      merchant,
      category,
      type,
      amount: Number(amount),
      date: new Date(Number(date)),
      status: status || 'cleared',
      note: note || '',
      currency: currency || 'INR'
    });

    await transaction.save();
    res.status(201).json(transaction);
  }
);

// ─── GET /api/transactions/exists ─────────────────────────────────────────────
// Must be defined BEFORE /:id routes
router.get(
  '/exists',
  [
    query('merchant').notEmpty().withMessage('merchant is required'),
    query('amount').isFloat({ min: 0 }).withMessage('amount must be a number'),
    query('date').notEmpty().withMessage('date is required')
  ],
  validate,
  async (req, res) => {
    const { merchant, amount, date } = req.query;
    const dateMs = Number(date);
    const amountNum = Number(amount);

    const doc = await Transaction.findOne({
      merchant: { $regex: new RegExp(`^${merchant.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') },
      amount: { $gte: amountNum - 0.01, $lte: amountNum + 0.01 },
      date: { $gte: new Date(dateMs - 60000), $lte: new Date(dateMs + 60000) }
    });

    res.json({ exists: doc !== null });
  }
);

// ─── GET /api/transactions/recent ─────────────────────────────────────────────
router.get('/recent', async (req, res) => {
  const n = Math.max(1, Math.min(100, parseInt(req.query.n) || 5));
  const transactions = await Transaction.find().sort({ date: -1 }).limit(n).lean();
  res.json(transactions);
});

// ─── GET /api/transactions/summary/monthly ────────────────────────────────────
router.get('/summary/monthly', async (req, res) => {
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

  const [result] = await Transaction.aggregate([
    { $match: { date: { $gte: monthStart, $lte: monthEnd } } },
    {
      $group: {
        _id: null,
        totalIncome: {
          $sum: { $cond: [{ $eq: ['$type', 'income'] }, '$amount', 0] }
        },
        totalExpenses: {
          $sum: { $cond: [{ $eq: ['$type', 'expense'] }, '$amount', 0] }
        }
      }
    }
  ]);

  const totalIncome = result ? result.totalIncome : 0;
  const totalExpenses = result ? result.totalExpenses : 0;
  const daysInMonth = now.getDate(); // days elapsed so far
  const dailyExpenseAvg = daysInMonth > 0 ? totalExpenses / daysInMonth : 0;

  res.json({ totalIncome, totalExpenses, dailyExpenseAvg });
});

// ─── GET /api/transactions/summary/net-worth ──────────────────────────────────
router.get('/summary/net-worth', async (req, res) => {
  const portfolioValue = parseFloat(req.query.portfolioValue) || 0;

  const [result] = await Transaction.aggregate([
    {
      $group: {
        _id: null,
        totalIncome: {
          $sum: { $cond: [{ $eq: ['$type', 'income'] }, '$amount', 0] }
        },
        totalExpenses: {
          $sum: { $cond: [{ $eq: ['$type', 'expense'] }, '$amount', 0] }
        }
      }
    }
  ]);

  const totalIncome = result ? result.totalIncome : 0;
  const totalExpenses = result ? result.totalExpenses : 0;
  const netWorth = totalIncome - totalExpenses + portfolioValue;

  res.json({ netWorth });
});

// ─── GET /api/transactions/breakdown/category ─────────────────────────────────
router.get('/breakdown/category', async (req, res) => {
  const { from, to } = req.query;
  const match = { type: 'expense' };
  if (from || to) {
    match.date = {};
    if (from) match.date.$gte = new Date(Number(from));
    if (to) match.date.$lte = new Date(Number(to));
  }

  const results = await Transaction.aggregate([
    { $match: match },
    {
      $group: {
        _id: '$category',
        total: { $sum: '$amount' }
      }
    }
  ]);

  const breakdown = {};
  results.forEach((r) => {
    breakdown[r._id] = r.total;
  });

  res.json(breakdown);
});

// ─── GET /api/transactions/breakdown/daily ────────────────────────────────────
router.get('/breakdown/daily', async (req, res) => {
  const days = Math.max(1, Math.min(365, parseInt(req.query.days) || 7));

  const result = [];
  const now = new Date();

  for (let i = days - 1; i >= 0; i--) {
    const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i, 0, 0, 0, 0);
    const dayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i, 23, 59, 59, 999);

    const [agg] = await Transaction.aggregate([
      { $match: { type: 'expense', date: { $gte: dayStart, $lte: dayEnd } } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);

    result.push(agg ? agg.total : 0.0);
  }

  res.json(result);
});

// ─── GET /api/transactions/savings/monthly ────────────────────────────────────
router.get('/savings/monthly', async (req, res) => {
  const months = Math.max(1, Math.min(24, parseInt(req.query.months) || 6));
  const result = [];
  const now = new Date();

  for (let i = months - 1; i >= 0; i--) {
    const year = now.getMonth() - i < 0
      ? now.getFullYear() - Math.ceil((i - now.getMonth()) / 12)
      : now.getFullYear();
    const month = ((now.getMonth() - i) % 12 + 12) % 12;

    const monthStart = new Date(year, month, 1);
    const monthEnd = new Date(year, month + 1, 0, 23, 59, 59, 999);

    const [agg] = await Transaction.aggregate([
      { $match: { date: { $gte: monthStart, $lte: monthEnd } } },
      {
        $group: {
          _id: null,
          income: { $sum: { $cond: [{ $eq: ['$type', 'income'] }, '$amount', 0] } },
          expenses: { $sum: { $cond: [{ $eq: ['$type', 'expense'] }, '$amount', 0] } }
        }
      }
    ]);

    const savings = agg ? agg.income - agg.expenses : 0.0;
    result.push(savings);
  }

  res.json(result);
});

// ─── GET /api/transactions ────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  const offset = Math.max(0, parseInt(req.query.offset) || 0);
  const limit = Math.max(1, Math.min(200, parseInt(req.query.limit) || 20));
  const { search, category, from, to } = req.query;

  const filter = {};

  if (search) {
    filter.merchant = { $regex: search, $options: 'i' };
  }

  if (category) {
    filter.category = category;
  }

  if (from || to) {
    filter.date = {};
    if (from) filter.date.$gte = new Date(Number(from));
    if (to) filter.date.$lte = new Date(Number(to));
  }

  const [transactions, total] = await Promise.all([
    Transaction.find(filter).sort({ date: -1 }).skip(offset).limit(limit).lean(),
    Transaction.countDocuments(filter)
  ]);

  res.json({ data: transactions, total, offset, limit });
});

// ─── PUT /api/transactions/:id ────────────────────────────────────────────────
router.put(
  '/:id',
  [
    param('id').notEmpty().withMessage('id is required'),
    body('merchant').optional().notEmpty().withMessage('merchant cannot be empty'),
    body('category').optional().isIn(['food', 'transport', 'housing', 'utilities', 'entertainment', 'healthcare', 'education', 'shopping', 'salary', 'freelance', 'investment', 'other']).withMessage('invalid category'),
    body('type').optional().isIn(['income', 'expense']).withMessage('type must be income or expense'),
    body('amount').optional().isFloat({ min: 0 }).withMessage('amount must be a non-negative number'),
  ],
  validate,
  async (req, res) => {
    const { merchant, category, type, amount, date, status, note, currency } = req.body;
    const updates = {};
    if (merchant !== undefined) updates.merchant = merchant;
    if (category !== undefined) updates.category = category;
    if (type !== undefined) updates.type = type;
    if (amount !== undefined) updates.amount = Number(amount);
    if (date !== undefined) updates.date = new Date(Number(date));
    if (status !== undefined) updates.status = status;
    if (note !== undefined) updates.note = note;
    if (currency !== undefined) updates.currency = currency;

    const updated = await Transaction.findByIdAndUpdate(req.params.id, updates, { new: true });
    if (!updated) return res.status(404).json({ error: 'Transaction not found' });
    res.json(updated);
  }
);

// ─── DELETE /api/transactions/:id ─────────────────────────────────────────────
router.delete(
  '/:id',
  [param('id').notEmpty().withMessage('id is required')],
  validate,
  async (req, res) => {
    const deleted = await Transaction.findByIdAndDelete(req.params.id);
    if (!deleted) {
      return res.status(404).json({ error: 'Transaction not found' });
    }
    res.json({ deleted: true, id: req.params.id });
  }
);

module.exports = router;
