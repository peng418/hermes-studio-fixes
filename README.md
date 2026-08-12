# hermes-studio-fixes · Hermes Studio (fnOS) 升级修复基线

> **用途**：保存 Hermes Studio（fnOS fpk 版，上游项目 [Fnos-Hermes-Studio](https://github.com/veenyi/Fnos-Hermes-Studio)）升级链路的自研修复。
> 每次从 fnOS 应用中心**升级 Hermes Studio 后**，若出现「更新失败 / 拉取开发工具失败」类问题，按本仓库 `FIXES.md` 检查并用 `scripts/` 恢复。

## 覆盖的故障（2026-08-11 实测修复）

| # | 故障现象 | 根因 | 修复 |
|---|---------|------|------|
| 1 | 运行 `hermes` 报 `hermes-agent not installed in venv. Please reinstall the app.` | fnOS 启动器写死找 `${PKGHOME}/data/venv/bin/hermes`，但离线 bundle 把 venv 建在源码树 `hermes-agent/venv/` | `data/venv/bin/hermes` 软链接到源码树 venv |
| 2 | `hermes update` 报 `git: 'remote-origin' is not a git command` / origin 缺失 | 离线 bundle 的 `.git` 不带 remote | 补 `git remote add origin https://github.com/NousResearch/hermes-agent.git` |
| 3 | `hermes update --check` 无限卡死 | 出口 DNS 被透明代理劫持（`getent hosts github.com` → 198.18.x.x 保留段），git 协议被不完整代理破坏且无超时 | git 走 socks 代理 + `http.lowSpeedLimit 100 / lowSpeedTime 120`（实测 35s 完成 fetch） |
| 4 | `npm install -g` 报 EACCES 权限不足 | npm prefix 指向系统 Node 全局目录（`/vol6/@appcenter/nodejs_v24`），普通用户无写权限 | `npm config set prefix ${PKGHOME}/data/node`，registry 用 npmmirror |

## 快速使用

```bash
# 1. 先检查环境哪里坏了（输出缺失项）
bash scripts/check_upgrade_env.sh /vol6/@apphome/hermes-studio

# 2. 一键恢复（幂等，可重复执行）
export GIT_SOCKS_PROXY="socks5h://user:pass@host:port"   # 可选：有代理才设，没有就跳过
bash scripts/recover_upgrade_env.sh /vol6/@apphome/hermes-studio

# 3. 验证
hermes --version && hermes update --check
```

## 仓库结构

```
hermes-studio-fixes/
├── README.md                        # 本文件
├── FIXES.md                         # 各故障根因详解 + 手工修复命令 + 验证标记
└── scripts/
    ├── check_upgrade_env.sh         # 环境检查（幂等，只读）
    └── recover_upgrade_env.sh       # 一键恢复（幂等，可重复执行）
```

## 合并流程（升级后）

1. fnOS 应用中心升级 Hermes Studio → 出现上述任一故障
2. `bash scripts/check_upgrade_env.sh <PKGHOME>` 定位缺失项
3. `bash scripts/recover_upgrade_env.sh <PKGHOME>` 恢复
4. 若官方改版导致脚本不适用：以官方新版为准，按 `FIXES.md` 中的修复点手工合并

## 版本记录

- 2026-08-12：初版。收录 2026-08-11 在 `/vol6/@apphome/hermes-studio` 实测的 4 项升级链路修复。
