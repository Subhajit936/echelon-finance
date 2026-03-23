const mongoose = require('mongoose');

let isConnected = false;

async function connectDB() {
  if (isConnected) return;
  await mongoose.connect(process.env.MONGODB_URI, {
    dbName: 'echelon_finance'
  });
  isConnected = true;
  console.log('MongoDB connected');
}

module.exports = { connectDB };
