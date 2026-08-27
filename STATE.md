# hermes-studio-2 状态卡（2026-08-26 二轮更新）

## 当前状态：✅ 弹窗可用 + 问号已修（本轮）

- 两个实例并存：8648（老，vol6）+ 8649（新，vol2），互不影响
- **新实例登录**：admin / 123456（默认，未改）
- 本轮修复「打开是一个问号」：Vite preload 前缀缺失（详见下）

## 二轮修复（2026-08-26 晚）：打开是问号

### 根因：Vite preload 拼接函数 xR 无前缀
- `dist/client/assets/js/index-*.js` 里 Vite 生成的 preload 辅助函数：
  `xR=function(e){return"/"+e}` → 所有**动态加载的 chunk**（LoginView CSS/JS 等）
  被拼成根路径 `/assets/...` → 打到网关根路径（5566）→ 被 fnOS 网关拦成登录页/404
  → JS 语法错误 → 页面停在 boot-fallback + logo 破图（用户看到的「问号」）
- 上轮 fix_subpath.py / recover_subpath.sh 只处理了 `/api`、`/socket.io`、`/engine.io`、
  `/plugins/` 5 种形态，**漏了 xR 函数 + /assets、/upload、/chat-run、/global-agent、
  /group-chat、/notification-sw.js、/logo.png、/coding-agents/、/icons/** → 复发

### 修复（全链路）
1. **运行版 dist**（/vol2/.../dist/client）：28 个 JS 文件白名单前缀注入 + xR 修复
   （脚本 /tmp/fix_subpath2.py，白名单只动 HTTP 资源，跳过前端路由 /hermes/*）
2. **打包源码 dist**（hermes-studio-2-fpk/app/node/...）：同样修复（25 文件）
3. **recover_subpath.sh 升级 v2**：加 xR 修复 + 全白名单（打包源码 + 运行版
   /vol2/@appcenter/hermes-studio-2/scripts/ 已同步），幂等验证 0 变化
4. 浏览器实测：登录 → 聊天页完整，64 个 assets 全带前缀、0 无前缀资源

## 压缩配置修复（本轮，8648 老实例 config.yaml）
- **根因**：① compression.threshold 0.5（代码默认 0.35）→ 触发晚、每次压得多；
  ② progress_notices false → 压缩进度被网关噪音过滤，看着像卡住；
  ③ auxiliary.compression 为空 → 压缩继承主模型（MOA imgAndView 聚合 8 模型）→
  300s 超时中断（23:00 日志 interrupted_during_api_call）→ 压缩失败
- **修复**：threshold 0.35 / target_ratio 0.3 / progress_notices true /
  auxiliary.compression = deepseek-v4-flash（压缩走单模型，不再 MOA 聚合）
- **生效**：需重启 8648 实例（当前 CLI 会话跑在上面，未重启）

## 一修（闪图标 + 压缩超时 900s）

### 1. 闪图标根因与修复（2026-08-26）
- **根因 A（致命）**：recover_subpath.sh 前缀注入吞开引号：`"/favicon.ico` → `/app/hermes-studio-2"/favicon.ico`
  → HTML 属性畸形 + JS `"/api` → `/app/hermes-studio-2"/api` **JS 语法错误** → 页面白屏一直闪
- **根因 B**：hermes-web-ui 响应头 `X-Frame-Options: DENY` + `CSP frame-ancestors 'none'`
  → iframe 弹窗被浏览器拒绝渲染（老实例 type:url 新窗口打开所以没事）
- **修复**：
  - dist/client 从打包源码干净基线整体覆盖（含全部修复：Profile400/压缩锁/IPv6）
  - 用 `scripts/fix_subpath.py` 正确注入前缀（old[0]+PREFIX+old[1:]）
  - gateway-proxy.js 转发响应剥离 X-Frame-Options/Content-Security-Policy
  - 源码侧：recover_subpath.sh 引号 bug 已修 + 模板字符串形态；gateway-proxy.js 已同步
  - 运行版脚本：`/vol6/@apphome/hermes-studio/hermes-home/workspace/hermes-studio-2-fpk/scripts/{fix_subpath.py,fix_gw.py,remote_fix.sh,remote_restart2.sh}`

### 2. 压缩失败根因与修复
- **根因**：Ekko summarizer（provider=moa）403 地区限制 → fallback Hermes（deepseek 16万 tokens）
  300s 超时（summarizationTimeoutMs 默认 300_000）→ Empty response → 几乎没压（179728→163504）
- **修复**：summarizationTimeoutMs 300s → 900s（4 处：老实例 dist / 新实例 dist / 打包源码 dist / hs-upstream index.ts）
- **生效时机**：重启对应实例后生效（老实例 8648 需重启，当前会话跑在上面所以未重启）

## 关键路径速查
- 打包源码：`/vol6/@apphome/hermes-studio/hermes-home/workspace/hermes-studio-2-fpk/`（build: scripts/build-fpk.sh）
- 源码仓库：`/vol6/@apphome/hermes-studio/hermes-home/workspace/hs-upstream/`
- 运行版 dist：老 `/vol6/@apphome/hermes-studio/data/node/...`；新 `/vol2/@apphome/hermes-studio-2/data/node/...`
- gateway-proxy：`/vol2/@appcenter/hermes-studio-2/server/gateway-proxy.js`（cmd/main start 自动拉起，持久化 OK）
- 管理通道：SSH admin@127.0.0.1（密码=fnclub.keys 的 FNCLUB_PASSWORD）；浏览器 127.0.0.1:5566（访问码 030709）
