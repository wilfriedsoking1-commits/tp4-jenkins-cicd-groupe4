const request = require('supertest');
const app = require('./index');

describe('Tests de l application TP4 Groupe 4', () => {
  it('GET / doit retourner 200 et le statut OK', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toEqual(200);
    expect(res.body.status).toBe('OK');
    expect(res.body.group).toBe('ITT3-IR Groupe 4');
  });

  it('GET /health doit retourner healthy: true', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toEqual(200);
    expect(res.body.healthy).toBe(true);
  });
});
