#!/usr/bin/env node
/**
 * Hermes Studio 2 统一网关桥接代理
 * fnOS 统一网关把 /app/hermes-studio-2/* 请求转发到本 unix socket，
 * 本代理将请求转给本机 hermes-web-ui (127.0.0.1:8649)，并处理：
 *   - 剥离 /app/hermes-studio-2 前缀（hermes-web-ui 路由无前缀感知）
 *   - 改写 Host 为 127.0.0.1:8649（loopback 放行，避免 fence/鉴权异常）
 *   - 删除 Origin/Referer（部分中间件对跨源敏感）
 *   - WebSocket upgrade 转发（hermes-web-ui 的 socket.io / chat-run / tts 是 WS）
 */
const http = require("http");
const net = require("net");
const fs = require("fs");
const path = require("path");

const APP_DEST = process.env.TRIM_APPDEST || "/vol2/@appcenter/hermes-studio-2";
const SOCKET_PATH = process.env.GATEWAY_SOCKET_PATH || path.join(APP_DEST, "hermes-studio-2.sock");
const PREFIX = process.env.GATEWAY_PREFIX || "/app/hermes-studio-2";
const TARGET_HOST = "127.0.0.1";
const TARGET_PORT = Number(process.env.HS2_PORT || 8649);

function stripPrefix(url) {
  if (url === PREFIX) return "/";
  if (url.startsWith(PREFIX + "/")) return url.slice(PREFIX.length);
  return url;
}

function rewriteHeaders(headers) {
  const h = { ...headers };
  h.host = `${TARGET_HOST}:${TARGET_PORT}`;
  delete h.origin;
  delete h.referer;
  return h;
}

const server = http.createServer((req, res) => {
  req.url = stripPrefix(req.url);
  const proxyReq = http.request(
    { host: TARGET_HOST, port: TARGET_PORT, path: req.url, method: req.method, headers: rewriteHeaders(req.headers) },
    (proxyRes) => {
      const h = { ...proxyRes.headers };
      // iframe 弹窗需要：剥离 X-Frame-Options / CSP frame-ancestors，否则被浏览器拒绝渲染（2026-08-26 实测）
      delete h["x-frame-options"];
      delete h["content-security-policy"];
      res.writeHead(proxyRes.statusCode, h);
      proxyRes.pipe(res);
    }
  );
  proxyReq.on("error", (e) => {
    res.writeHead(502, { "content-type": "text/plain" });
    res.end("gateway proxy error: " + e.message);
  });
  req.pipe(proxyReq);
});

server.on("upgrade", (req, socket, head) => {
  req.url = stripPrefix(req.url);
  const proxySocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
    const headLines = Object.entries(rewriteHeaders(req.headers))
      .map(([k, v]) => `${k}: ${v}`)
      .join("\r\n");
    proxySocket.write(`${req.method} ${req.url} HTTP/1.1\r\n${headLines}\r\n\r\n`);
    if (head && head.length) proxySocket.write(head);
  });
  proxySocket.on("error", () => socket.destroy());
  socket.on("error", () => proxySocket.destroy());
  proxySocket.on("connect", () => {
    socket.pipe(proxySocket);
    proxySocket.pipe(socket);
  });
});

try { fs.unlinkSync(SOCKET_PATH); } catch (e) { /* 首次启动无旧 socket */ }
fs.mkdirSync(path.dirname(SOCKET_PATH), { recursive: true });
server.listen(SOCKET_PATH, () => {
  try { fs.chmodSync(SOCKET_PATH, 0o666); } catch (e) {}
  console.log(`[gateway-proxy] listening on ${SOCKET_PATH} -> ${TARGET_HOST}:${TARGET_PORT} (prefix ${PREFIX})`);
});
