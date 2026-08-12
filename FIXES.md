# FIXES.md — 升级链路故障根因与修复详解

> 对应 README 的 4 项故障。每条含：根因、检查命令（输出=未修复）、修复命令。
> 环境变量约定：`PKGHOME` = fnOS 应用目录（本机 `/vol6/@apphome/hermes-studio`）。

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

**根因**：出口 DNS 被透明代理劫持——`getent hosts github.com` 返回保留段地址（如 198.18.0.19），该代理对 git 协议支持不完整，git 连接挂起且**默认无超时上限**。

**检查**：
```bash
timeout 5 getent hosts github.com   # 若返回 198.18.x.x / 10.x / 保留段 = 被劫持
git config --global --list | grep -E 'proxy|lowSpeed'   # 应看到代理 + lowSpeedLimit
```

**修复**（走 socks 代理 + 低速超时，实测 fetch 35s 完成）：
```bash
git config --global http.proxy "${GIT_SOCKS_PROXY}"        # 例: socks5h://user:pass@host:1080
git config --global https.proxy "${GIT_SOCKS_PROXY}"
git config --global http.lowspeedlimit 100
git config --global http.lowspeedtime 120
```

> ⚠️ 凭证红线：代理的用户名/密码**不要写进本仓库任何文件**，用环境变量 `GIT_SOCKS_PROXY` 传递（脚本支持）。

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
