#!/usr/bin/env python3
# 注入防回归门禁 + socket 桥接（幂等版：带哨兵标记，重复运行安全）
import os

ROOT = "/vol6/@apphome/hermes-studio/hermes-home/workspace/hermes-studio-2-fpk"

def read(p):
    with open(p, "rb") as f:
        return f.read()

def write(p, data):
    with open(p, "wb") as f:
        f.write(data)

def inject(p, anchor, block, sentinel, before=True):
    """在 anchor 前/后插入 block；若已存在 sentinel 则跳过。保持 LF。"""
    data = read(p)
    if sentinel.encode() in data:
        print(f"  ⏭️  {os.path.basename(p)}: 已注入（sentinel 命中），跳过")
        return
    text = data  # cmd/ 已统一 LF
    n = text.count(anchor)
    if n == 0:
        print(f"  ⚠️ {os.path.basename(p)}: 锚点未找到: {anchor[:50]!r}")
        return
    if before:
        text = text.replace(anchor, block + anchor, 1)
    else:
        text = text.replace(anchor, anchor + block, 1)
    write(p, text)
    print(f"  ✅ {os.path.basename(p)}: 注入 {n} 处")

# ── 1. cmd/main ──
MAIN = os.path.join(ROOT, "cmd/main")

# 1a. 函数定义（start_process 前）
main_funcs = """# ── 防回归门禁 + 网关桥接（inject_gates 注入）──
SENTINEL_FIX_GATE=1

run_fix_gate() {
    local check="${TRIM_APPDEST}/scripts/check_fixes.sh"
    [ -f "${check}" ] || return 0
    if ! bash "${check}" "${TRIM_PKGHOME}" >/dev/null 2>&1; then
        log_msg "WARNING: fixes missing, running recover_fixes.sh ..."
        bash "${TRIM_APPDEST}/scripts/recover_fixes.sh" "${TRIM_PKGHOME}" >> "${LOG_FILE}" 2>&1 || \\
            log_msg "WARNING: recover_fixes.sh failed (strategy A: continue)"
    else
        log_msg "fix gate: all fixes in place"
    fi
}

start_gateway_proxy() {
    local proxy="${TRIM_APPDEST}/server/gateway-proxy.js"
    [ -f "${proxy}" ] || return 0
    if pgrep -f "hermes-studio-2.sock" >/dev/null 2>&1; then
        log_msg "gateway-proxy already running"
        return 0
    fi
    log_msg "starting gateway-proxy (${TRIM_APPDEST}/hermes-studio-2.sock -> 127.0.0.1:${PORT})"
    TRIM_APPDEST="${TRIM_APPDEST}" GATEWAY_PREFIX="/app/hermes-studio-2" HS2_PORT="${PORT}" \\
        nohup "${NODE_BIN}" "${proxy}" >> "${LOG_FILE}" 2>&1 &
}

"""
inject(MAIN, b"start_process() {\n", main_funcs.encode(), "SENTINEL_FIX_GATE=1", before=True)

# 1b. start_process 开头调用 run_fix_gate
inject(MAIN, b"start_process() {\n    # \xe5\x90\xaf\xe5\x8a\xa8\xe5\x89\x8d\xe5\xbc\xba\xe5\x88\xb6\xe6\xb8\x85\xe7\x90\x86",
       b"start_process() {\n    # \xe9\x98\xb2\xe5\x9b\x9e\xe5\xbd\x92\xe9\x97\xa8\xe6\xa3\x80\n    run_fix_gate\n    # \xe5\x90\xaf\xe5\x8a\xa8\xe5\x89\x8d\xe5\xbc\xba\xe5\x88\xb6\xe6\xb8\x85\xe7\x90\x86",
       "start_gateway_proxy() {\n    local proxy", before=False)

# 1c. 启动成功后拉起 socket 桥接
inject(MAIN, b'log_msg "started, port ${PORT} listening"',
       b'log_msg "started, port ${PORT} listening"\n            start_gateway_proxy',
       "start_gateway_proxy() {\n    local proxy", before=False)
