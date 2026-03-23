const request = require('supertest');
const app = require('../src/server');

const baseInvestment = (overrides = {}) => ({
  _id: `inv-${Date.now()}-${Math.random()}`,
  name: 'NIFTY 50 ETF',
  ticker: 'NIFTYBEES',
  assetClass: 'equities',
  units: 10,
  currentPrice: 200,
  sevenDayReturn: 1.5,
  currency: 'INR',
  ...overrides
});

const baseSnapshot = (overrides = {}) => ({
  _id: `snap-${Date.now()}-${Math.random()}`,
  date: Date.now(),
  totalPortfolioValue: 50000,
  currency: 'INR',
  ...overrides
});

describe('POST /api/investments', () => {
  it('creates an investment and returns 201', async () => {
    const inv = baseInvestment();
    const res = await request(app).post('/api/investments').send(inv);
    expect(res.status).toBe(201);
    expect(res.body._id).toBe(inv._id);
    expect(res.body.name).toBe('NIFTY 50 ETF');
    expect(res.body.units).toBe(10);
    expect(res.body.currentPrice).toBe(200);
  });

  it('upserts existing investment by _id', async () => {
    const inv = baseInvestment({ _id: 'inv-upsert' });
    await request(app).post('/api/investments').send(inv);

    const updated = { ...inv, units: 20, currentPrice: 250 };
    const res = await request(app).post('/api/investments').send(updated);
    expect(res.status).toBe(201);
    expect(res.body.units).toBe(20);
    expect(res.body.currentPrice).toBe(250);
  });

  it('returns 422 for invalid assetClass', async () => {
    const res = await request(app).post('/api/investments').send(baseInvestment({ assetClass: 'stocks' }));
    expect(res.status).toBe(422);
  });

  it('returns 422 when _id is missing', async () => {
    const { _id, ...noId } = baseInvestment();
    const res = await request(app).post('/api/investments').send(noId);
    expect(res.status).toBe(422);
  });
});

describe('GET /api/investments', () => {
  beforeEach(async () => {
    await request(app).post('/api/investments').send(baseInvestment({ _id: 'inv1', name: 'ETF A', assetClass: 'equities' }));
    await request(app).post('/api/investments').send(baseInvestment({ _id: 'inv2', name: 'Bitcoin', assetClass: 'crypto', units: 0.5, currentPrice: 5000000 }));
  });

  it('returns all investments', async () => {
    const res = await request(app).get('/api/investments');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);
  });
});

describe('GET /api/investments/total-value', () => {
  it('returns sum of units * currentPrice', async () => {
    await request(app).post('/api/investments').send(baseInvestment({ _id: 'tv1', units: 10, currentPrice: 100 }));
    await request(app).post('/api/investments').send(baseInvestment({ _id: 'tv2', units: 5, currentPrice: 200, assetClass: 'crypto' }));

    const res = await request(app).get('/api/investments/total-value');
    expect(res.status).toBe(200);
    expect(res.body.totalValue).toBe(2000); // 10*100 + 5*200
  });

  it('returns 0 when no investments', async () => {
    const res = await request(app).get('/api/investments/total-value');
    expect(res.status).toBe(200);
    expect(res.body.totalValue).toBe(0);
  });
});

describe('GET /api/investments/allocation', () => {
  it('returns allocation grouped by assetClass', async () => {
    await request(app).post('/api/investments').send(baseInvestment({ _id: 'al1', assetClass: 'equities', units: 10, currentPrice: 100 }));
    await request(app).post('/api/investments').send(baseInvestment({ _id: 'al2', assetClass: 'equities', units: 5, currentPrice: 200 }));
    await request(app).post('/api/investments').send(baseInvestment({ _id: 'al3', assetClass: 'crypto', units: 1, currentPrice: 3000 }));

    const res = await request(app).get('/api/investments/allocation');
    expect(res.status).toBe(200);
    expect(res.body.equities).toBe(2000); // 10*100 + 5*200
    expect(res.body.crypto).toBe(3000);
  });

  it('returns empty object when no investments', async () => {
    const res = await request(app).get('/api/investments/allocation');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({});
  });
});

describe('DELETE /api/investments/:id', () => {
  it('deletes an investment', async () => {
    await request(app).post('/api/investments').send(baseInvestment({ _id: 'del-inv1' }));

    const res = await request(app).delete('/api/investments/del-inv1');
    expect(res.status).toBe(200);
    expect(res.body.deleted).toBe(true);
  });

  it('returns 404 for non-existent investment', async () => {
    const res = await request(app).delete('/api/investments/nonexistent-inv');
    expect(res.status).toBe(404);
  });
});

describe('POST /api/investments/snapshots', () => {
  it('creates a snapshot and returns 201', async () => {
    const snap = baseSnapshot();
    const res = await request(app).post('/api/investments/snapshots').send(snap);
    expect(res.status).toBe(201);
    expect(res.body._id).toBe(snap._id);
    expect(res.body.totalPortfolioValue).toBe(50000);
  });

  it('returns 422 when totalPortfolioValue is missing', async () => {
    const { totalPortfolioValue, ...noVal } = baseSnapshot();
    const res = await request(app).post('/api/investments/snapshots').send(noVal);
    expect(res.status).toBe(422);
  });
});

describe('GET /api/investments/snapshots', () => {
  it('returns snapshots sorted by date desc up to limit', async () => {
    const now = Date.now();
    for (let i = 0; i < 5; i++) {
      await request(app).post('/api/investments/snapshots').send(
        baseSnapshot({ _id: `s${i}`, date: now - i * 86400000, totalPortfolioValue: 50000 + i * 1000 })
      );
    }

    const res = await request(app).get('/api/investments/snapshots?limit=3');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(3);
    // Most recent first
    expect(new Date(res.body[0].date) >= new Date(res.body[1].date)).toBe(true);
  });

  it('defaults to 30 limit', async () => {
    const now = Date.now();
    for (let i = 0; i < 35; i++) {
      await request(app).post('/api/investments/snapshots').send(
        baseSnapshot({ _id: `sd${i}`, date: now - i * 86400000 })
      );
    }

    const res = await request(app).get('/api/investments/snapshots');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(30);
  });
});
