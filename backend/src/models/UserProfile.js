const mongoose = require('mongoose');

const userProfileSchema = new mongoose.Schema({
  _id: { type: String, default: '1' },
  displayName: { type: String, default: '', trim: true },
  preferredCurrency: { type: String, default: 'INR' },
  onboardingComplete: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
}, { _id: false, timestamps: false });

module.exports = mongoose.model('UserProfile', userProfileSchema);
