const mongoose = require('mongoose');

const investmentSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  name: { type: String, required: true, trim: true },
  ticker: { type: String, default: '', trim: true },
  assetClass: {
    type: String,
    required: true,
    enum: ['equities', 'realEstate', 'fixedIncome', 'crypto', 'cash']
  },
  units: { type: Number, required: true, min: 0 },
  currentPrice: { type: Number, required: true, min: 0 },
  sevenDayReturn: { type: Number, default: 0 },
  currency: { type: String, default: 'INR' },
  lastUpdated: { type: Date, default: Date.now }
}, { _id: false, timestamps: false });

module.exports = mongoose.model('Investment', investmentSchema);
