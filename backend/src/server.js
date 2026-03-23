require('dotenv').config();
require('express-async-errors');

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');

const { connectDB } = require('./db');
const authMiddleware = require('./middleware/auth');
const errorHandler = require('./middleware/errorHandler');

const authRouter = require('./routes/auth');
const transactionsRouter = require('./routes/transactions');
const goalsRouter = require('./routes/goals');
const budgetsRouter = require('./routes/budgets');
const investmentsRouter = require('./routes/investments');
const profileRouter = require('./routes/profile');
const chatRouter = require('./routes/chat');

const app = express();

// ─── Security & Utility Middleware ────────────────────────────────────────────
app.use(helmet());
app.use(cors());
app.use(express.json());

if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// ─── Health check (no auth required) ─────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    env: process.env.NODE_ENV || 'development'
  });
});

// Auth routes (no auth required)
app.use('/api/auth', authRouter);

// ─── Auth on all /api routes (except /api/health above) ──────────────────────
app.use('/api', authMiddleware);

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/transactions', transactionsRouter);
app.use('/api/goals', goalsRouter);
app.use('/api/budgets', budgetsRouter);
app.use('/api/investments', investmentsRouter);
app.use('/api/profile', profileRouter);
app.use('/api/chat', chatRouter);

// ─── 404 handler ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: `Route ${req.method} ${req.path} not found` });
});

// ─── Global error handler ─────────────────────────────────────────────────────
app.use(errorHandler);

// ─── Start server ─────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;

async function start() {
  try {
    await connectDB();
    app.listen(PORT, () => {
      console.log(`Echelon Finance API running on port ${PORT}`);
    });
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

// Only start the HTTP server when executed directly (not during tests)
if (require.main === module) {
  start();
}

module.exports = app;
