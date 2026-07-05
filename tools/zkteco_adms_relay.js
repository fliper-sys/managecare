#!/usr/bin/env node

const http = require('http');
const https = require('https');

const listenPort = Number.parseInt(process.env.PORT || '7005', 10);
const listenHost = process.env.HOST || '0.0.0.0';
const upstreamHost =
  process.env.ZK_UPSTREAM_HOST ||
  'us-central1-manage-care-1e96b.cloudfunctions.net';
const upstreamFunctionPath = `/${(process.env.ZK_UPSTREAM_FUNCTION || 'iclock')
  .replace(/^\/+|\/+$/g, '')}`;

function upstreamPathFor(requestUrl) {
  const url = new URL(requestUrl, 'http://zkteco-device');
  const path = url.pathname.toLowerCase();

  if (path === '/' || path === '') {
    return `${upstreamFunctionPath}${url.search}`;
  }

  if (path.startsWith(upstreamFunctionPath.toLowerCase())) {
    return `${url.pathname}${url.search}`;
  }

  return `${upstreamFunctionPath}${url.pathname}${url.search}`;
}

function forward(req, res, body) {
  const upstreamPath = upstreamPathFor(req.url || '/');
  const upstreamReq = https.request(
    {
      hostname: upstreamHost,
      method: req.method,
      path: upstreamPath,
      headers: {
        ...req.headers,
        host: upstreamHost,
        'x-forwarded-host': req.headers.host || '',
        'x-forwarded-proto': 'http',
      },
    },
    (upstreamRes) => {
      res.writeHead(upstreamRes.statusCode || 502, upstreamRes.headers);
      upstreamRes.pipe(res);
    }
  );

  upstreamReq.on('error', (error) => {
    console.error('[zkteco-adms-relay] upstream error', error);
    res.writeHead(502, { 'content-type': 'text/plain; charset=utf-8' });
    res.end('ERROR');
  });

  if (body.length > 0) {
    upstreamReq.write(body);
  }
  upstreamReq.end();
}

const server = http.createServer((req, res) => {
  const chunks = [];
  req.on('data', (chunk) => chunks.push(chunk));
  req.on('end', () => {
    const body = Buffer.concat(chunks);
    console.log(
      `[zkteco-adms-relay] ${req.method} ${req.url} -> ${upstreamHost}${upstreamPathFor(req.url || '/')}`
    );
    forward(req, res, body);
  });
});

server.listen(listenPort, listenHost, () => {
  console.log(
    `[zkteco-adms-relay] listening on ${listenHost}:${listenPort}, forwarding to https://${upstreamHost}${upstreamFunctionPath}`
  );
});
