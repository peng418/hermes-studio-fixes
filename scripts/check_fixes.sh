#!/bin/bash
# ============================================================
# check_fixes.sh — 防回归检查（只读、幂等）
# 逐条探测 FIXES.md 中已修复的 bug 是否仍然处于修复态。
# 任一修复缺失 → 输出 FAIL 明细 + 退出码非 0。
#
# 用法:
#   bash scripts/check_fixes.sh [PKGHOME]              # 运行期（默认 /vol2/@apphome/hermes-studio-2）
#   bash scripts/check_fixes.sh --webui <path>         # 构建期：只查打包产物的源码类修复
#
# 修复清单（与 FIXES.md 对应）:
#   1. IPv6 双栈绑定   dist/server/index.js 无 '||"0.0.0.0"' 默认
#   2. Profile 400     client 产物 getActiveProfileName 带 '||"default"' 兜底
#   3. HERMES_BIN      upgrade_callback 定义 NODE_PREFIX/HERMES_BIN
#   4. venv 软链       data/venv/bin/hermes 存在（仅运行期）
#   5. git origin      hermes-agent 有 remote origin（仅运行期）
#   6. npm prefix      ~/.npmrc prefix 指向 data/node（仅运行期）
#   7. SPA 子路径前缀  esm socket.io/engine.io 带前缀、无 client_old 残留、无引号错位（构建期）
# ============================================================
set -u

MODE="runtime"
PKGHOME="/vol2/@apphome/hermes-studio-2"
WEBUI=""

if [ "${1:-}" = "--webui" ]; then
    MODE="build"
    WEBUI="${2:-}"
    [ -z "${WEBUI}" ] && { echo "❌ --webui 需要路径参数"; exit 2; }
    [ -d "${WEBUI}" ] || { echo "❌ WEBUI 路径不存在: ${WEBUI}"; exit 2; }
else
    PKGHOME="${1:-/vol2/@apphome/hermes-studio-2}"
    WEBUI="${PKGHOME}/data/node/lib/node_modules/hermes-web-ui"
fi

CMD_DIR="$(cd "$(dirname "$0")/../cmd" 2>/dev/null && pwd)"

FAIL=0
PASS=0

ck() { # ck <编号> <名称> <描述> <结果 0=通过 1=失败>
    if [ "$4" = "0" ]; then
        PASS=$((PASS+1))
        echo "✅ [$1] $2 — 修复在"
    else
        FAIL=$((FAIL+1))
        echo "❌ [$1] $2 — 修复缺失: $3"
    fi
}

echo "== check_fixes (mode=${MODE}) =="

# 1. IPv6 双栈绑定（BIND_HOST 默认值 / listen 兜底不应是 0.0.0.0）
if [ -f "${WEBUI}/dist/server/index.js" ]; then
    if grep -q '||"::"' "${WEBUI}/dist/server/index.js" 2>/dev/null || \
       grep -q "||'::'" "${WEBUI}/dist/server/index.js" 2>/dev/null; then
        ck 1 "IPv6 双栈绑定" "" 0
    else
        ck 1 "IPv6 双栈绑定" "dist/server/index.js 无 :: 兜底（升级可能已覆盖为 0.0.0.0）" 1
    fi
else
    ck 1 "IPv6 双栈绑定" "dist/server/index.js 不存在" 1
fi

# 2. Profile 400 兜底（getActiveProfileName 带 default）
if [ -d "${WEBUI}/dist/client/assets/js" ]; then
    HIT=$(grep -rl 'hermes_active_profile_name' "${WEBUI}/dist/client/assets/js/" 2>/dev/null | head -1)
    if [ -n "${HIT}" ] && grep -q 'default' "${HIT}" 2>/dev/null; then
        ck 2 "Profile 400 兜底" "" 0
    else
        ck 2 "Profile 400 兜底" "client 产物 getActiveProfileName 无 default 兜底（编辑模型会 400）" 1
    fi
else
    ck 2 "Profile 400 兜底" "dist/client/assets/js 不存在" 1
fi

