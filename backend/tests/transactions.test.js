const request = require('supertest');
const app = require('../src/server');

// Seed helper
const baseTransaction = (overrides = {}) => ({
  _id: `txn-${Date.now()}-${Math.random()}`,
  merchant: 'Zomato',
  category: 'food',
  type: 'expense',
  amount: 250,
  date: Date.now(),
  status: 'cleared',
  note: 'lunch',
  currency: 'INR',
  ...overrides
});

describe('POST /api/transactions', () => {
  it('creates a transaction and returns 201', async () => {
    const tx = baseTransaction();
    const res = await request(app).post('/api/transactions').send(tx);
    expect(res.status).toBe(201);
    expect(res.body._id).toBe(tx._id);
    expect(res.body.merchant).toBe('Zomato');
    expect(res.body.amount).toBe(250);
  });

  it('returns 422 when required fields are missing', async () => {
    const res = await request(app).post('/api/transactions').send({ merchant: 'X' });
    expect(res.status).toBe(422);
    expect(res.body.details).toBeDefined();
  });

  it('returns 422 for invalid category', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .send(baseTransaction({ category: 'invalid_cat' }));
    expect(res.status).toBe(422);
  });

  it('returns 422 for invalid type', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .send(baseTransaction({ type: 'other' }));
    expect(res.status).toBe(422);
  });

  it('accepts income type', async () => {
    const tx = baseTransaction({ type: 'income', category: 'salary', amount: 50000 });
    const res = await request(app).post('/api/transactions').send(tx);
    expect(res.status).toBe(201);
    expect(res.body.type).toBe('income');
  });
});

