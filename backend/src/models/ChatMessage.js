const mongoose = require('mongoose');

const chatMessageSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  role: { type: String, required: true, enum: ['user', 'assistant'] },
  content: { type: String, required: true },
  intent: { type: String, default: '' },
  timestamp: { type: Date, default: Date.now },
  parsedTransactionId: { type: String, default: null },
  isError: { type: Boolean, default: false }
}, { _id: false, timestamps: false });

chatMessageSchema.index({ timestamp: -1 });

module.exports = mongoose.model('ChatMessage', chatMessageSchema);
