const express = require('express');
const { body, validationResult } = require('express-validator');
const UserProfile = require('../models/UserProfile');

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

// ─── GET /api/profile ─────────────────────────────────────────────────────────
// Returns the single profile document; creates a default one if it doesn't exist
router.get('/', async (req, res) => {
  let profile = await UserProfile.findById('1').lean();

  if (!profile) {
    const newProfile = new UserProfile({
      _id: '1',
      displayName: '',
      preferredCurrency: 'INR',
      onboardingComplete: false
    });
    await newProfile.save();
    profile = newProfile.toObject();
  }

  res.json(profile);
});

// ─── PUT /api/profile ─────────────────────────────────────────────────────────
router.put(
  '/',
  [
    body('displayName').optional().isString().withMessage('displayName must be a string'),
    body('preferredCurrency').optional().isString().withMessage('preferredCurrency must be a string'),
    body('onboardingComplete').optional().isBoolean().withMessage('onboardingComplete must be a boolean')
  ],
  validate,
  async (req, res) => {
    const { displayName, preferredCurrency, onboardingComplete } = req.body;

    const update = {};
    if (displayName !== undefined) update.displayName = displayName;
    if (preferredCurrency !== undefined) update.preferredCurrency = preferredCurrency;
    if (onboardingComplete !== undefined) update.onboardingComplete = onboardingComplete;

    const profile = await UserProfile.findByIdAndUpdate(
      '1',
      { $set: update, $setOnInsert: { _id: '1', createdAt: new Date() } },
      { upsert: true, new: true, runValidators: true }
    );

    res.json(profile);
  }
);

module.exports = router;
