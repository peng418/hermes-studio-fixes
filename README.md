# hermes-studio-fixes · Hermes Studio (fnOS) 完整源码 + 升级修复基线

> 本仓库 = **Fnos-Hermes-Studio 完整项目源码**（上游 [veenyi/Fnos-Hermes-Studio](https://github.com/veenyi/Fnos-Hermes-Studio)，把 [EKKOLearnAI/hermes-studio](https://github.com/EKKOLearnAI/hermes-studio) 打包为飞牛 fnOS 可安装 FPK）
> \+ **升级链路修复**（2026-08-11/12 实测：更新失败、拉取开发工具失败）。
> 升级官方新版后若问题复现，用本仓库的修复合并回去。

## 目录结构

```
hermes-studio-fixes/
├── .github/workflows/          # CI：auto-update / build（上游原样）
├── app/                        # FPK 应用内容（bin/config/skills/ui）
├── cmd/                        # fnOS 生命周期脚本（install/upgrade/start...）
├── config/bootstrap/           # 版本号（hermes-studio-version.env 等）
├── fnos-skills/                # fnOS Skill 打包
├── preview/                    # 预览素材
├── scripts/
│   ├── build-fpk.sh            # FPK 打包脚本（上游原样）
│   ├── hermes_monitor.py       # 安装监控脚本（上游原样）
│   ├── check_upgrade_env.sh    # 🛠 升级链路环境检查（本仓库新增）
│   ├── recover_upgrade_env.sh  # 🛠 升级链路一键恢复（本仓库新增）
│   └── recover_ipv6_bind.sh    # 🛠 IPv6 双栈监听一键恢复（本仓库新增，升级后必跑）
├── FIXES.md                    # 全部修复的根因 + 验证标记 + 合并指南
└── README.md                   # 本文件
```

## 修复清单

| # | 类型 | 故障 | 修复 |
|---|------|------|------|
| 1 | 源码 | 升级后 `upgrade_callback` 版本检测失效（`HERMES_BIN` 未定义，每次升级异常/误判） | `cmd/upgrade_callback` 补 `NODE_PREFIX`/`HERMES_BIN` 定义 + `toast_err` 空值兜底 |
| 2 | 环境 | `hermes` 报 `not installed in venv` | `data/venv/bin/hermes` 软链到 `hermes-agent/venv/bin/hermes` |
| 3 | 环境 | `hermes update` 无 git origin | 补 `git remote add origin https://github.com/NousResearch/hermes-agent.git` |
| 4 | 环境 | `update --check` 无限卡死（透明代理异常时 git 无超时挂死） | 清远程代理，git 直连走 NAS 全局代理 + `lowSpeedLimit 100 / lowSpeedTime 120` 防御 |
| 5 | 环境 | npm 全局装包 EACCES | `npm prefix → ${PKGHOME}/data/node` + npmmirror registry |
| 6 | 源码 | 升级后 IPv6 域名打不开（监听被重置回 0.0.0.0，域名有 AAAA 记录时浏览器走 IPv6 连不上，8-14 首修 8-25 复发） | `scripts/recover_ipv6_bind.sh` 一键恢复双栈监听 `::`（官方源码已修，见 PR） |

## 升级后合并流程

1. fnOS 应用中心升级 Hermes Studio → 出现更新失败/开发工具拉取失败
2. 环境类（#2~#5）：
   ```bash
   bash scripts/check_upgrade_env.sh /vol6/@apphome/hermes-studio   # 检查
   bash scripts/recover_upgrade_env.sh /vol6/@apphome/hermes-studio # 恢复（幂等）
   ```
   （代理凭证用环境变量 `GIT_SOCKS_PROXY` 传入，不写死在仓库）
3. 源码类（#1、#6）：对比官方新版对应文件，把修复补回去
   - #1：`cmd/upgrade_callback` 的 `NODE_PREFIX`/`HERMES_BIN` 定义（见 FIXES.md）
   - #6：`bash scripts/recover_ipv6_bind.sh ${PKGHOME}`（检测/修复 dist 监听默认值，幂等）
4. 重启应用使生效

## 版本记录

- 2026-08-12：完整源码入库（上游原样）+ 修复 #1（upgrade_callback 源码 bug）+ 修复 #2~#5（升级链路环境脚本）。