inject(MAIN, b'log_msg "started, server log reports listening on port ${PORT}"',
       b'log_msg "started, server log reports listening on port ${PORT}"\n            start_gateway_proxy',
       "start_gateway_proxy() {\n    local proxy", before=False)

# 1d. stop 清理桥接
inject(MAIN, b"stop_process() {\n    log_msg \"stopping hermes-web-ui ...\"",
       b"stop_process() {\n    log_msg \"stopping hermes-web-ui ...\"\n    pkill -f \"hermes-studio-2.sock\" 2>/dev/null || true",
       "SENTINEL_FIX_GATE=1", before=False)

# ── 2. cmd/upgrade_callback ──
UPGRADE = os.path.join(ROOT, "cmd/upgrade_callback")
upgrade_block = """# ── 防回归门禁：check → recover → verify（策略A：失败警告继续）──
SENTINEL_UPGRADE_FIXGATE=1
if [ -f "${APP_DIR}/scripts/check_fixes.sh" ]; then
    log_msg "=== 防回归检查 ==="
    if bash "${APP_DIR}/scripts/check_fixes.sh" "${TRIM_PKGHOME}" >> "${LOG_FILE}" 2>&1; then
        log_msg "✅ 全部修复在，无需恢复"
    else
        log_msg "⚠️ 检测到修复缺失，执行 recover_fixes.sh ..."
        bash "${APP_DIR}/scripts/recover_fixes.sh" "${TRIM_PKGHOME}" >> "${LOG_FILE}" 2>&1 || \\
            log_msg "WARNING: recover_fixes.sh 失败（策略A：警告继续，下次启动重试）"
    fi
fi

"""
inject(UPGRADE, b'log_msg "upgrade_callback finished successfully."', upgrade_block.encode(), "SENTINEL_UPGRADE_FIXGATE=1", before=True)

# ── 3. cmd/install_callback ──
INSTALL = os.path.join(ROOT, "cmd/install_callback")
install_block = """# ── 防回归门禁：check → recover → verify（策略A：失败警告继续）──
SENTINEL_INSTALL_FIXGATE=1
if [ -f "${APP_DIR}/scripts/check_fixes.sh" ]; then
    log_msg "=== 防回归检查 ==="
    if bash "${APP_DIR}/scripts/check_fixes.sh" "${TRIM_PKGHOME}" >> "${LOG_FILE}" 2>&1; then
        log_msg "✅ 全部修复在，无需恢复"
    else
        log_msg "⚠️ 检测到修复缺失，执行 recover_fixes.sh ..."
        bash "${APP_DIR}/scripts/recover_fixes.sh" "${TRIM_PKGHOME}" >> "${LOG_FILE}" 2>&1 || \\
            log_msg "WARNING: recover_fixes.sh 失败（策略A：警告继续，下次启动重试）"
    fi
fi

"""
inject(INSTALL, b'log_msg "install_callback finished successfully."', install_block.encode(), "SENTINEL_INSTALL_FIXGATE=1", before=True)

# ── 4. scripts/build-fpk.sh ──
BUILD = os.path.join(ROOT, "scripts/build-fpk.sh")
build_block = """# ── 防回归构建门禁：打包产物修复缺失则拒绝出包 ──
SENTINEL_BUILD_FIXGATE=1
if [ -f "scripts/check_fixes.sh" ] && [ -d "app/node/lib/node_modules/hermes-web-ui" ]; then
    echo ">>> 防回归构建门禁：检查打包产物修复状态 ..."
    if ! bash scripts/check_fixes.sh --webui app/node/lib/node_modules/hermes-web-ui; then
        echo "::error:: 打包产物存在未修复项，禁止出包。先修复后再构建。" >&2
        exit 1
    fi
    echo ">>> 构建门禁通过"
fi

"""
inject(BUILD, b"ensure_node_bundle\n", build_block.encode(), "SENTINEL_BUILD_FIXGATE=1", before=True)

print("\n全部注入完成")
