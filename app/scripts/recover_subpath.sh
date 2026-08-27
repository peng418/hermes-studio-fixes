#!/bin/bash
# ============================================================
# recover_subpath.sh — SPA 统一网关子路径适配（幂等，v2 全量版）
# 把 hermes-web-ui dist 产物中的根路径引用（/assets、/api、/socket.io 等）
# 加上 /app/hermes-studio-2 前缀，使 iframe 弹窗（网关子路径）下资源/API 不 404。
#
# v2 修复（2026-08-26）：补上 v1 遗漏的两大块，解决「打开是问号/白屏」：
#   1. Vite preload 拼接函数 xR=function(e){return"/"+e} —— 动态 chunk（CSS/JS）
#      全部经它拼成根路径 /assets/... → 网关 404。必须改为带前缀拼接。
#   2. 根路径静态资源/API 白名单不全：补 /assets/、/upload、/chat-run、
#      /global-agent、/group-chat、/notification-sw.js。
#   v1 只处理了 "/api、`/api、/socket.io、/engine.io、/plugins/ 五种形态，
#   漏掉上述路径 → 页面能出 HTML 但 JS/CSS/logo 全部加载失败。
#
# 原理：fnOS 网关把 /app/hermes-studio-2/* 转发到 unix socket（gateway-proxy 再转
# 127.0.0.1:8649）。前端代码里以 "/" 开头的绝对路径会绕过网关（发到根路径），
# 必须加前缀。相对路径基于 iframe base 自动带前缀，无需改。
#
# 用法: bash scripts/recover_subpath.sh [WEBUI_DIST_DIR]
#   默认 /vol2/@apphome/hermes-studio-2/data/node/lib/node_modules/hermes-web-ui/dist
# 幂等: 已有前缀的调用跳过，可重复执行。
# ============================================================
set -uo pipefail

DIST="${1:-/vol2/@apphome/hermes-studio-2/data/node/lib/node_modules/hermes-web-ui/dist}"
PREFIX="/app/hermes-studio-2"

if [ ! -d "${DIST}/client" ]; then
  echo "❌ 未找到 ${DIST}/client，确认路径是否正确"
  exit 1
fi

echo "== SPA 子路径适配 v2: ${DIST}/client 前缀 ${PREFIX} =="

python3 - "${DIST}/client" "${PREFIX}" <<'PYEOF'
import os, re, sys

client, prefix = sys.argv[1], sys.argv[2]
changed = 0

# 根路径白名单：这些开头的字面量必须加前缀（HTTP 资源/API/WS）。
# 注意：前端路由（/hermes/*、/desktop-pet 等）和逻辑字符串（/skill、/fork、
# /anthropic、/dev/poll 等）不在白名单，绝不替换。
PREFIX_WHITELIST = [
    "/logo.png", "/favicon.ico", "/manifest.webmanifest", "/coding-agents/",
    "/assets/", "/icons/", "/socket.io", "/engine.io", "/upload", "/chat-run",
    "/global-agent", "/group-chat", "/notification-sw.js",
]

def fix_js(path):
    global changed
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            src = f.read()
    except Exception:
        return
    o = src
    for wl in PREFIX_WHITELIST:
        for q in ('"', "'", "`"):
            # 引号 + 路径，跳过已带前缀的；不动模板字符串里的变量拼接
            pat = re.compile(re.escape(q) + r'(?!/app/hermes-studio-2/)' + re.escape(wl))
            src = pat.sub(q + prefix + wl, src)
    # Vite preload 拼接函数：xR=function(e){return"/"+e} → 带前缀
    pat_xr = re.compile(r'xR=function\(e\)\{return"/"\+e\}')
    src = pat_xr.sub('xR=function(e){return"' + prefix + '/"+e}', src)
    if src != o:
        with open(path, "w", encoding="utf-8") as f:
            f.write(src)
        changed += 1
        print(f"  ✅ {os.path.relpath(path, client)}")

def fix_html(path):
    global changed
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            src = f.read()
    except Exception:
        return
    o = src
    for q in ('"', "'"):
        pat = re.compile(r'(src|href)=' + re.escape(q) + r'/(?!app/|/)([^' + re.escape(q) + r']+)' + re.escape(q))
        src = pat.sub(r'\1=' + q + prefix + r'/\2' + q, src)
    if src != o:
        with open(path, "w", encoding="utf-8") as f:
            f.write(src)
        changed += 1
        print(f"  ✅ {os.path.relpath(path, client)}")

# 1) index.html 静态资源引用
fix_html(os.path.join(client, "index.html"))

# 2) assets/js 下所有 JS（含 Vite 主 bundle 与动态 chunk）
js_dir = os.path.join(client, "assets", "js")
if os.path.isdir(js_dir):
    for fn in sorted(os.listdir(js_dir)):
        if fn.endswith(".js"):
            fix_js(os.path.join(js_dir, fn))

# 3) 其他子目录 js（coding-agents、icons 等）
for sub in ("coding-agents", "icons"):
    d = os.path.join(client, sub)
    if os.path.isdir(d):
        for root, _dirs, files in os.walk(d):
            for fn in files:
                if fn.endswith(".js"):
                    fix_js(os.path.join(root, fn))

print(f"完成: {changed} 个文件已加前缀 {prefix}")
PYEOF

echo
echo "== 验证 =="
echo "  xR 拼接函数（应含前缀）:"
grep -rho 'xR=function(e){return"[^"]*"\+e}' "${DIST}/client/assets/js/" 2>/dev/null | head -2
echo "  正确前缀计数（应为 >0）:"
grep -rho "\"${PREFIX}/api" "${DIST}/client/assets/js/" 2>/dev/null | wc -l
echo "  残留无前缀 /assets 字面量（应接近 0）:"
grep -rho '"/assets/' "${DIST}/client/assets/js/" 2>/dev/null | wc -l
