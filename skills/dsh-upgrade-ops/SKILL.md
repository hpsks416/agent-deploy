---
name: dsh-upgrade-ops
description: DSH 升级/闪退定位。升级必须同步「全局 CLI @deepseek-ai/dsh」与「profile 的 dsh-base/dsh-web-app」两处，否则 resolveBundleDir 优先加载旧 bundle 必闪退。含本机非标准 pnpm-global 路径、三 store 打架、插件 peer 失配等坑。触发词：升级 DSH、DSH 闪退、dsh web 启动失败、配置 dsh-mobile、版本错配。
---

# DSH 升级与运维

> 与官方 DSH 升级文档的区别（防重复造轮子）：官方只讲通用升级，本 skill 记录**本机专属约定**——非标准 pnpm-global 路径、`resolveBundleDir` 导致「只升 profile 不升全局 CLI」必闪退、三个 pnpm store 打架、插件 peerDeps 锁旧版本线。环境专属踩坑清单，非官方文档的重复。

## 对外接口 / 影响面 / 可验证项

- 输入：用户说「升级 DSH」「DSH 闪退/启动失败」「配置 dsh-mobile」。
- 产出：正确升级命令序列 + 闪退根因定位 + 回滚方案。
- 影响面：只改 DSH 的全局 CLI 与 profile 两处安装，不碰业务数据/凭据。
- 可验证：`dsh --version` 与 profile `package.json` 的 `dsh-base`/`dsh-web-app` 三处版本一致；`dsh web --no-open` 能绑定端口且无 `parameter codec has no create() factory` / `agent-presets` 报错。

## 动手前强制检查（铁律一前置检查）

升级/迁移/改环境是最高优先级强制检查，四项缺一就停下补齐：

1. **检索已知坑与 issue**：同名问题往往早有人踩过——如「内测声明无法保存确认状态」早报在 deepseek-ai/deepseek-harness Discussion #860；「升级必须双处同步」是本 skill 铁律。
2. **检索官方 README/文档的正确姿势**：如 dsh-mobile 的 USAGE.md、DSH 升级说明，先读后动。
3. **备份关键配置 + 明确回滚方案**：至少备份 profile 的 `package.json` + `pnpm-lock.yaml`。
4. **确认版本兼容矩阵**：全局 CLI 与 profile 双处同步；三个 pnpm store 各指向谁；插件 peerDeps 是否锁旧版本线。

## 铁律：升级必须双处同步

DSH 有两处安装，**版本必须一致**：