describe('GET /api/transactions', () => {
  beforeEach(async () => {
    const now = Date.now();
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'tx1', merchant: 'Zomato', category: 'food', type: 'expense', amount: 100, date: now }));
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'tx2', merchant: 'Uber', category: 'transport', type: 'expense', amount: 200, date: now - 1000 }));
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'tx3', merchant: 'Company', category: 'salary', type: 'income', amount: 5000, date: now - 2000 }));
  });

  it('returns paginated list', async () => {
    const res = await request(app).get('/api/transactions?limit=2&offset=0');
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(2);
    expect(res.body.total).toBe(3);
    expect(res.body.offset).toBe(0);
    expect(res.body.limit).toBe(2);
  });

  it('filters by category', async () => {
    const res = await request(app).get('/api/transactions?category=food');
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].category).toBe('food');
  });

  it('filters by search (case-insensitive)', async () => {
    const res = await request(app).get('/api/transactions?search=zomato');
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].merchant).toBe('Zomato');
  });

  it('filters by date range (from/to in ms)', async () => {
    const from = Date.now() - 500;
    const to = Date.now() + 500;
    const res = await request(app).get(`/api/transactions?from=${from}&to=${to}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
  });

  it('applies offset correctly', async () => {
    const res = await request(app).get('/api/transactions?limit=2&offset=2');
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
  });
});

describe('GET /api/transactions/exists', () => {
  it('returns exists:true for duplicate within 1 min', async () => {
    const now = Date.now();
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'dup1', merchant: 'Swiggy', amount: 300, date: now }));

    const res = await request(app).get(`/api/transactions/exists?merchant=Swiggy&amount=300&date=${now + 30000}`);
    expect(res.status).toBe(200);
    expect(res.body.exists).toBe(true);
  });

  it('returns exists:false when outside 1-min window', async () => {
    const now = Date.now();
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'far1', merchant: 'Swiggy', amount: 300, date: now }));

    const res = await request(app).get(`/api/transactions/exists?merchant=Swiggy&amount=300&date=${now + 120000}`);
    expect(res.status).toBe(200);
    expect(res.body.exists).toBe(false);
  });

  it('returns exists:false for different merchant', async () => {
    const now = Date.now();
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'diff1', merchant: 'Swiggy', amount: 300, date: now }));

    const res = await request(app).get(`/api/transactions/exists?merchant=Zomato&amount=300&date=${now}`);
    expect(res.status).toBe(200);
    expect(res.body.exists).toBe(false);
  });

  it('is case-insensitive for merchant', async () => {
    const now = Date.now();
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'ci1', merchant: 'Swiggy', amount: 300, date: now }));

    const res = await request(app).get(`/api/transactions/exists?merchant=swiggy&amount=300&date=${now}`);
    expect(res.status).toBe(200);
    expect(res.body.exists).toBe(true);
  });

  it('returns 422 when params missing', async () => {
    const res = await request(app).get('/api/transactions/exists?merchant=X');
    expect(res.status).toBe(422);
  });
});

describe('GET /api/transactions/recent', () => {
  it('returns last N transactions sorted by date desc', async () => {
    const now = Date.now();
    for (let i = 0; i < 7; i++) {
      await request(app).post('/api/transactions').send(baseTransaction({ _id: `rec${i}`, date: now - i * 1000 }));
    }

    const res = await request(app).get('/api/transactions/recent?n=3');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(3);
    // First should be most recent
    expect(new Date(res.body[0].date) >= new Date(res.body[1].date)).toBe(true);
  });

  it('defaults to 5 if n not provided', async () => {
    const now = Date.now();
    for (let i = 0; i < 8; i++) {
      await request(app).post('/api/transactions').send(baseTransaction({ _id: `def${i}`, date: now - i * 1000 }));
    }

    const res = await request(app).get('/api/transactions/recent');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(5);
  });
});

describe('GET /api/transactions/summary/monthly', () => {
  it('returns correct totalIncome, totalExpenses and dailyExpenseAvg', async () => {
    const now = Date.now();
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'm1', type: 'income', category: 'salary', amount: 10000, date: now }));
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'm2', type: 'expense', category: 'food', amount: 500, date: now }));
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'm3', type: 'expense', category: 'transport', amount: 300, date: now }));

    const res = await request(app).get('/api/transactions/summary/monthly');
    expect(res.status).toBe(200);
    expect(res.body.totalIncome).toBe(10000);
    expect(res.body.totalExpenses).toBe(800);
    expect(res.body.dailyExpenseAvg).toBeGreaterThan(0);
  });

  it('returns zeros when no transactions', async () => {
    const res = await request(app).get('/api/transactions/summary/monthly');
    expect(res.status).toBe(200);
    expect(res.body.totalIncome).toBe(0);
    expect(res.body.totalExpenses).toBe(0);
    expect(res.body.dailyExpenseAvg).toBe(0);
  });
});

describe('GET /api/transactions/summary/net-worth', () => {
  it('calculates netWorth as income - expenses + portfolio', async () => {
    const now = Date.now();
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'nw1', type: 'income', category: 'salary', amount: 50000, date: now }));
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'nw2', type: 'expense', category: 'food', amount: 10000, date: now }));

    const res = await request(app).get('/api/transactions/summary/net-worth?portfolioValue=20000');
    expect(res.status).toBe(200);
    expect(res.body.netWorth).toBe(60000); // 50000 - 10000 + 20000
  });

  it('defaults portfolioValue to 0', async () => {
    const now = Date.now();
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'nw3', type: 'income', category: 'salary', amount: 1000, date: now }));

    const res = await request(app).get('/api/transactions/summary/net-worth');
    expect(res.status).toBe(200);
    expect(res.body.netWorth).toBe(1000);
  });
});

describe('GET /api/transactions/breakdown/category', () => {
  it('returns expense totals grouped by category', async () => {
    const now = Date.now();
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'bc1', type: 'expense', category: 'food', amount: 200, date: now }));
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'bc2', type: 'expense', category: 'food', amount: 300, date: now }));
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'bc3', type: 'expense', category: 'transport', amount: 150, date: now }));
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'bc4', type: 'income', category: 'salary', amount: 5000, date: now })); // should be excluded

    const res = await request(app).get('/api/transactions/breakdown/category');
    expect(res.status).toBe(200);
    expect(res.body.food).toBe(500);
    expect(res.body.transport).toBe(150);
    expect(res.body.salary).toBeUndefined();
  });

  it('filters by date range', async () => {
    const now = Date.now();
    const old = now - 10 * 24 * 60 * 60 * 1000; // 10 days ago
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'bc5', type: 'expense', category: 'food', amount: 999, date: old }));
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'bc6', type: 'expense', category: 'food', amount: 100, date: now }));

    const res = await request(app).get(`/api/transactions/breakdown/category?from=${now - 1000}&to=${now + 1000}`);
    expect(res.status).toBe(200);
    expect(res.body.food).toBe(100);
  });
});

describe('GET /api/transactions/breakdown/daily', () => {
  it('returns an array of daily expense totals', async () => {
    const now = Date.now();
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'bd1', type: 'expense', category: 'food', amount: 400, date: now }));

    const res = await request(app).get('/api/transactions/breakdown/daily?days=7');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body).toHaveLength(7);
    // Last element is today's total
    expect(res.body[res.body.length - 1]).toBe(400);
  });

  it('defaults to 7 days', async () => {
    const res = await request(app).get('/api/transactions/breakdown/daily');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(7);
  });
});

describe('GET /api/transactions/savings/monthly', () => {
  it('returns array of monthly savings (income - expenses)', async () => {
    const now = Date.now();
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'sm1', type: 'income', category: 'salary', amount: 10000, date: now }));
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'sm2', type: 'expense', category: 'food', amount: 3000, date: now }));

    const res = await request(app).get('/api/transactions/savings/monthly?months=3');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body).toHaveLength(3);
    // Current month savings
    expect(res.body[res.body.length - 1]).toBe(7000);
  });

  it('defaults to 6 months', async () => {
    const res = await request(app).get('/api/transactions/savings/monthly');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(6);
  });
});

describe('DELETE /api/transactions/:id', () => {
  it('deletes a transaction', async () => {
    await request(app).post('/api/transactions').send(baseTransaction({ _id: 'del1' }));

    const res = await request(app).delete('/api/transactions/del1');
    expect(res.status).toBe(200);
    expect(res.body.deleted).toBe(true);

    const check = await request(app).get('/api/transactions?search=del1');
    expect(check.body.total).toBe(0);
  });

  it('returns 404 for non-existent id', async () => {
    const res = await request(app).delete('/api/transactions/nonexistent-id-xyz');
    expect(res.status).toBe(404);
  });
});