# 3. HERMES_BIN 变量（upgrade_callback 定义）
if [ -f "${CMD_DIR}/upgrade_callback" ]; then
    if grep -q 'HERMES_BIN=' "${CMD_DIR}/upgrade_callback" 2>/dev/null; then
        ck 3 "HERMES_BIN 变量" "" 0
    else
        ck 3 "HERMES_BIN 变量" "upgrade_callback 未定义 HERMES_BIN（升级误判重装）" 1
    fi
else
    ck 3 "HERMES_BIN 变量" "cmd/upgrade_callback 不存在" 1
fi

# 7. SPA 子路径前缀（构建期：esm socket/engine 带前缀、无旧构建残留、无引号错位、无双前缀）
if [ -d "${WEBUI}/dist/client/assets/js" ]; then
    ESM=$(ls ${WEBUI}/dist/client/assets/js/esm-*.js 2>/dev/null | head -1)
    if [ -n "${ESM}" ] && grep -q '"/app/hermes-studio-2/socket\.io' "${ESM}" 2>/dev/null \
       && grep -q '"/app/hermes-studio-2/engine\.io' "${ESM}" 2>/dev/null; then
        ck 7 "SPA 前缀(socket/engine)" "" 0
    else
        ck 7 "SPA 前缀(socket/engine)" "esm 里 socket.io/engine.io 未加 /app/hermes-studio-2 前缀（弹窗 WS 404 白屏）" 1
    fi
    RESID=$(ls -d ${WEBUI}/dist/client_old* ${WEBUI}/dist/*handpatched* 2>/dev/null | wc -l)
    if [ "${RESID}" = "0" ]; then
        ck 7 "SPA 前缀(无残留)" "" 0
    else
        ck 7 "SPA 前缀(无残留)" "dist 混入旧构建残留目录（${RESID} 个），网关可能服务旧版" 1
    fi
    DOUBLE=$(grep -rc '/app/hermes-studio-2/app/hermes-studio-2' "${WEBUI}/dist/client" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
    if [ "${DOUBLE}" = "0" ]; then
        ck 7 "SPA 前缀(无翻倍)" "" 0
    else
        ck 7 "SPA 前缀(无翻倍)" "前缀被二次适配翻倍（${DOUBLE} 处），recover_subpath 非幂等" 1
    fi
else
    ck 7 "SPA 前缀" "dist/client/assets/js 不存在" 1
fi

# 构建期：环境类检查（venv/origin/npm）在打包产物上无意义，跳过
if [ "${MODE}" = "build" ]; then
    echo "----------------------------------------"
    echo "check_fixes(build): PASS=${PASS} FAIL=${FAIL}"
    [ "${FAIL}" = "0" ] && echo "✅ 打包产物全部修复在，可以出包" || echo "❌ ${FAIL} 项修复缺失，禁止出包"
    exit ${FAIL}
fi

# 4. venv 软链（仅运行期）
if [ -e "${PKGHOME}/data/venv/bin/hermes" ]; then
    ck 4 "venv 软链" "" 0
else
    ck 4 "venv 软链" "data/venv/bin/hermes 缺失（CLI 报 not installed in venv；agent 未装时属正常）" 1
fi

# 5. git origin（仅运行期）
if [ -d "${PKGHOME}/hermes-agent/.git" ]; then
    if git -C "${PKGHOME}/hermes-agent" remote get-url origin >/dev/null 2>&1; then
        ck 5 "git origin" "" 0
    else
        ck 5 "git origin" "hermes-agent 无 origin（hermes update 失败）" 1
    fi
else
    ck 5 "git origin" "hermes-agent/.git 不存在（Agent 可能未装）" 1
fi

# 6. npm prefix（仅运行期）
NPMRC="${PKGHOME}/data/.npmrc"
if [ -f "${NPMRC}" ] && grep -q "prefix=${PKGHOME}/data/node" "${NPMRC}" 2>/dev/null; then
    ck 6 "npm prefix" "" 0
else
    ck 6 "npm prefix" "${NPMRC} 未指向 ${PKGHOME}/data/node（npm 全局 EACCES）" 1
fi

echo "----------------------------------------"
echo "check_fixes: PASS=${PASS} FAIL=${FAIL}"
[ "${FAIL}" = "0" ] && echo "✅ 全部修复在，可以打包/升级" || echo "❌ ${FAIL} 项修复缺失，先跑 recover_fixes.sh"
exit ${FAIL}
