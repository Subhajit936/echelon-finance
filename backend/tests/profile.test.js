const request = require('supertest');
const app = require('../src/server');

describe('GET /api/profile', () => {
  it('creates and returns a default profile if none exists', async () => {
    const res = await request(app).get('/api/profile');
    expect(res.status).toBe(200);
    expect(res.body._id).toBe('1');
    expect(res.body.preferredCurrency).toBe('INR');
    expect(res.body.onboardingComplete).toBe(false);
  });

  it('returns the existing profile on subsequent calls', async () => {
    await request(app).get('/api/profile');
    const res = await request(app).get('/api/profile');
    expect(res.status).toBe(200);
    expect(res.body._id).toBe('1');
  });

  it('returns the profile after it has been updated', async () => {
    await request(app).put('/api/profile').send({ displayName: 'Alice' });
    const res = await request(app).get('/api/profile');
    expect(res.status).toBe(200);
    expect(res.body.displayName).toBe('Alice');
  });
});

describe('PUT /api/profile', () => {
  it('creates a profile on first PUT if none exists', async () => {
    const res = await request(app).put('/api/profile').send({
      displayName: 'Bob',
      preferredCurrency: 'USD',
      onboardingComplete: true
    });
    expect(res.status).toBe(200);
    expect(res.body.displayName).toBe('Bob');
    expect(res.body.preferredCurrency).toBe('USD');
    expect(res.body.onboardingComplete).toBe(true);
  });

  it('updates specific fields without overwriting others', async () => {
    await request(app).put('/api/profile').send({ displayName: 'Charlie', preferredCurrency: 'EUR' });
    const res = await request(app).put('/api/profile').send({ onboardingComplete: true });
    expect(res.status).toBe(200);
    expect(res.body.displayName).toBe('Charlie');
    expect(res.body.preferredCurrency).toBe('EUR');
    expect(res.body.onboardingComplete).toBe(true);
  });

  it('updates displayName', async () => {
    await request(app).put('/api/profile').send({ displayName: 'Initial' });
    const res = await request(app).put('/api/profile').send({ displayName: 'Updated' });
    expect(res.status).toBe(200);
    expect(res.body.displayName).toBe('Updated');
  });

  it('returns 422 for invalid onboardingComplete type', async () => {
    const res = await request(app).put('/api/profile').send({ onboardingComplete: 'yes' });
    expect(res.status).toBe(422);
  });
});

describe('GET /api/health', () => {
  it('returns 200 with status ok', async () => {
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toBeDefined();
  });
});
