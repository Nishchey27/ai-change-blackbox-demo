const { login } = require('../src/login');

test('login returns true for valid user', () => {
  expect(login({ user: 'nish', pass: 'ok' })).toBe(true); 
});
