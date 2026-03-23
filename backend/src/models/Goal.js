const mongoose = require('mongoose');

const goalSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  name: { type: String, required: true, trim: true },
  emoji: { type: String, default: '' },
  targetAmount: { type: Number, required: true, min: 0 },
  currentAmount: { type: Number, default: 0, min: 0 },
  targetDate: { type: Date, default: null },
  dailyTarget: { type: Number, default: 0 },
  status: { type: String, default: 'active', enum: ['active', 'completed', 'paused'] },
  currency: { type: String, default: 'INR' },
  createdAt: { type: Date, default: Date.now }
}, { _id: false, timestamps: false });

module.exports = mongoose.model('Goal', goalSchema);
