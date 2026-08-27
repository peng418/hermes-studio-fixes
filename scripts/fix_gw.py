#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gateway-proxy.js: 转发响应时剥离 X-Frame-Options / CSP（iframe 弹窗必需）"""
p = "/vol2/@appcenter/hermes-studio-2/server/gateway-proxy.js"
c = open(p).read()
if "x-frame-options" not in c:
    old = "      res.writeHead(proxyRes.statusCode, proxyRes.headers);"
    new = """      const h = { ...proxyRes.headers };
      // iframe 弹窗需要：剥离 X-Frame-Options / CSP frame-ancestors，否则被浏览器拒绝渲染
      delete h["x-frame-options"];
      delete h["content-security-policy"];
      res.writeHead(proxyRes.statusCode, h);"""
    assert old in c, "anchor not found"
    c = c.replace(old, new, 1)
    open(p, "w").write(c)
    print("gateway-proxy.js: CSP strip patched OK")
else:
    print("gateway-proxy.js: already patched")
