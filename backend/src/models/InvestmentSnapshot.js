const mongoose = require('mongoose');

const investmentSnapshotSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  date: { type: Date, required: true },
  totalPortfolioValue: { type: Number, required: true, min: 0 },
  currency: { type: String, default: 'INR' }
}, { _id: false, timestamps: false });

investmentSnapshotSchema.index({ date: -1 });

module.exports = mongoose.model('InvestmentSnapshot', investmentSnapshotSchema);
