const request = require('supertest');
const app = require('../src/server');

// Helper: budget period covering today
const currentPeriod = () => {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), 1).getTime();
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999).getTime();
  return { periodStart: start, periodEnd: end };
};

const baseBudget = (overrides = {}) => ({
  _id: `bud-${Date.now()}-${Math.random()}`,
  category: 'food',
  limitAmount: 5000,
  currency: 'INR',
  ...currentPeriod(),
  ...overrides
});

const baseTx = (overrides = {}) => ({
  _id: `tx-${Date.now()}-${Math.random()}`,
  merchant: 'Zomato',
  category: 'food',
  type: 'expense',
  amount: 500,
  date: Date.now(),
  currency: 'INR',
  ...overrides
});

describe('POST /api/budgets', () => {
  it('creates a budget and returns 201', async () => {
    const budget = baseBudget();
    const res = await request(app).post('/api/budgets').send(budget);
    expect(res.status).toBe(201);
    expect(res.body.category).toBe('food');
    expect(res.body.limitAmount).toBe(5000);
  });

  it('upserts budget for the same category', async () => {
    await request(app).post('/api/budgets').send(baseBudget({ category: 'transport', limitAmount: 2000 }));
    const res = await request(app).post('/api/budgets').send(baseBudget({ category: 'transport', limitAmount: 3000 }));
    expect(res.status).toBe(201);
    expect(res.body.limitAmount).toBe(3000);

    // Should still be only one transport budget
    const list = await request(app).get('/api/budgets/current');
    const transport = list.body.filter((b) => b.category === 'transport');
    expect(transport).toHaveLength(1);
  });

  it('returns 422 for invalid category', async () => {
    const res = await request(app).post('/api/budgets').send(baseBudget({ category: 'invalid' }));
    expect(res.status).toBe(422);
  });

  it('returns 422 when limitAmount is missing', async () => {
    const { limitAmount, ...noAmount } = baseBudget();
    const res = await request(app).post('/api/budgets').send(noAmount);
    expect(res.status).toBe(422);
  });
});

describe('GET /api/budgets/current', () => {
  it('returns budgets with computed spent amounts', async () => {
    // Create food budget for current month
    await request(app).post('/api/budgets').send(baseBudget({ category: 'food', limitAmount: 5000 }));

    // Create transactions in current period
    await request(app).post('/api/transactions').send(baseTx({ _id: 'bt1', category: 'food', amount: 600 }));
    await request(app).post('/api/transactions').send(baseTx({ _id: 'bt2', category: 'food', amount: 400 }));
    await request(app).post('/api/transactions').send(baseTx({ _id: 'bt3', category: 'transport', amount: 9999, type: 'expense' })); // different category, not in budget

    const res = await request(app).get('/api/budgets/current');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);

    const foodBudget = res.body.find((b) => b.category === 'food');
    expect(foodBudget).toBeDefined();
    expect(foodBudget.spent).toBe(1000);
    expect(foodBudget.limitAmount).toBe(5000);
  });

  it('returns empty array when no current budgets', async () => {
    const res = await request(app).get('/api/budgets/current');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(0);
  });

  it('excludes income transactions from spent', async () => {
    await request(app).post('/api/budgets').send(baseBudget({ category: 'salary', limitAmount: 100000 }));
    await request(app).post('/api/transactions').send(
      baseTx({ _id: 'bt4', category: 'salary', type: 'income', amount: 50000 })
    );

    const res = await request(app).get('/api/budgets/current');
    expect(res.status).toBe(200);
    const salaryBudget = res.body.find((b) => b.category === 'salary');
    expect(salaryBudget.spent).toBe(0);
  });

  it('returns 0 spent when no transactions for that category', async () => {
    await request(app).post('/api/budgets').send(baseBudget({ category: 'healthcare', limitAmount: 3000 }));

    const res = await request(app).get('/api/budgets/current');
    expect(res.status).toBe(200);
    const hc = res.body.find((b) => b.category === 'healthcare');
    expect(hc.spent).toBe(0);
  });
});

describe('DELETE /api/budgets/:id', () => {
  it('deletes a budget', async () => {
    const createRes = await request(app).post('/api/budgets').send(baseBudget({ category: 'entertainment' }));
    const id = createRes.body._id;

    const res = await request(app).delete(`/api/budgets/${id}`);
    expect(res.status).toBe(200);
    expect(res.body.deleted).toBe(true);
  });

  it('returns 404 for non-existent budget', async () => {
    const res = await request(app).delete('/api/budgets/nonexistent-budget-id');
    expect(res.status).toBe(404);
  });
});
