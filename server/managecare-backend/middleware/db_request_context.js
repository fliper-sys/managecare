const { AsyncLocalStorage } = require('async_hooks');

const requestStorage = new AsyncLocalStorage();
const wrappedClient = Symbol('managecare.requestScopedClient');

function getRequestUserId() {
  return requestStorage.getStore()?.userId || null;
}

function runWithUser(userId, callback) {
  return requestStorage.run({ userId }, callback);
}

function bindPoolToRequestUser(pool) {
  const originalConnect = pool.connect.bind(pool);

  const wrapClient = (client) => {
    if (client[wrappedClient]) return client;
    const originalQuery = client.query.bind(client);
    client.query = (...args) => {
      const callback = typeof args[args.length - 1] === 'function'
        ? args.pop()
        : null;
      const sql = typeof args[0] === 'string' ? args[0] : args[0]?.text || '';
      const endsTransaction = /^\s*(COMMIT|END|ROLLBACK)\b/i.test(sql);
      const userId = getRequestUserId();
      const claims = userId
        ? JSON.stringify({ sub: userId, role: 'authenticated' })
        : '{}';

      const operation = (async () => {
        if (endsTransaction) {
          try {
            return await originalQuery(...args);
          } finally {
            await originalQuery(
              `SELECT set_config('request.jwt.claim.sub', '', false),
                      set_config('request.jwt.claims', '{}', false)`,
            ).catch(() => {});
          }
        }
        await originalQuery(
          `SELECT set_config('request.jwt.claim.sub', $1, false),
                  set_config('request.jwt.claims', $2, false)`,
          [userId || '', claims],
        );
        try {
          return await originalQuery(...args);
        } finally {
          await originalQuery(
            `SELECT set_config('request.jwt.claim.sub', '', false),
                    set_config('request.jwt.claims', '{}', false)`,
          ).catch(() => {});
        }
      })();

      if (callback) {
        operation.then((result) => callback(null, result), callback);
        return;
      }
      return operation;
    };
    client[wrappedClient] = true;
    return client;
  };

  pool.connect = (callback) => {
    const connection = originalConnect();
    if (typeof callback === 'function') {
      connection.then((client) => callback(
        null,
        wrapClient(client),
        client.release.bind(client),
      ), callback);
      return;
    }
    return connection.then(wrapClient);
  };

  pool.query = (...args) => {
    const callback = typeof args[args.length - 1] === 'function'
      ? args.pop()
      : null;
    const operation = pool.connect().then(async (client) => {
      try {
        return await client.query(...args);
      } finally {
        client.release();
      }
    });
    if (callback) {
      operation.then((result) => callback(null, result), callback);
      return;
    }
    return operation;
  };

  return pool;
}

module.exports = { bindPoolToRequestUser, getRequestUserId, runWithUser };
