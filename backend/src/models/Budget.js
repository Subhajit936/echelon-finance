const mongoose = require('mongoose');

const budgetSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  category: {
    type: String,
    required: true,
    enum: ['food', 'transport', 'housing', 'utilities', 'entertainment', 'healthcare', 'education', 'shopping', 'salary', 'freelance', 'investment', 'other']
  },
  limitAmount: { type: Number, required: true, min: 0 },
  periodStart: { type: Date, required: true },
  periodEnd: { type: Date, required: true },
  currency: { type: String, default: 'INR' }
}, { _id: false, timestamps: false });

module.exports = mongoose.model('Budget', budgetSchema);
