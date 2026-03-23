const request = require('supertest');
const app = require('../src/server');

const baseGoal = (overrides = {}) => ({
  _id: `goal-${Date.now()}-${Math.random()}`,
  name: 'Emergency Fund',
  emoji: '🏦',
  targetAmount: 100000,
  currentAmount: 0,
  targetDate: Date.now() + 365 * 24 * 60 * 60 * 1000,
  dailyTarget: 274,
  status: 'active',
  currency: 'INR',
  ...overrides
});

describe('POST /api/goals', () => {
  it('creates a goal and returns 201', async () => {
    const goal = baseGoal();
    const res = await request(app).post('/api/goals').send(goal);
    expect(res.status).toBe(201);
    expect(res.body._id).toBe(goal._id);
    expect(res.body.name).toBe('Emergency Fund');
    expect(res.body.targetAmount).toBe(100000);
  });

  it('returns 422 when _id is missing', async () => {
    const { _id, ...noId } = baseGoal();
    const res = await request(app).post('/api/goals').send(noId);
    expect(res.status).toBe(422);
  });

  it('returns 422 when targetAmount is missing', async () => {
    const { targetAmount, ...noAmount } = baseGoal();
    const res = await request(app).post('/api/goals').send(noAmount);
    expect(res.status).toBe(422);
  });

  it('defaults status to active', async () => {
    const { status, ...noStatus } = baseGoal({ _id: 'g-nostat' });
    const res = await request(app).post('/api/goals').send(noStatus);
    expect(res.status).toBe(201);
    expect(res.body.status).toBe('active');
  });

  it('accepts null targetDate', async () => {
    const res = await request(app).post('/api/goals').send(baseGoal({ _id: 'g-nulldate', targetDate: null }));
    expect(res.status).toBe(201);
    expect(res.body.targetDate).toBeNull();
  });
});

describe('GET /api/goals', () => {
  beforeEach(async () => {
    await request(app).post('/api/goals').send(baseGoal({ _id: 'g1', status: 'active' }));
    await request(app).post('/api/goals').send(baseGoal({ _id: 'g2', status: 'completed' }));
    await request(app).post('/api/goals').send(baseGoal({ _id: 'g3', status: 'paused' }));
  });

  it('returns all goals', async () => {
    const res = await request(app).get('/api/goals');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(3);
  });
});

describe('GET /api/goals/active', () => {
  beforeEach(async () => {
    await request(app).post('/api/goals').send(baseGoal({ _id: 'ga1', status: 'active' }));
    await request(app).post('/api/goals').send(baseGoal({ _id: 'ga2', status: 'completed' }));
    await request(app).post('/api/goals').send(baseGoal({ _id: 'ga3', status: 'active' }));
  });

  it('returns only active goals', async () => {
    const res = await request(app).get('/api/goals/active');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);
    res.body.forEach((g) => expect(g.status).toBe('active'));
  });
});

describe('PUT /api/goals/:id', () => {
  it('updates a goal', async () => {
    await request(app).post('/api/goals').send(baseGoal({ _id: 'upd1' }));
    const res = await request(app).put('/api/goals/upd1').send({ name: 'Updated Name', status: 'paused' });
    expect(res.status).toBe(200);
    expect(res.body.name).toBe('Updated Name');
    expect(res.body.status).toBe('paused');
  });

  it('returns 404 for non-existent goal', async () => {
    const res = await request(app).put('/api/goals/nonexistent').send({ name: 'X' });
    expect(res.status).toBe(404);
  });
});

describe('DELETE /api/goals/:id', () => {
  it('deletes a goal', async () => {
    await request(app).post('/api/goals').send(baseGoal({ _id: 'del-g1' }));
    const res = await request(app).delete('/api/goals/del-g1');
    expect(res.status).toBe(200);
    expect(res.body.deleted).toBe(true);
  });

  it('returns 404 for non-existent goal', async () => {
    const res = await request(app).delete('/api/goals/nonexistent-goal');
    expect(res.status).toBe(404);
  });
});

describe('POST /api/goals/:id/contribute', () => {
  it('adds amount to currentAmount', async () => {
    await request(app).post('/api/goals').send(baseGoal({ _id: 'con1', currentAmount: 1000, targetAmount: 10000 }));

    const res = await request(app).post('/api/goals/con1/contribute').send({ amount: 2000 });
    expect(res.status).toBe(200);
    expect(res.body.currentAmount).toBe(3000);
    expect(res.body.status).toBe('active');
  });

  it('marks goal as completed when target reached', async () => {
    await request(app).post('/api/goals').send(baseGoal({ _id: 'con2', currentAmount: 9000, targetAmount: 10000 }));

    const res = await request(app).post('/api/goals/con2/contribute').send({ amount: 1000 });
    expect(res.status).toBe(200);
    expect(res.body.currentAmount).toBe(10000);
    expect(res.body.status).toBe('completed');
  });

  it('marks goal as completed when contribution exceeds target', async () => {
    await request(app).post('/api/goals').send(baseGoal({ _id: 'con3', currentAmount: 0, targetAmount: 500 }));

    const res = await request(app).post('/api/goals/con3/contribute').send({ amount: 600 });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('completed');
  });

  it('returns 404 for non-existent goal', async () => {
    const res = await request(app).post('/api/goals/nonexistent/contribute').send({ amount: 100 });
    expect(res.status).toBe(404);
  });

  it('returns 422 for invalid amount', async () => {
    await request(app).post('/api/goals').send(baseGoal({ _id: 'con4' }));
    const res = await request(app).post('/api/goals/con4/contribute').send({ amount: -50 });
    expect(res.status).toBe(422);
  });
});
