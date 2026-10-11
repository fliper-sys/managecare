const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const http = require('node:http');
const test = require('node:test');
const jwt = require('jsonwebtoken');
const { verifyAccessToken } = require('../middleware/auth');

test('verifies current and legacy HS256 plus Supabase ES256 access tokens', async () => {
  const original = {
    current: process.env.JWT_SECRET,
    previous: process.env.JWT_SECRET_PREVIOUS,
    jwksUrl: process.env.SUPABASE_JWKS_URL,
  };
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
  });
  const jwk = {
    ...publicKey.export({ format: 'jwk' }),
    alg: 'ES256',
    kid: 'test-signing-key',
    use: 'sig',
  };
  const server = http.createServer((_req, res) => {
    res.setHeader('Cache-Control', 'public, max-age=60');
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ keys: [jwk] }));
  });

  try {
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const address = server.address();
    process.env.JWT_SECRET = 'test-current-secret';
    process.env.JWT_SECRET_PREVIOUS = 'test-legacy-secret';
    process.env.SUPABASE_JWKS_URL = `http://127.0.0.1:${address.port}/jwks`;

    const current = jwt.sign({ sub: 'current-user' }, process.env.JWT_SECRET, {
      algorithm: 'HS256',
      expiresIn: '5m',
    });
    const legacy = jwt.sign({ sub: 'legacy-user' }, process.env.JWT_SECRET_PREVIOUS, {
      algorithm: 'HS256',
      expiresIn: '5m',
    });
    const asymmetric = jwt.sign({ sub: 'es256-user' }, privateKey, {
      algorithm: 'ES256',
      keyid: jwk.kid,
      expiresIn: '5m',
    });

    assert.equal((await verifyAccessToken(current)).sub, 'current-user');
    assert.equal((await verifyAccessToken(legacy)).sub, 'legacy-user');
    assert.equal((await verifyAccessToken(asymmetric)).sub, 'es256-user');

    const unknownKey = jwt.sign({ sub: 'unknown-user' }, privateKey, {
      algorithm: 'ES256',
      keyid: 'unknown-key',
      expiresIn: '5m',
    });
    await assert.rejects(verifyAccessToken(unknownKey), /Unknown token signing key/);
  } finally {
    await new Promise((resolve) => server.close(resolve));
    if (original.current === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = original.current;
    if (original.previous === undefined) delete process.env.JWT_SECRET_PREVIOUS;
    else process.env.JWT_SECRET_PREVIOUS = original.previous;
    if (original.jwksUrl === undefined) delete process.env.SUPABASE_JWKS_URL;
    else process.env.SUPABASE_JWKS_URL = original.jwksUrl;
  }
});
