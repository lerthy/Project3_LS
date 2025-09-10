import { handler } from './index.js';

jest.mock('pg', () => {
  const connect = jest.fn();
  const end = jest.fn();
  const query = jest.fn(async (sql) => {
    // simulate INSERT returning row (robust to whitespace/newlines)
    if (typeof sql === 'string' && /insert\s+into\s+contacts/i.test(sql)) {
      return { rows: [{ id: 1, created_at: '2025-01-01T00:00:00Z' }] };
    }
    return { rows: [] };
  });
  // expose for per-test control
  global.__pgMock = { connect, end, query };
  return {
    Client: jest.fn(() => ({ connect, end, query }))
  };
});

const baseBody = {
  fullName: 'Jane Doe',
  email: 'jane@example.com',
  phone: '123',
  company: 'Acme',
  jobTitle: 'Engineer',
  country: 'US',
  city: 'NYC',
  message: 'Hello'
};

describe('Lambda handler', () => {
  it('handles OPTIONS preflight', async () => {
    const res = await handler({ httpMethod: 'OPTIONS' });
    expect(res.statusCode).toBe(200);
  });

  it('rejects non-POST methods', async () => {
    const res = await handler({ httpMethod: 'GET' });
    expect(res.statusCode).toBe(405);
  });

  it('rejects invalid JSON', async () => {
    const res = await handler({ httpMethod: 'POST', body: '{' });
    expect(res.statusCode).toBe(400);
  });

  it('rejects missing fields', async () => {
    const body = { ...baseBody, email: '' };
    const res = await handler({ httpMethod: 'POST', body: JSON.stringify(body) });
    expect(res.statusCode).toBe(400);
  });

  it('rejects invalid email', async () => {
    const body = { ...baseBody, email: 'bad' };
    const res = await handler({ httpMethod: 'POST', body: JSON.stringify(body) });
    expect(res.statusCode).toBe(400);
  });

  it('inserts contact and returns success', async () => {
    process.env.DB_HOST = 'host';
    process.env.DB_USER = 'user';
    process.env.DB_PASS = 'pass';
    process.env.DB_NAME = 'db';

    const res = await handler({ httpMethod: 'POST', body: JSON.stringify(baseBody) });
    expect(res.statusCode).toBe(200);
    const payload = JSON.parse(res.body);
    expect(payload.success).toBe(true);
    expect(payload.id).toBe(1);
  });

  it('returns 503 when DB connection fails', async () => {
    // make connect throw
    global.__pgMock.connect.mockRejectedValueOnce(Object.assign(new Error('ECONNREFUSED'), { code: 'ECONNREFUSED' }));
    const res = await handler({ httpMethod: 'POST', body: JSON.stringify(baseBody) });
    expect(res.statusCode).toBe(503);
    const payload = JSON.parse(res.body);
    expect(payload.success).toBe(false);
    expect(payload.error).toMatch(/Database connection failed/i);
  });

  it('returns 409 on duplicate entry error', async () => {
    // first connect ok, table create ok, then insert fails with duplicate
    global.__pgMock.connect.mockResolvedValueOnce();
    // first query (CREATE TABLE) resolve
    global.__pgMock.query.mockResolvedValueOnce({ rows: [] });
    // second query (INSERT) rejects with duplicate code
    global.__pgMock.query.mockRejectedValueOnce(Object.assign(new Error('duplicate'), { code: '23505' }));
    const res = await handler({ httpMethod: 'POST', body: JSON.stringify(baseBody) });
    expect(res.statusCode).toBe(409);
    const payload = JSON.parse(res.body);
    expect(payload.success).toBe(false);
    expect(payload.error).toMatch(/Duplicate entry/i);
  });
});


