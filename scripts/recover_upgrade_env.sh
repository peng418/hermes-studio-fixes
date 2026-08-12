#!/bin/bash
# recover_upgrade_env.sh — 一键恢复 Hermes Studio (fnOS) 升级链路环境（幂等，可重复执行）
# 用法:
#   export GIT_SOCKS_PROXY="socks5h://user:pass@host:1080"   # 可选；未设置则跳过代理配置
#   bash scripts/recover_upgrade_env.sh [PKGHOME]
# 默认 PKGHOME=/vol6/@apphome/hermes-studio
set -u

PKGHOME="${1:-/vol6/@apphome/hermes-studio}"
UPSTREAM_REPO="https://github.com/NousResearch/hermes-agent.git"
NPM_REGISTRY="https://registry.npmmirror.com"

echo "== 恢复 Hermes Studio 升级链路环境 PKGHOME=$PKGHOME =="

# 1. CLI venv 软链接（离线 bundle venv 在源码树，启动器找 data/venv/bin）
mkdir -p "${PKGHOME}/data/venv/bin"
ln -sf "${PKGHOME}/hermes-agent/venv/bin/hermes" "${PKGHOME}/data/venv/bin/hermes"
if [ -x "${PKGHOME}/data/venv/bin/hermes" ]; then
  echo "✅ 1/4 CLI 软链接就绪: data/venv/bin/hermes -> hermes-agent/venv/bin/hermes"
else
  echo "❌ 1/4 软链接失败，检查 ${PKGHOME}/hermes-agent/venv/bin/hermes 是否存在"
  exit 1
fi

# 2. git origin（离线 bundle 打包时不带 remote）
if git -C "${PKGHOME}/hermes-agent" remote -v 2>/dev/null | grep -q origin; then
  echo "✅ 2/4 git origin 已存在"
else
  git -C "${PKGHOME}/hermes-agent" remote add origin "${UPSTREAM_REPO}"
  echo "✅ 2/4 git origin 已补上: ${UPSTREAM_REPO}"
fi

# 3. git 代理 + 低速超时（DNS 劫持防御；代理凭证走环境变量，绝不落盘到仓库）
if [ -n "${GIT_SOCKS_PROXY:-}" ]; then
  git config --global http.proxy "${GIT_SOCKS_PROXY}"
  git config --global https.proxy "${GIT_SOCKS_PROXY}"
  echo "✅ 3/4 git 代理已配置（来自 GIT_SOCKS_PROXY 环境变量）"
else
  echo "ℹ️  3/4 未设置 GIT_SOCKS_PROXY，跳过代理配置（仅配置低速超时）"
fi
git config --global http.lowspeedlimit 100
git config --global http.lowspeedtime 120
echo "✅ 3/4 低速超时已配置: lowSpeedLimit=100, lowSpeedTime=120"

# 4. npm prefix（避免 EACCES）+ 国内镜像
# 直写 ~/.npmrc（幂等）：npm config set 本质也是改这个文件，且不依赖 node 在 PATH
mkdir -p "${HOME}"
touch "${HOME}/.npmrc"
grep -vE '^(prefix|registry)=' "${HOME}/.npmrc" > "${HOME}/.npmrc.tmp" 2>/dev/null || true
mv "${HOME}/.npmrc.tmp" "${HOME}/.npmrc"
printf 'prefix=%s\nregistry=%s\n' "${PKGHOME}/data/node" "${NPM_REGISTRY}" >> "${HOME}/.npmrc"
echo "✅ 4/4 npm prefix=${PKGHOME}/data/node, registry=${NPM_REGISTRY}（写入 ${HOME}/.npmrc）"

echo
echo "== 验证 =="
"${PKGHOME}/data/venv/bin/hermes" --version 2>/dev/null || "${PKGHOME}/hermes-agent/venv/bin/hermes" --version
echo "origin: $(git -C "${PKGHOME}/hermes-agent" remote get-url origin 2>/dev/null)"
echo "npm prefix: $(grep -E '^prefix=' "${HOME}/.npmrc" 2>/dev/null | tail -1 | cut -d= -f2-)"
echo
echo "🎉 恢复完成。升级后如需拉最新代码: hermes update"