| 处 | 位置 | 版本字段 |
|---|---|---|
| 全局 CLI | `C:\Users\Razer\Documents\Codex\pnpm-global`（非标准，`PNPM_HOME` 未设） | `global/v11/*/package.json` 里的 `@deepseek-ai/dsh` |
| profile | `C:\Users\Razer\.dsh\profiles\web\` | `package.json` 里的 `@deepseek-ai/dsh-base` + `@deepseek-ai/dsh-web-app` |

**只升一边 → 必闪退**。根因：启动器 `resolveBundleDir` 按 `[installAnchor, profileDir]` 顺序解析 bundle，全局安装目录优先。全局仍 0.1.5 时，会加载 0.1.5 的 `dsh-web-app`（引用已废弃的 `agent-presets` 复数），与 profile 0.1.7 的 `agent-preset`（单数）冲突 → `parameter codec has no create() factory` → 闪退。

## 正确升级姿势

1. 备份 profile：`package.json` + `pnpm-lock.yaml`（回滚用）。
2. 升 profile：
   `dsh plugin --profile web add '@deepseek-ai/dsh-base@<v>' '@deepseek-ai/dsh-web-app@<v>' <新插件@<v>>`
3. 升全局 CLI（**同版本**），并在全局项目目录内、用它自己的 store：
   `pnpm install --force --store-dir "C:\Users\Razer\Documents\Codex\pnpm-global\store" --virtual-store-dir "C:\Users\Razer\Documents\Codex\pnpm-global\store\v11\links"`
4. 验证三处版本一致 → `dsh web --no-open` 能绑端口。
5. 失败回滚：覆盖回备份的 `package.json` + `pnpm-lock.yaml` → `cd ~/.dsh/profiles/web && pnpm install`。

## 常见坑（按踩坑顺序）

1. **三 store 打架**：profile 用 `AppData\Local\pnpm\store\v11`，全局用 `Documents\Codex\pnpm-global\store`。跑 pnpm 务必 `--store-dir` 指对，否则报 `Unexpected store location` 或依赖装「残」（缺包 → Node 向上回退到旧版）。
2. **旧 hoist 残留挡路**：全局项目升级时，旧 0.1.5 的 `node_modules` 是「真实目录」非链接，`--force` 也不替换。需把整个 `node_modules` 改名移开，再干净 `pnpm install`。
3. **插件锁旧版本线**：`dsh-skill-studio` 等 peer 锁 `^0.1.5-rc.1`，升 0.1.7 会告警（`autoInstallPeers:false` 下通常只警告不硬阻断），但代码接缝（如 0.1.6 renderer-v2）只能启动后实测。**已确认翻车**：`dsh-session-ref@0.2.0`（为 0.1.2 构建、无 0.1.7 版）在 0.1.7 报 `unreachable variant in session-reference surface event` 打断本轮——0.1.7 核心已原生含 `session-reference`，该插件既冗余又坏，直接移除即可。仍重点盯 skill-studio / codex-migrate / skill-importer。
4. **闪退报错定位**：`invalid plugin ... received object` / `parameter codec has no create() factory` 往往不是单插件问题，而是「全局旧 bundle + profile 新依赖」错配。先查 `dsh --version` 是否与 profile 一致，再逐个排查缺包。
5. **设置写入全回滚（卡内测声明）**：双处都升到同版本后，若全局 CLI 与 profile 各有一份 `dsh-app-boot`（两个 pnpm store 硬链接），`bootstrapIncludes` 模块级 WeakMap 会分裂，profile 的 `dsh-config-editor` 调 `reconcileProfilePatches` 报 `dsh: profile reload requires the root Include entry` → settings.update 全回滚 → 内测声明锁死 + provider 迁不进。workaround：把 profile 的 `dsh-app-boot` 用 junction 指向全局同版本（脚本见 `redo-dsh-junction.ps1`）。上游已报 Discussion #860。
6. **子进程 Schannel TLS 报 SEC_E_NO_CREDENTIALS（0x8009030e）**：在 DSH sandbox（workspace-write 及更严）下，curl/git/PowerShell 等子进程用 Schannel 后端直连 HTTPS 会报 `AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS`——**不是系统 Schannel 坏了，也不是密码套件被清空/根证书缺失，是 sandbox 破坏了子进程的 Schannel TLS**（上游 Discussion #2850；Codex 同款 issue #17459）。判据：Node(openssl)/certifi 直连正常、只有 Schannel 栈报错，且在 sandbox 外（普通终端）跑 curl 正常。workaround 走 openssl 栈：`git -c http.sslBackend=openssl`、curl 换 openssl 后端、Codex 设 `SSL_CERT_FILE`/`CODEX_CA_CERTIFICATE` 指 certifi。**勿删 `SCHANNEL\CipherSuites\Functions`**（不存在是默认态，删了无效，是误诊）。
7. **会话日志查看器 `dsh-session-log-explorer` 在 Windows 白屏**：`serve.mjs` 的 `localFile` 用 `filename.startsWith(directory + "/")` 判断路径前缀，Windows `resolve()` 返回反斜杠 → 前缀不匹配 → 所有静态文件（`/assets/*.js`）fallback 到 `index.html` → 前端 JS 加载成 HTML → 白屏。判据：请求 `/assets/*.js` 返回 HTML（len ≈477）而非 JS。临时修复：改 `pnpm dlx` 缓存包内 `scripts/serve.mjs` 的 localFile，让 `startsWith` 同时匹配 `directory + "/"` 与 `directory + "\\"`。上游待报（检索未见 issue）。
8. **端口 3080 EADDRINUSE → host-webserver 起不来 → 13 插件 pending → plugin tree 加载失败 → 闪退**：残留 DSH 实例占着 3080（重复双击桌面图标/反复重启攒下的僵尸 node）。判据：`netstat -ano | findstr :3080` 有 PID 处于 LISTENING，启动日志报 `listen EADDRINUSE: address already in use 127.0.0.1:3080`。修复：`taskkill /F /PID <占端口PID>` → 确认 `netstat -ano | findstr :3080` 无输出 → 再起 `dsh web`。**只开一个 DSH 实例，别重复双击**；重启走 `restart-dsh.ps1`（轮询等端口释放 + 验证绑定，见 `G:\CodexDS\DSH\INTRO\restart-dsh.ps1`）。

## 会话日志排障（DSH 崩溃 / agent 无法自述时）

本地落盘位置 + 离线查看器，不依赖运行中的 DSH、不调 LLM API：

- **完整原始日志**：`~/.dsh/sessions/<工作区>/<session-id>/session.v3.jsonl.zstd`（zstd 压缩 JSONL，含 subagents/）。
- **可读投影**：`~/.dsh/storages/session_projcache/sessions/session-*.json`（`{version, record}`，含 prompt/response）。
- **崩溃日志**：`~/.dsh/logs/startup-*.log`（报错点名的插件名）。

### 保底查看器（当前可用，已验证）

**dsh-replay**（npm，MIT，zoahdev，零依赖 Node 内置 zstd）——唯一能解码 DSH **v3** 格式的离线查看器：

```sh
pnpm dlx dsh-replay --file <session.v3.jsonl.zstd> --out replay.html   # 渲染 timeline
pnpm dlx dsh-replay --file <file> --stats                              # JSON 摘要（turns/steps/toolCalls）
```

- 可视化引导页：`G:\CodexDS\DSH\INTRO\dsh-replay-web.mjs`（Node 零依赖 HTTP 服务，127.0.0.1:7781，列会话 + 点选渲染）。
- 桌面一键启动：`~/.dsh/launch-dsh-replay.cmd` + 桌面快捷方式「DSH 会话回放」。
- **只读不覆盖原日志**：输出到 `%TEMP%\dsh-replay-out\`，原 `session.v3.jsonl.zstd` 原地不动。

### 多 agent 统一查看器调研（死局，别再绕）

目标「多 agent（DSH+Codex+Claude）统一罗列对话」的现成轮子全部卡死：

| 轮子 | 障碍 |
|---|---|
| `@gengwg/agentlens`（多 agent + DSH tested） | better-sqlite3 原生编译失败（本机无 VS Build Tools + Node24 缺 prebuilt） |
| `@1agents/session-reader`（多 agent） | 只支持 DSH v2/v4，**不支持 v3** |
| `agent-log-viewer`（多 agent） | 需 Bun + 不支持 DSH |
| 官方 `@deepseek-ai/dsh-session-format-v3-to-v4`（v3→v4 迁移库） | npm 装不了（依赖 `dsh-type-meta` 404） |

结论：多 agent 统一查看器暂无可用的，**保底用 dsh-replay（仅 DSH 但支持 v3）**。要「多 agent」只能自写（dsh-replay 的 v3 解码 + 多 agent 罗列壳）或等上游。

### 坑（保底方案踩过的）

- **不覆盖原日志**：任何迁移/转化只读原日志、输出新文件（`%TEMP%`），绝不原地改 `session.v3.jsonl.zstd`。
- **.cmd 中文编码**：桌面启动 .cmd 必须纯 ASCII/英文，中文会被 cmd GBK 解析成乱码拆断命令。
- **端口占用闪退**：引导服务被占（EADDRINUSE）时，要「打开浏览器 + `process.stdin.resume()` 保持进程」，否则脚本退出导致窗口闪退。

## 已验证版本对

- DSH `0.1.5-rc.2` ↔ 各插件 0.1.5 线（旧稳定组合）。
- DSH `0.1.7-rc.2` ↔ `dsh-mobile@0.5.0` ↔ 全局 CLI `0.1.7-rc.2`（本次目标组合）。

## 多机部署场景（ABC）与三能力适配

### 三台机器部署形态

| 机 | 角色 | 铁律形态 | 事前强制 | 日志查看 |
|---|---|---|---|---|
| A（本机 DSH·Razer） | 主工作机 | AGENTS.md 常驻 | `dsh-retrieval-guard`（ask 弹窗版，`tools/pre-execute` 轮次级） | dsh-replay 保底（解码 v3）+ 引导页 + 桌面一键 |
| B（Codex 部署·LENOVO） | 部署 agent-deploy 框架 | AGENTS.md + config.toml | 待适配（Codex 有 hook：PreToolUse） | 待适配（Codex 日志格式不同） |
| C（提示词学习） | 未部署，仅提示词要求学习 | 对话里一句话 | 无 | 无 |

### 核心教训

- **铁律执行力 = 部署形态**：C（提示词学习）最易跳过铁律；B（原生部署）次之；A（常驻注入 + harness 强制检查）最强。要「保证」先检索，必须 harness 检查，不能靠提示词。
- **「医者无法自医」**：agent 崩溃/无 LLM 时无法自述，必须有无模型 API 依赖的离线日志查看器兜底。
- **检索保底**：`web_search` / `open-source-scout` 为主；不可用时 `web_fetch` 百度搜索（`www.baidu.com/s?wd=`）或人工检索兜底。文心（`wenxin.baidu.com/search`）是 AI 助手界面，web_fetch 只能拿标题、**不能自动化检索**，仅作人工保底。

### 三能力跨机落地状态

1. **事前强制（先检索检查）**：A 已实现（`dsh-retrieval-guard`，`tools/pre-execute` + `{kind:"ask"}` 弹窗 + 轮次级）；B 可适配——Codex 有 hook 机制（官方 `codex-hooks.md`、`vinctor-codex-hook`），用 PreToolUse hook 实现同款「未检索拦截」；C 无法（未部署，无 harness）。
2. **日志查看**：A 已实现（dsh-replay 保底：解码 v3 + 引导页 + 桌面一键）；B 待适配（Codex 日志格式/位置不同）；C 无本地日志。
3. **引导部署（桌面一键 + 引导导入）**：A 已实现（`launch-dsh-log-viewer.ps1` + 桌面快捷方式「DSH 日志查看器」）；B/C 待做。

## 0.1.5-rc.2 稳定态约束（本机实测，勿破坏）

- **三组件显式声明 + 锁精确版**：`@deepseek-ai/dsh-client-runtime` / `dsh-client-ui-slots` / `dsh-client-ui-primitives` 必须显式写在 profile `dependencies` 且**锁 `0.1.0-rc.6` 精确版**（不能用 `^`，会偏离到 `0.1.0-rc.8` → 与 0.1.5 核心版本错位 → `dsh web` 启动永久卡死零输出）。`autoInstallPeers:false` 下 peer 不自动装，显式声明是唯一稳定做法。
- **文件浏览器用 `dsh-file-explorer-kit`（^0.3.8）**，**不用** `@jie-rong-214/dsh-file-explorer`：后者 client 代码硬编码旧架构 `ctx.workspaces`/`ctx.sessions`（复数服务），0.1.5 只有 `ctx.workspaceRegistry`/`ctx.sessionProjections`（单数），加载失败。`dsh-file-explorer-kit` 0.3.4+ 用 `ui-slots`/`ui-workspace`（0.1.5 都有），支持任意绝对路径跳转。
- **patchReload 用 `startup`**（`live` 需要 Cordis HMR 服务，0.1.5 环境无 HMR → `watchUserPatches` 抛错崩溃）。
- **目录选择器只能从 C 盘 home 开始**：browse 后端固定从 `os.homedir()`（`C:\Users\Razer`）列目录，无法逐级浏览到别的盘（G 盘等）。去别的盘 = 弹窗右上角**铅笔图标 → 输入绝对路径（如 `G:\CodexDS\DSH\MAIN`）→ 回车跳转**（官方 issue #256 的恢复入口，图标隐蔽易漏）。native 原生对话框若在后台启动（Codex 启动）下不可见，改普通 PowerShell 前台 `cd C:\Users\Razer\Documents\Codex; dsh web` 即可。
- **换轮子优先于自行修复**：插件因架构重构不兼容时，先找「兼容当前 DSH 版本的同类轮子」替换（file-explorer → dsh-file-explorer-kit），不要 patch 旧插件的 client.js——架构重构后 API 变了，patch 服务名也救不了（`sessions.list()`/`binding` 无对应），且脆弱、下次 pnpm install 就失效。
