#!/bin/bash
# check_upgrade_env.sh — 检查 Hermes Studio (fnOS) 升级链路环境，只读、幂等
# 用法: bash scripts/check_upgrade_env.sh [PKGHOME]
# 默认 PKGHOME=/vol2/@apphome/hermes-studio-2
set -u

PKGHOME="${1:-/vol2/@apphome/hermes-studio-2}"
FAIL=0

say()  { printf '%-10s %s\n' "$1" "$2"; }
fail() { say "❌ FAIL" "$1"; FAIL=1; }
ok()   { say "✅ OK" "$1"; }

echo "== PKGHOME=$PKGHOME =="

# 1. CLI venv 软链接
if [ -x "${PKGHOME}/data/venv/bin/hermes" ]; then
  ok "data/venv/bin/hermes 存在"
else
  fail "data/venv/bin/hermes 缺失 → hermes CLI 会报 not installed in venv"
fi

# 2. git origin
if git -C "${PKGHOME}/hermes-agent" remote -v 2>/dev/null | grep -q origin; then
  ok "hermes-agent git origin 存在"
else
  fail "hermes-agent 缺 git origin → hermes update 无法拉取"
fi

# 3. git 代理 + 低速超时（DNS 劫持防御）
PROXY_CNT=$(git config --global --list 2>/dev/null | grep -cE '^http.*proxy=')
LOWSPEED=$(git config --global --get http.lowspeedlimit 2>/dev/null || echo 0)
if [ "${PROXY_CNT}" -ge 2 ] && [ "${LOWSPEED}" -ge 100 ]; then
  ok "git 代理 + lowSpeedLimit=${LOWSPEED} 已配置"
else
  fail "git 代理或低速超时未配置 → update --check 可能无限卡死"
fi

# 4. npm prefix（npm 可能不在 PATH，读 ~/.npmrc 兜底）
NPM_PREFIX=$(npm config get prefix 2>/dev/null || true)
if [ -z "${NPM_PREFIX}" ] && [ -f "${HOME}/.npmrc" ]; then
  NPM_PREFIX=$(grep -E '^prefix=' "${HOME}/.npmrc" | tail -1 | cut -d= -f2-)
fi
case "${NPM_PREFIX}" in
  "${PKGHOME}/data/node")
    ok "npm prefix=${NPM_PREFIX}"
    ;;
  "")
    fail "npm prefix 未知（npm 不在 PATH 且 ~/.npmrc 无 prefix 行）"
    ;;
  *)
    fail "npm prefix=${NPM_PREFIX}（应为 ${PKGHOME}/data/node）→ 装全局包会 EACCES"
    ;;
esac

echo
if [ "${FAIL}" -eq 0 ]; then
  echo "🎉 全部通过，升级链路环境正常"
else
  echo "⚠️ 存在缺失项，运行: bash scripts/recover_upgrade_env.sh ${PKGHOME}"
  exit 1
fi
