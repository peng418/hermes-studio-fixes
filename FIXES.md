# FIXES.md — 升级链路故障根因与修复详解

> 对应 README 的修复清单。每条含：根因、检查命令（输出=未修复）、修复命令。
> 环境变量约定：`PKGHOME` = fnOS 应用目录（本机 `/vol6/@apphome/hermes-studio`）。

---

## 0. 源码修复：upgrade_callback 版本检测失效（2026-08-12 新增）

**现象**：升级 Hermes Studio 后版本检测异常、反复重装或升级流程报错。

**根因**：`cmd/upgrade_callback` 第 3 步检测已安装版本时引用 `HERMES_BIN`，但脚本里**从未定义**该变量（`install_callback` 定义了，`upgrade_callback` 漏了）。`[ -x "${HERMES_BIN}" ]` 恒为 false → `INSTALLED_VER` 永远为空 → 升级逻辑走错分支；`ACTUAL_VER` 处还会执行 `"" --version` 报错。

**修复**（本仓库 `cmd/upgrade_callback` 已应用）：
```bash
# 在 DATA_DIR="${TRIM_PKGHOME}/data" 之后补：
NODE_PREFIX="${DATA_DIR}/node"
HERMES_BIN="${NODE_PREFIX}/bin/hermes-web-ui"
# 另：toast_err 的 $TRIM_TEMP_LOGFILE 补空值兜底 ${TRIM_TEMP_LOGFILE:-/tmp/hermes-studio-upgrade.err}
```

**检查**（官方新版是否已修）：
```bash
grep -n 'HERMES_BIN=' cmd/upgrade_callback   # 有输出=已修；无输出=bug 还在，需合并
```

**验证**：`bash -n cmd/upgrade_callback` 通过；升级时日志出现 `installed: x.y.z, target: x.y.z` 且版本匹配走「无需重装」。

---

## 1. CLI 报 `hermes-agent not installed in venv`

**现象**：任何 `hermes` 命令输出 `hermes-agent not installed in venv. Please reinstall the app.`

**根因**：fnOS 商店启动器 `/usr/local/bin/hermes` 写死找 `${PKGHOME}/data/venv/bin/hermes`；而离线 bundle 安装（`OFFLINE_SRC_FLAG=1`）把 venv 建在源码树 `hermes-agent/venv/`。两边路径不一致，启动器找不到入口脚本。

**检查**：
```bash
test -x ${PKGHOME}/data/venv/bin/hermes && echo OK || echo MISSING
```

**修复**（软链接，幂等）：
```bash
mkdir -p ${PKGHOME}/data/venv/bin
ln -sf ${PKGHOME}/hermes-agent/venv/bin/hermes ${PKGHOME}/data/venv/bin/hermes
```

---

## 2. `hermes update` 报 git origin 缺失

**现象**：`hermes update` 失败，git 报错找不到 origin / `remote-origin is not a git command`。

**根因**：离线 bundle 的 `.git` 仓库打包时不带 remote（避免把构建机的 remote 带出去），首次更新时无远程可拉。

**检查**：
```bash
git -C ${PKGHOME}/hermes-agent remote -v | grep -q origin && echo OK || echo MISSING
```

**修复**：
```bash
git -C ${PKGHOME}/hermes-agent remote add origin https://github.com/NousResearch/hermes-agent.git
```

> 注：8-11 实测该离线 bundle 与官方树仅 stat 差异（8313 文件 0 行内容改动），`git pull` 不冲突。

---

## 3. `hermes update --check` 无限卡死

**现象**：`update --check` / `git fetch` 长时间无响应（几分钟~无限）。

**根因**：NAS 开启全局代理（Clash TUN / fake-ip 模式）时，DNS 解析被代理接管——`getent hosts github.com` 返回保留段地址（198.18.x.x），流量经 TUN 转代理出口。**代理正常时 git/curl 直连即可通（实测毫秒级）**；但当透明代理异常/链路不通时，git 连接会挂起且**默认无超时上限** → 无限卡死。

**检查**：
```bash
timeout 5 getent hosts github.com   # 198.18.x.x = TUN fake-ip，属正常
timeout 20 git ls-remote https://github.com/NousResearch/hermes-agent.git HEAD   # 通=代理链路正常
git config --global --list | grep -E 'proxy|lowSpeed'   # 应无远程代理，可有 lowSpeed 防御
```

**修复**（NAS 有全局代理 → **直连即可，不要配远程 socks 代理**）：
```bash
# 1. 确保没有残留的远程代理配置（已废弃 8.212.182.25 那台）
git config --global --unset-all http.proxy 2>/dev/null
git config --global --unset-all https.proxy 2>/dev/null
# 2. 只保留低速超时防御（代理异常时快速失败而不是无限挂）
git config --global http.lowspeedlimit 100
git config --global http.lowspeedtime 120
# 3. 验证
timeout 30 git ls-remote https://github.com/peng418/hermes-studio-fixes.git HEAD
```

> ⚠️ 若 NAS 全局代理关闭了，再按需配置代理（本机 Clash 常见端口：HTTP 7890 / SOCKS5 7891，指向 127.0.0.1）。

---

## 4. `npm install -g` / 拉取开发工具 EACCES

**现象**：`npm install -g <pkg>` 报 `EACCES: permission denied`，或全局包装进 root 目录导致普通用户进程读不到。

**根因**：npm prefix 指向系统 Node 运行时全局目录（本机 `/vol6/@appcenter/nodejs_v24`），该目录属 root，`hermes-studio` 用户无写权限。

**检查**：
```bash
npm config get prefix   # 应为 ${PKGHOME}/data/node，而非 @appcenter 路径
```

**修复**：
```bash
npm config set prefix ${PKGHOME}/data/node
npm config set registry https://registry.npmmirror.com
```

---

## 验证标记速查

修复全部完成后：

| 检查项 | 期望 |
|--------|------|
| `hermes --version` | 输出版本号（不再报 not installed） |
| `hermes update --check` | 35s 内返回，不卡死 |
| `git -C ${PKGHOME}/hermes-agent remote -v` | 有 origin |
| `npm config get prefix` | `${PKGHOME}/data/node` |
