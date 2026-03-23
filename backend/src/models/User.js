const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    _id:          { type: String, required: true },
    name:         { type: String, required: true, trim: true },
    email:        { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    createdAt:    { type: Date, default: Date.now }
  },
  { _id: false }
);

module.exports = mongoose.model('User', userSchema);
