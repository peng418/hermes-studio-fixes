#!/bin/bash
# ============================================================
# recover_fixes.sh — 防回归一键恢复（幂等，可重复执行）
# 聚合全部已知修复的恢复逻辑：
#   1. 升级链路环境（venv 软链 / git origin / 代理清理 / npm prefix）
#   2. IPv6 双栈监听（dist/server/index.js 0.0.0.0 -> ::）
#   3. Profile 400 兜底（client 产物 getActiveProfileName 补 default）
#   4. SPA 子路径适配（/app/hermes-studio-2 前缀）
#
# 用法: bash scripts/recover_fixes.sh [PKGHOME]
#   默认 PKGHOME=/vol2/@apphome/hermes-studio-2
# ============================================================
set -u

PKGHOME="${1:-/vol2/@apphome/hermes-studio-2}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEBUI="${PKGHOME}/data/node/lib/node_modules/hermes-web-ui"
DIST="${WEBUI}/dist"

echo "== 恢复 Hermes Studio 2 全部修复 PKGHOME=${PKGHOME} =="

# 1. 升级链路环境（venv/origin/代理/npm prefix）
if [ -f "${SCRIPT_DIR}/recover_upgrade_env.sh" ]; then
  echo "--- [1/4] 升级链路环境 ---"
  bash "${SCRIPT_DIR}/recover_upgrade_env.sh" "${PKGHOME}" || echo "  ⚠️ 环境恢复有警告（继续）"
else
  echo "--- [1/4] 跳过：recover_upgrade_env.sh 不存在 ---"
fi

# 2. IPv6 双栈监听
if [ -f "${SCRIPT_DIR}/recover_ipv6_bind.sh" ]; then
  echo "--- [2/4] IPv6 双栈监听 ---"
  bash "${SCRIPT_DIR}/recover_ipv6_bind.sh" "${PKGHOME}" || echo "  ⚠️ IPv6 恢复有警告（继续）"
else
  echo "--- [2/4] 跳过：recover_ipv6_bind.sh 不存在 ---"
fi

# 3. Profile 400 兜底（client 产物补 default）
if [ -d "${DIST}/client" ] && [ -f "${SCRIPT_DIR}/patch_profile_default.py" ]; then
  echo "--- [3/4] Profile 400 兜底 ---"
  python3 "${SCRIPT_DIR}/patch_profile_default.py" "${DIST}/client" || echo "  ⚠️ Profile 400 恢复有警告（继续）"
else
  echo "--- [3/4] 跳过：patch_profile_default.py 或 dist/client 不存在 ---"
fi

# 4. SPA 子路径适配
if [ -d "${DIST}/client" ] && [ -f "${SCRIPT_DIR}/recover_subpath.sh" ]; then
  echo "--- [4/4] SPA 子路径适配 ---"
  bash "${SCRIPT_DIR}/recover_subpath.sh" "${DIST}" || echo "  ⚠️ 子路径适配有警告（继续）"
else
  echo "--- [4/4] 跳过：recover_subpath.sh 或 dist/client 不存在 ---"
fi

echo
echo "== 验证 =="
bash "${SCRIPT_DIR}/check_fixes.sh" "${PKGHOME}" || true
echo
echo "🎉 recover_fixes 完成（任何失败项请查看上方 ⚠️/❌ 输出）"
