const express = require('express');
const { body, param, query, validationResult } = require('express-validator');
const Investment = require('../models/Investment');
const InvestmentSnapshot = require('../models/InvestmentSnapshot');

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

// ─── GET /api/investments ─────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  const investments = await Investment.find().sort({ name: 1 }).lean();
  res.json(investments);
});

// ─── GET /api/investments/total-value ─────────────────────────────────────────
router.get('/total-value', async (req, res) => {
  const [result] = await Investment.aggregate([
    {
      $group: {
        _id: null,
        totalValue: { $sum: { $multiply: ['$units', '$currentPrice'] } }
      }
    }
  ]);
  res.json({ totalValue: result ? result.totalValue : 0 });
});

// ─── GET /api/investments/allocation ──────────────────────────────────────────
router.get('/allocation', async (req, res) => {
  const results = await Investment.aggregate([
    {
      $group: {
        _id: '$assetClass',
        value: { $sum: { $multiply: ['$units', '$currentPrice'] } }
      }
    }
  ]);

  const allocation = {};
  results.forEach((r) => {
    allocation[r._id] = r.value;
  });

  res.json(allocation);
});

// ─── GET /api/investments/snapshots ───────────────────────────────────────────
router.get('/snapshots', async (req, res) => {
  const limit = Math.max(1, Math.min(365, parseInt(req.query.limit) || 30));
  const snapshots = await InvestmentSnapshot.find().sort({ date: -1 }).limit(limit).lean();
  res.json(snapshots);
});

// ─── POST /api/investments ────────────────────────────────────────────────────
// Upsert investment by _id (or create)
router.post(
  '/',
  [
    body('_id').notEmpty().withMessage('_id is required'),
    body('name').notEmpty().withMessage('name is required'),
    body('assetClass')
      .isIn(['equities', 'realEstate', 'fixedIncome', 'crypto', 'cash'])
      .withMessage('invalid assetClass'),
    body('units').isFloat({ min: 0 }).withMessage('units must be a non-negative number'),
    body('currentPrice').isFloat({ min: 0 }).withMessage('currentPrice must be a non-negative number')
  ],
  validate,
  async (req, res) => {
    const { _id, name, ticker, assetClass, units, currentPrice, sevenDayReturn, currency } = req.body;

    const investment = await Investment.findByIdAndUpdate(
      _id,
      {
        $set: {
          _id,
          name,
          ticker: ticker || '',
          assetClass,
          units: Number(units),
          currentPrice: Number(currentPrice),
          sevenDayReturn: sevenDayReturn != null ? Number(sevenDayReturn) : 0,
          currency: currency || 'INR',
          lastUpdated: new Date()
        }
      },
      { upsert: true, new: true, runValidators: true, setDefaultsOnInsert: true }
    );

    res.status(201).json(investment);
  }
);

// ─── POST /api/investments/snapshots ──────────────────────────────────────────
// Defined before DELETE /:id so the literal path /snapshots is not swallowed by the param route
router.post(
  '/snapshots',
  [
    body('_id').notEmpty().withMessage('_id is required'),
    body('totalPortfolioValue').isFloat({ min: 0 }).withMessage('totalPortfolioValue must be a non-negative number'),
    body('date').notEmpty().withMessage('date is required')
  ],
  validate,
  async (req, res) => {
    const { _id, date, totalPortfolioValue, currency } = req.body;

    const snapshot = new InvestmentSnapshot({
      _id,
      date: new Date(Number(date)),
      totalPortfolioValue: Number(totalPortfolioValue),
      currency: currency || 'INR'
    });

    await snapshot.save();
    res.status(201).json(snapshot);
  }
);

// ─── DELETE /api/investments/:id ──────────────────────────────────────────────
router.delete(
  '/:id',
  [param('id').notEmpty().withMessage('id is required')],
  validate,
  async (req, res) => {
    const deleted = await Investment.findByIdAndDelete(req.params.id);
    if (!deleted) {
      return res.status(404).json({ error: 'Investment not found' });
    }
    res.json({ deleted: true, id: req.params.id });
  }
);

module.exports = router;
