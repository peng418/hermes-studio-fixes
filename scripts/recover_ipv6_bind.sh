#!/bin/bash
# recover_ipv6_bind.sh — 升级后恢复 IPv6 双栈监听（域名带 AAAA 记录时必需）
#
# 背景: hermes-studio-2 升级/重装会把 dist/server/index.js 的监听默认值重置为 0.0.0.0
#       (IPv4-only)。域名 www.pjcaio.top 同时有 A/AAAA 记录，浏览器优先走 IPv6，
#       无监听者 -> 页面打不开。2026-08-14 首修，2026-08-25 升级复发。
#
# 用法: bash scripts/recover_ipv6_bind.sh [PKGHOME]
#       默认 PKGHOME=/vol2/@apphome/hermes-studio-2
# 幂等: 已修复则跳过。改完需重启应用（应用中心 或 cmd/main restart）。
set -uo pipefail

PKGHOME="${1:-/vol2/@apphome/hermes-studio-2}"
IDX="${PKGHOME}/data/node/lib/node_modules/hermes-web-ui/dist/server/index.js"

if [ ! -f "$IDX" ]; then
  echo "❌ 未找到 ${IDX}，确认 PKGHOME 是否正确"
  exit 1
fi

COUNT=$(grep -c '||"0.0.0.0"' "$IDX" || true)
echo "检测到 '||\"0.0.0.0\"' 默认监听 ${COUNT} 处（期望 0 = 已修复）"

if [ "$COUNT" -gt 0 ]; then
  echo "→ 执行修复（0.0.0.0 -> :: 双栈）..."
  python3 - "$IDX" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8', errors='replace').read()
n = s.count('||"0.0.0.0"')
s2 = s.replace('||"0.0.0.0"', '||"::"')
open(p, 'w', encoding='utf-8').write(s2)
print(f"  替换 {n} 处")
PYEOF
  echo "✅ 修复完成"
else
  echo "✅ 已是双栈（::），无需修复"
fi

echo
echo "== 验证（需重启应用后）=="
echo "  curl -6 http://[::1]:8649/       → 应 HTTP 200（IPv6 通）"
echo "  curl    http://127.0.0.1:8649/   → 应 HTTP 200（IPv4 通）"
echo "  ss -tlnp | grep 8649             → 应显示 *:8649（双栈监听）"
echo "剩余 0.0.0.0 默认监听: $(grep -c '||"0.0.0.0"' "$IDX" || true) 处（UDP 广播等其他 0.0.0.0 属正常，勿动）"
