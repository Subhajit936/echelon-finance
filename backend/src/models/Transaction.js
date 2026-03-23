const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  merchant: { type: String, required: true, trim: true },
  category: {
    type: String,
    required: true,
    enum: ['food', 'transport', 'housing', 'utilities', 'entertainment', 'healthcare', 'education', 'shopping', 'salary', 'freelance', 'investment', 'other']
  },
  type: { type: String, required: true, enum: ['income', 'expense'] },
  amount: { type: Number, required: true, min: 0 },
  date: { type: Date, required: true },
  status: { type: String, default: 'cleared', enum: ['approved', 'cleared', 'pending', 'subscription'] },
  note: { type: String, default: '' },
  currency: { type: String, default: 'INR' },
  createdAt: { type: Date, default: Date.now }
}, { _id: false, timestamps: false });

transactionSchema.index({ date: -1 });
transactionSchema.index({ type: 1 });
transactionSchema.index({ category: 1 });

module.exports = mongoose.model('Transaction', transactionSchema);
