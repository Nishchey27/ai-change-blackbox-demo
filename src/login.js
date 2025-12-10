function login({ user, pass }) {
  const VALID_USERS = {
    nish: 'ok',
    alice: 'secret',
  };

  if (!user || !pass) {
    return false;
  }

  // BUG: accidentally used != instead of ===
  return VALID_USERS[user] != pass;
}

module.exports = { login };
