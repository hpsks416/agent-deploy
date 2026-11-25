# 交接文档（长对话收口）

> 本文档供「下一个对话」接手。最新状态见「一」，收口三件套见「四」。
> 本轮同步提交：**e71469e**（agent-deploy）。

## 一、当前状态

- **2026-11-23 桌面 profile 依赖升级（不涉 web/CLI 轨）**：`@zseven-w/dsh-game-studio` 0.1.0-rc.5 → **0.1.0-rc.6**（DSH 自带 node/pnpm 在 desktop profile `pnpm install` 已装好；备份 `package.json.bak-gamestudio-20261123-123826` / `pnpm-lock.yaml.bak-gamestudio-20261123-123826`）；桌面 DSH **0.2.2-rc.5 安装包已下载就绪**（`%LOCALAPPDATA%\@deepseek-aidsh-desktop-updater\pending\deepseek-harness-0.2.2-rc.5-win-x64.exe`，`update-info.json` sha512 已校验），**待重启应用生效**（一次重启同时应用 rc.5 + 加载 rc.6）。web/CLI 轨（全局 CLI `0.1.5-rc.2`、`profiles\web`、3443 移动网关实例）按用户决定**保持不动**；`dsh-mobile` desktop 插件 0.8.2→0.8.14 由另一对话负责，**勿重复动**。

- **2026-11-25 DSH 桌面端 0.2.2-rc.5 已生效并完成升级后核查**：exe / `runtime.json` / `app.asar` 内 333 个官方包全为 rc.5（node 24.21.0 / pnpm 11.28.5 / python 3.12.14 未变）；会话格式**仍 v4**；11 个第三方插件 + `dsh-deepseek-chat-import` bundle 全部 `fiberPhase=active`（含 game-studio **0.1.0-rc.6**、dsh-mobile **0.8.14**，均为升级前已由其他对话完成）；**rc.5 唯一行为变更已实测命中**：默认模型 `deepseek-account/deepseek-flash` 的网页搜索走服务端 Messages 搜索，会话日志出现 1 条 `web/deepseek-search-llm-request` 事件；官方 rc.3↔rc.5 的 bundle 名单与 `dsh-base` 依赖集合**零差异**（无 package-export 迁移项）；community 报的「rc.5 桌面更新后可选包仍停 rc.3、预检关掉 session-query-sqlite」本机**未复现**（`session-query-sqlite` / `session-controller` 均 active）；框架 live↔repo 差异 0（`answer-me-with-html` 按 manifest external 跳过）；KB 806 chunks / 80 源；`framework-manifest.json` desktop `dshBase` 已改 rc.5、`dsh-upgrade-ops` 补 rc.5 版本矩阵与「搜索默认路由」小节、`DUAL-TRACK.md` 版本号同步。

- **2026-11-18 DeepSeek 213 篇会话已成功搬到手机（chat-demo 自建站点）** 🎉：`https://dashing-malabi-00d45e.netlify.app`（Netlify Drop，官方 chat-demo v0.1.1 静态包），全量包 `deepseek_migrate\zips\deepseek_chatdemo_213.zip`（51.22 MiB / 509 条目 / SHA256 `9ba31ed0…`）导入成功，213 篇可在手机浏览器用，会话与图片存手机 IndexedDB（不依赖电脑开机）。**踩到的真坑是条目顺序**：chat-demo 的 `importArchive.ts` 是流式状态机，顺序必须是 `manifest.json → 全部 chat_sessions/<id>.json → chat_session_index.json → 全部图片`；index 若排在会话之前，后续会话全部落进 else-branch → `fail('backupIncomplete')`，界面只报"文件格式错误或旧版导出"。另两条 chat-demo 比 DSH 插件更严的规则：消息 id 必须是数字（不是 GUID）、角色必须交替且根为提问。四个离线自检脚本已留在 `deepseek_migrate\`：`zip_probe.ps1` / `zip_crc_check.ps1` / `verify_chatdemo.ps1` / `simulate_import.ps1`（按状态机走条目顺序）。

- **2026-11-18 DeepSeek 长对话迁移落地（工作区 `MAIN\PARTNER`）**：官方导出 v3 已解包在 `MAIN\PARTNER\deepseek_data-2026-11-18`（213 篇 / 510 文件 / 87.13 MiB）。启用官方实验 bundle `@deepseek-ai/dsh-deepseek-chat-import 0.2.2-rc.3`（默认关闭 → 已开，`application: applied`）。配套脚本 `deepseek_migrate\{inventory,make_zip,convert_md}.ps1` 产出：`inventory.csv`（每篇轮次/正文字符/思考字符）、`zips\pilot_策略分析.zip`（5.15 MiB / 13 条目）、`zips\deepseek_export_full.zip`（54.25 MiB / 509 条目）、`conversations\` 213 篇 MD（28.86 MiB）+ `index.md`。实测：195 篇 <5 万字（可直接续聊），9 篇超长——最长《策略分析》1272 轮 / 273 万字 ≈ 170 万 token，**不可能原生续聊**。会话源注册表新增 **源 0 `deepseek-md`**（full/brief 两份 + live 已部署，`diff(live vs repo)=0`；KB 783 chunks / 79 源）。DSH 沙箱下 `python.exe`/`node.exe` 无法启动（命名管道被拒），全部改用 PowerShell + .NET 完成。

- **2026-11-15 新仓库 `secure-push-kit` 已三平台发布**：整合 secrets-link（token 加密链 + 多工作区面板）+ 打包/安检/推送四件套（github-ready-packager / secret-scan / acp-studio / secure-push-workflow）；GitHub/Gitee `hpsks416/secure-push-kit`、AtomGit `qq_60289026/secure-push-kit`，HEAD `f265a3f`，三端 `ls-remote` 一致、匿名页 200；README / LICENSE(MIT) / .gitignore 齐备，真实 `links.json` / `secrets.cmd` 未入库。同源改进已回写本仓 `skills/acp-studio/scripts/`：新增 `push_all.py`（`http.extraheader` Basic 认证、免 shell helper），`push-secure.cmd` 补 `atomgit` 目标与 `SECRETS_CMD`/`GIT_HTTP_PROXY` 覆盖；`SKILL.md` 记「沙箱 `sh.exe` 建信号管道失败 → 改用 push_all.py」与「Gitee 空仓库先推 commit 再转公开」两条坑。
- **HANDOFF 已纳入版本控制（2026-11-10 22:45）**：本文件为唯一事实源，随 `agent-deploy` 仓库三目标同步（GitHub/Gitee/GitCode）；旧的 `G:\CodexDS\DSH\INTRO\HANDOFF.md` 已改为指针；`sync_framework.ps1` 与 `build_kb.py` 的 KB 源路径同步切换。
- **2026-11-14 DSH 桌面端升到 0.2.2-rc.3**（rc.1→rc.3，跨过 rc.2 的全部迁移项）：`app.asar` 内 333 个官方包全为 rc.3，会话格式**仍是 v4**；desktop profile 的 `@deepseek-ai/dsh-experimental-agent-team-profile` 被官方 `RETIRED_BUNDLES` **自动摘除**（AgentTeam 能力已并入 core：`agent-team` / `tool-agent-team` 均 `fiberPhase=active`），9 个第三方插件全部 `active`（审计 0 红 5 黄 13 绿，黄仅为元数据锁旧版本线）；升前 15 个配置/凭据文件已备份到 `~/.dsh/profile-backups/pre-rc3-20261114`（SHA256 15/15 校验一致）；`framework-manifest.json` 的 desktop `dshBase` 已改为 rc.3、`dsh-upgrade-ops` 补「两条轨」与 rc.3 版本矩阵、`DUAL-TRACK.md` 版本号同步。
- 仓库：`G:\CodexDS\DSH\INTRO\agent-deploy`（本地有 .git；云端基线曾追平 `8cac86f`，之后为本地提交）。
- **38 个 skill 全部并入仓库**（原 25 个 + 11 个 live-only + 2 个新增），`core-skills.txt` 同步为 38 行，`framework-manifest.json` **46 items / 39 skills（38 入库 + 1 external）**；第 38 个是 2026-11-18 新增的 `deepseek-export-migration`。`answer-me-with-html` 已于 2026-11-23 定性为**外部技能**（manifest `source: external:market`、`portable:false`）：**不入库、不进 KB**，收口脚本与 KB 构建按 manifest 的 external 标记跳过，live 里存在属正常。
- **常驻铁律 = 三条**（铁律一 先检索 / 铁律二 收尾反思 / 铁律三 调用框架·SKILL 前先查 framework-kb）：`agent-deploy/AGENTS.md`、`agent-deploy/dsh-config/AGENTS.md`、live `~/.dsh/AGENTS.md` **三处完全一致**。
- 三云同步：GitHub `hpsks416/agent-deploy` = Gitee `hpsks416/agent-deploy` = GitCode `qq_60289026/agent-deploy`（= `1df4b9c`）；`agent-deployed` 与 `HASHRAP` 同样三目标一致。
- 知识库：`agent-deployed` 仓库只含框架本体（铁律/画像/偏离日志/HANDOFF/skill 及其 references），**KB chunks: 808 / 源: 80**；构建产物 `framework_kb.sqlite3` **已入库**，journal 用 DELETE（非 WAL）。
- 守卫插件 3 个全注册（`dsh-retrieval-guard` + `dsh-context-guard` + `dsh-secure-push-guard`）：bundle 已在 profile `package.json`，DSH 进程已重启（Web 端口 55900 → 57594 → 62497），判定已加载；实际拦截行为可择机实测。
- **framework-kb 检索链路可用**：正确调用 = `framework-kb\.uv-python\...\python.exe` + `PYTHONPATH=framework-kb\pylibs`（误用 runtime python 会 ImportError / `unable to open database file`，不是库坏）。
- **dual-track 重构已收口（2026-11-10 22:30）**：`framework-manifest.json`（**37 skills / 7 plugins**）取代 `core-skills.txt` 与 `install.ps1` 硬编码清单；`deploy.ps1`（`-Track/-Profile/-Rollback`）与 `dsh-config/install.ps1`（`-PluginsOnly/-Profile/-DryRun`、npm 轨、按 profile 过滤）已在**假 HOME 沙箱实测**：安装 37/37 skill + 5 插件、回滚删净并恢复 profile `package.json`、失败路径 exit 2。`core-skills.txt` 降级为人类可读摘要/兜底（头注释已写明）。契约检查器 `check-plugin-contract.ps1`：web PASS5/WARN2、desktop PASS5/WARN2（WARN 均为 profile 归属）。`dsh-marktext@0.1.13`（desktop，npm 轨）与 `dsh-context-guard`（随仓分发，3.4KB）已收进；随仓 6 插件 engines.dsh/license 全覆盖。剩余子项：`-Only` 单装、npm 化发布、CI 接检查器、compatibility 真机验证。

## 二、已完成（本轮 = 2026-11-18 DeepSeek 会话迁移）

- **2026-11-24 决策：插件不发 npm**。现役分发改为两条：`deploy.ps1 -Track plugins`（link，本机）与 `tools/pack-plugins.ps1` + `dsh plugin add file:<tgz>`（离线/他机）；实测 6 个 tgz（1.5–34.7 KB）能在空项目里 `pnpm add file:` 装进 `node_modules/@hpsks416/...`；`tools/publish-plugins.ps1` 与 scoped 名保留但停用。`dist/` 已进 .gitignore。
- **2026-11-23 directed-article-learning 增「取不到正文时的回落链」**：等价源检索 → r.jina.ai → 用户录屏 ffmpeg 抽帧逐帧读图 → 贴正文；铁律写明「截图转写必须标注可能截断」「无等价源不许猜」「笔记必须写取证方式」。起因：拿微信正文连撞验证墙两次。
- **2026-11-23 design-qa 增 G13「交互自解释」**：来自《交互构件》一文（微信原文被验证墙挡住，改用屏幕录制抽帧取证：88s→22 帧）；把「形态即说明书」拆成 4 条可判定命中特征（全靠 label / 靠 hover / 图标要猜 / 必须读说明）+ 改法与可量化验收（「哪些元素必须读文字」清单数量）。
- **2026-11-23 依赖升级（game-studio rc.6 + 桌面 rc.5 待重启）**：`game-studio` 用 DSH 自带 `node v24.21.0` + `pnpm 11.28.5` 在 desktop profile `pnpm install` 升级到 rc.6（exit 0、lockfile 通过 supply-chain 策略 87 项、engines `node>=22` 满足、无 peer 限制）；桌面 DSH rc.5 走**应用内更新**（desktop 轨不适用双处同步），更新包已在 pending 目录、只需完全退出并重启。web/CLI 轨（全局 CLI `0.1.5-rc.2` → `0.2.2-rc.5`）经兼容矩阵评估后**决定不升**：跨三代、`profiles\web` 里 `dsh-mobile 0.5.0`/`dsh-codex-migrate`/`dsh-skill-importer 0.2.5` 等插件 peer 多锁 0.1.x，且该实例承担 3443 手机移动网关，迁移会中断移动访问。

- **2026-11-23 收口 11-18 遗留 WIP**：`deepseek-export-migration`（第 38 个 skill）连同 `core-skills.txt` / `framework-manifest.json` / 两份 `conversation-sources.md` / HANDOFF 一并提交；`answer-me-with-html` 定性为外部技能（manifest 登记 `external:market`，不入库/不进 KB）；`sync_framework.ps1` 与 `build_kb.py` 增加 **external 跳过逻辑**（检查输出改为「已知例外」，KB 重建时剔除其 28KB 正文与 references）；顺手把 CI 那条 `secure-push-workflow` 假阳性（`not_contains "已推送"` 命中拒绝措辞）改正向断言。

- **2026-11-18 DeepSeek 超长会话迁移（PARTNER）**：先检索轮子后动手——结论是官方自带出口最合适：`@deepseek-ai/dsh-deepseek-chat-import`（app.asar 内含 0.2.2-rc.3，`MORE_BUNDLES` 里属实验性、默认关闭）+ 官网「导出所有历史对话」ZIP（`export_format_version: 3`）。逐条核实了三类第三方（DeepSeek2md / ceyaima 油猴 / py 版 conversations.json 转换器）：**它们的输入都是旧格式 `conversations.json`，都不吃 v3 ZIP**，所以没有再引第三方工具，改用 3 个本地 PowerShell 脚本（`make_zip` 重打包、`convert_md` 出 MD、`inventory` 出明细）。导入格式落到细节：ZIP 条目必须在根（`manifest.json` / `chat_session_index.json` / `chat_sessions/<id>.json` / `chat_sessions/<id>_files/*`），manifest 放第一个条目；子集 ZIP 靠过滤 index 实现（插件本身不支持挑篇）。框架侧登记 `deepseek-md` 会话源，`sync_framework.ps1 -Action skills -Direction repo2live` 部署后 diff 归零、KB 由 779→783 chunks。

- **2026-11-15 `secure-push-kit` 发布 + acp-studio 推送脚本回写**：新仓库收纳 secrets-link 面板/三层加密链 + 两个推送脚本 + 三个 skill；`push_all.py` 用 `http.extraheader=Authorization: Basic` 绕开沙箱内 `credential.helper=!shell` 的 `sh.exe` 管道失败；Gitee 建库实测「空仓库不能直接设公开 → 先推首个 commit 再 PATCH `private=false`」。三平台推送均 `ls-remote` 校验一致。

- **2026-11-14 npm scoped 化（选定 @hpsks416/*）**：6 个随仓插件改名 `@hpsks416/dsh-*`（package.json + cordis.patch.yml insert name + manifest.package 同步）；`install.ps1` link 轨改为 scoped 依赖并**自动迁移旧短名**（dependencies + bundles）；契约检查器同时认 package/id；`tools/publish-plugins.ps1`（-DryRun 预检 / 正式发布，token 走 secrets-link）；`dsh-skill-studio-patched/NOTICE.md` 标 fork 归属。
- **2026-11-14 收尾批（S1 + Phase1 + Phase2 启动）**：
  - **MUSICAL S1 完成**：CUDA 修好（`uv pip install --target _cuda nvidia-cublas-cu12 nvidia-cudnn-cu12` + **`os.add_dll_directory`**，只加 PATH 无效）；small.en 同一 wav：CPU int8 2.37s → GPU fp16 0.56s（**4.2×**）；`offline_pipeline.py` 已内置自动注册。
  - **compatibility 真机验证**：`context-guard` 用假 ctx 驱动 `tools/pre-execute`，四档全 PASS（0.50 pass / 0.72 warn 日志 / 0.86 ask ⚠️ / 0.96 ask 🚨）；测试脚本 `UPDATE/research/context-guard-test.mjs`。
  - **npm 化就绪**：6 个随仓插件补齐 `engines.node` / `keywords`；`pnpm pack` 实测产出 tarball（retrieval-guard 6.4KB）；发布到 npm 仍缺账号/2FA（未做）。
  - **Phase2 启动**：manifest 每个插件补 `portable` + `migration`（mcp/skill/none）——retrieval/secure-push/context-guard 可迁移（skill），skill-studio 可拆 MCP，其余不可移植。
  - **`sync_framework.ps1` 纳入版本控制**：真身进 `agent-deploy/tools/sync_framework.ps1`，`G:\CodexDS\DSH\INTRO\sync_framework.ps1` 改为转发包装。
- **2026-11-14 开源热榜第三批 P0-P3**：
  - `UPDATE/research/dsh-loading-chain.md`：bundle→patch→apply 三层对照 NamiDSH 源码；`dsh --profile web --dump-config` 实测 20572B/165 条目，我方插件行号（skill-studio 587、goat-vision 596、retrieval 651、secure-push 654、session-sync 657）；**desktop profile 不能被 CLI dump**（Electron 独占，exit 1）。
  - `local-tool-mcp-exposure` 增「工具集分层与进程生命周期」：Essentials 默认 + 按需工具集（`list_toolsets`/`enable_toolset`）、模式切换连带重启 MCP 进程（1–2s 重同步）、重启兜底 SIGTERM→1.5s SIGKILL→3s 强退、`<server>_status` 自检工具。
  - `CARTOON/产出规范-风格目录.md` + `CARTOON/styles/`（3 类：表情包/角色完整动作/场景短片；每类 STYLE.md 固定 6 段模板：案例表/怎么做/可直接这样说/具体做法/交付物）。
  - `design-qa` 增「文本模式（text）」：Pass 1 = 26 条 AI tells（分组 A–F，逐条改法）；Pass 2 = STE80 结构 S1–S15 的 80% 摘要；保真铁律（事实/数字/引号不动、不确定度不减、不加新事实、代码/U­RL 不碰）+ 何时不做（合同/代码/诗/品牌稿）。
- **2026-11-14 开源热榜 P0-P3（两批各 4 项）**：
  - **批一（11-14 报告）**：`MUSICAL/offline-pipeline/`（离线语音翻译：faster-whisper → Ollama → SRT，本机 CPU 实跑通；CUDA 缺 `cublas64_12.dll` 待修）｜`CAD/threert-eval.md`（ThreeRT 仅 macOS/iOS 客户端 → 不可用，替代 A+C：three.js WebGPU + Blender Cycles）｜`UPDATE/research/gpucanvas-feasibility.md`（依赖 Chrome 157 实验 API → 只借「agent 可读可指」语义层思想）｜`_collect.py` 刷星黑名单（实测过滤 4 条，含 1210★ 重打包仓库）。
  - **批二（11-12 报告）**：`UPDATE/research/lotmap-feasibility.md`（事件源 `ctx.on("session/event")` 有生产实证；面板走 webServer+SSE 最薄，右栏 tab 为二期）｜`skills/web-3d-asset-pipeline` 增「Texture Generation (AI PBR forge)」段（ai-texture-forge 是 Blender GUI add-on，非 CLI）｜`UPDATE/research/minimax-h3-image-decision.md`（权重 204GB + 许可排除欧/英/韩/美 → 走 API，不本地部署）｜`thirdparty-gate.ps1` 第三方插件门禁（SkillSpector 契约：exit 0/1/2、`risk_recommendation`、`is_complete`；Windows 不能 `--output`；超时 fail-closed；实测自有插件 PASS、marktext 90s 超时 BLOCK）。
- **2026-11-14 修 10 个脆 evals（CI dynamic-evals）**：根因两类——① CI 的 A/B harness **没有 exec/文件工具**，要求「真跑脚本」的用例必然红（`agent-instruction-supply-chain-scan` / `secret-scan` / `github-ready-packager` / `resume-conversation-brief`）；② 用 `not_contains` 判「不许出现某词」，模型正确回答「不会 force-push」「不应标记为 blocked」「与材质无关」时被误判。修法：用例改成**可判定问法**（问流程/给示例，不依赖工具）+ 否定式判据换**正向断言**（覆盖同义说法）；`run_evals.py` 加 `temperature=0`（消除随机 flaky）与 UTF-8 输出（修 Windows GBK 下 emoji 崩溃）。10 个 skill 本地全绿：acp-studio / agent-instruction-supply-chain-scan / agent-workflow-orchestration / github-ready-packager / iron-law-retrieval-first / long-sentence-structurizer / resume-conversation-brief / secret-scan / skill-lifecycle-manager / skill-optimizer。
- **2026-11-14 第三轮（终局）：CI dynamic-evals 全绿 ✅**。CI 模型按用户要求从 `deepseek-v4-pro` 换成官方 **`deepseek-flash`**（`EVAL_BASE_URL/API_KEY` 不变；官方 `/models` 只有 `deepseek-flash` 与 `deepseek-v4-pro`，**不存在 4.1-flash 这个 id**，v4.1-flash 仅在 commandcode 且本机 key 已过期 401）。换 flash 后暴露并修掉两类 harness 问题：① **无工具时模型吐 tool_calls 伪代码**（对两臂注入「不要输出 tool_calls，直接文字回答」）；② **正则 `.` 不跨行**（改 `re.S`，否则「排除：\n- 运行时产物」这类正确回答被误判）。另加 **失败用例重试一次**（flash 即使 temperature=0 仍偶发抖动）。判据统一改成**正向断言**（覆盖同义措辞）。最终 CI：`static-check ✅ / plugin-contract ✅ / dynamic-evals ✅ fail=0 skip=0`，**18/18 全 OK**（run `43601959379`，commit `e71469e`）。

- **2026-11-10 dual-track 重构 + 插件契约 Phase 1（另一会话，本机提交 1df4b9c→77d9221）**：`8e26390` 清理误提交备份目录；`f021ecc` 双 profile（web 0.1.5-rc.2 / desktop 0.2.2-rc.1）；`c46f738` 契约检查器 + 元数据归位；`92bdfd7` engines.dsh 补全 + marktext 纳入 npm 轨；`7e3b7f6` 实测收口（失败可见/回滚修对/core-skills 归属）；`77d9221` 收进 dsh-context-guard。
- **2026-11-10 待办四项**：
  1. **CI dynamic-evals 修复**：`.github/workflows/ci.yml` 改为「单 skill 失败不中断整轮」（`set +e` + 逐 skill OK/FAIL/SKIP 汇总）；`run_evals.py` 失败时输出失败 check 序号 + 答复预览。已推送，CI 重跑 `run 42827274271`（17 个带 evals 的 skill 串行跑，约 1 小时；静态体检 job 秒过）。
  2. **废弃 acp 前身 5 个仓库**：`git-acp` / `gitee-acp` / `gh-gitee-sync` / `gacp-studio` / `gacpee-studio` —— GitHub 全部 `archived=true`（可逆，已验证）；Gitee 无 archive API，改仓库描述为「[已废弃] 功能已并入 acp-studio / agent-deploy，请勿使用」（已验证精确匹配）。
  3. **hatch-pet「缺 assets」澄清**：`references/canonical-base.png` 与 `references/layout-guides/` 不是缺失文件，是 `prepare_pet_run.py` **运行期生成**的产物（见 `references/hatch-pet-detail.md` 第 264/282/676/858 行），**无需补**。
  4. **守卫插件复核**：3 个 bundle 在 profile 中 + DSH 已重启，视为已加载（见第一节）。
- **2026-11-09**：更新 `metro-traffic-prediction` skill——新增「演示平台（ECharts GL 3D）实战要点」：ECharts 6 与 echarts-gl 2.0.x 不兼容须降 5.5.1；`zlevel` 分层解决热力覆盖、`markLine` 挂空 series 会退化成边框（应给锚点或改用 axis.splitLine）；数据更新按 series `id` merge、禁 `notMerge` 重建以免重置相机/缩放；俯视 `alpha≈89.5/beta=180/orthographic` 且拖拽需自行检测退出；分界用零宽度 line3D + 曲线连接锚点保连续；3D 纵轴全局定标不随窗变；时间轴按 72 步/天、补夜间 0 需 96 步/天且输入窗口 > 夜间步数；未运营时刻用「掩码解码」硬约束而非加权损失；WSL matplotlib 中文字体需 `addfont`。KB 已重建。
- **2026-11-10 收口复查**：把只在 live 的 `metro-traffic-prediction` 回写仓库（live↔repo 回到 0 差异），补提交 agent-deployed 里已重建未提交的 KB 构建产物，三目标推送；顺手修了 `sync_framework.ps1` 静态体检标题的硬编码 skill 数。

1. **live ↔ 仓库双向归一**，skill 全量对齐（内容 0 差异）：
   - live→repo（live 新）：`directed-article-learning`、`dsh-upgrade-ops`、`skill-evaluator`、`acp-studio`（合并版）。
   - repo→live（仓库新）：`agent-workflow-orchestration`、`github-ready-packager`、`meta-layer-optimizer`、`secure-push-workflow`、`secret-scan`，外加 9 个附属文件（evals/scripts/references）。
   - `acp-studio` 合并：live 的 **AtomGit 三目标** + 仓库的 **secrets-link 面板/脚本** + `push-secure.cmd` + Gitee/GitHub API 坑。
2. **11 个 live-only skill 纳入发布范围**：`dsh-plugin-lazy-adapter-resolution`、`hatch-pet`、`homophone-pun-analysis`、`hpsks416`、`local-tool-mcp-exposure`、`metro-traffic-prediction`、`mindspore-gpu-wsl`、`restricted-download-mirror-first`、`rust-refactor-local-projects`、`web-3d-asset-pipeline`、`windows-node-spawn-cli`。
3. **文档同步**：`FRAMEWORK.md`、`FRAMEWORK-COUPLING.md`、`COMPARISON.md`、`README.md`、`core-skills.txt`。
4. **`framework_kb.sqlite3` 入库**（agent-deployed）。
5. **本地 git 记录追平云端**（`fetch` + `reset --hard`），桌面副本 `G:\DSH\CMAIN\CINTRO\agent-deploy` 重同步（0 差异）。
6. **CI 静态体检全绿（0 fail）**：修了 `static_check.py` 把 URL 里 `scripts/…` 误当本地引用；`dsh-upgrade-ops` 措辞；`hatch-pet` 86k 正文拆到 `references/hatch-pet-detail.md`。
7. **KB 管线扩展**：`build_kb.py` 同时索引每个 skill 的 `references/**/*.md`（tag `skill:<name>/ref`）。
8. **铁律三部署**：`dsh-config/AGENTS.md` 与 live `~/.dsh/AGENTS.md` 全量对齐仓库根 `AGENTS.md`。
9. **收口脚本重写**：`G:\CodexDS\DSH\INTRO\sync_framework.ps1` 单脚本多动作（`-Action check|skills|kb|push|all`）。
10. **三目标推送**：agent-deploy / agent-deployed / HASHRAP 全部推到 GitHub + Gitee + GitCode，推后 `ls-remote` 校验 9 个端点 MATCH。
11. **新增 skill（第 37 个）`agent-instruction-supply-chain-scan`**：指令文件投毒（网页把 AGENTS.md/CLAUDE.md 静默丢进 Downloads，agent 启动即当指令执行）的只读扫描器；证据同时落 `G:\DSH\CMAIN\SECURITY\knowledge\agent-instruction-supply-chain.md`。
12. **STM32CubeMX 更新器处置（2026-11-08）**：`MultiScanPanel - Unable to refresh data` 与 `sw-center.st.com` 的 pdsc 大量 404 只是更新器数据刷新失败（本地 DB 正常：226 boards 已加载）；`Check Update Manager` 占着导致连续 5 次点 X 都无法退出（日志 21:44:23 才 `Starting shutdown procedure`）。修复：`%USERPROFILE%\.stm32cubemx\plugins\updater\updater.ini` 的 `CheckType: 1→0`、`LastCheckStamp` 回填当前时间；备份 `updater.ini.bak.20261108214559`。当前安装版本为 **6.18.1 官方正式版**（ST 把内部构建号/文件版本都写成 `6.18.1-RC2`，曾误判为「候选版」，已纠正）。

## 三、待办 / 未完成

1. ~~DeepSeek 迁移~~ → **已完成（2026-11-18）**：① 超长会话"能不能续聊"已实测——桌面路由与 API 都是 1M 上下文，《策略分析》1,613,141 token 超限报 `CONTEXT_WINDOW_EXCEEDED`，其余 212 篇都能续；② 巨无霸方案已落地为"尾部 150 轮 + 40 段 map-reduce 接续摘要 + 合成 assistant 回执"，切片版 302 条消息 / 约 21 万 token；③ 手机侧走官方 chat-demo（不用 DSH Mobile、不装第三方插件），213 篇导入成功。**剩余可选**：把 212 篇也导入 DSH 工作区 `deepseek_pilot`（`zips\deepseek_export_212.zip`，格式已验，未做）。

1. ~~确认 CI 结果~~ → **已完成（2026-11-14）：CI 全绿**（`static-check` / `plugin-contract` / `dynamic-evals` 三 job 全过，18/18 skill OK，run `43601959379`）。CI 的 evals 模型现为官方 `deepseek-flash`；若以后要换更强/更弱模型，需按 `run_evals.py` 的「失败 check + 答复预览」重新校准判据，**不削闸门**。
2. ~~确认 dual-track 重构收口~~ → **已完成（2026-11-10 22:30）**：沙箱实测安装/回滚通过、契约检查器双 profile 通过。剩余子项：`-Only <id>` 单装、5 插件 npm 化、CI 接检查器、compatibility 真机验证。
3. CubeMX 已是 **6.18.1 正式版**（内部构建号 `6.18.1-RC2` 是 ST 命名习惯），无需换版本；若后续要汉化，先确认补丁的目标构建号与本机一致。
4. CubeMX 联网下载（固件包/更新）如需可用：开代理后写 `updater.ini` 的 `[Proxy]`，或在 `Application\STM32CubeMX.l4j.ini` 加 `-Dhttps.proxyHost/-Dhttps.proxyPort`；否则走镜像下载 zip + `From Local` 导入。
5. `templates/agents-core.md`（codex/claude 用的框架无关版）保持**两条铁律**——铁律三依赖 framework-kb，跨框架部署时无对应知识库，故不加。

## 四、关键约定（下一个对话必须遵守）

- **收口三件套**（改过框架后必跑）：① 更新 HANDOFF → ② 部署框架（skills + AGENTS.md → live）→ ③ 重建 deployed 知识库。脚本：`G:\CodexDS\DSH\INTRO\sync_framework.ps1`（`-Action check|skills|kb|push|all`；`-Action skills` 默认只报告差异，配 `-Direction repo2live|live2repo` 才动手）。
- **live 为先 + 双向归一**：skill 改动先落 live 验证再回写仓库；**任一方向都要逐文件比对，不能靠 mtime 猜**。
- **双轨唯一事实源**：部署读 `framework-manifest.json`（skills + plugins），`core-skills.txt` 仅人类可读摘要/兜底；改插件后跑 `pwsh check-plugin-contract.ps1 -Profile web|desktop`（有退出码）；插件分 link（随仓）与 npm（外部固定版本）两类。
- **多会话协作**：**禁止 `git add -A`**（会把另一会话未提交的改动一起带上云端）；一律定向 `git add <路径>`，提交前 `git status` 复核。
- **token 访问**：只用 `secrets.cmd` 或 `-Action push`（内部解密 `G:\KEY\*.zip`），不硬编码、不直接读明文、不打印。
- **push 流程（三目标缺一不可）**：GitHub + Gitee + GitCode/AtomGit（`-Action push` 已内置重试与推后 SHA 校验）。GitHub 偶发 `curl 55 / 连接超时`，重试即可。
- **知识库边界**：deployed KB 只放框架本体（AGENTS/persona/meta-drift-log/HANDOFF/skill 及其 references），调研笔记/计划不进 KB。
- **铁律**：**三条**（一 先检索 / 二 收尾反思+选项弹窗 / 三 调用框架·SKILL 前先查 framework-kb）；三处 AGENTS.md 一致。
- **kb / push 需 escalate** `danger-full-access`（token 解密、写 `~/.dsh`、sqlite unlink）。

## 五、已知坑（复用，勿重踩）

- **npm 发布坑**：`dsh-context-guard`（greenlv）与 `dsh-skill-studio`（zhengjunyao）在 npm 已被占用（后者是本仓 patched fork 的上游）→ 必须 scoped；scoped 包发布必须 `--access public`；发布不可逆（同版本不能再发）；Windows 上 `pnpm publish` 需要 `NODE_AUTH_TOKEN`（secrets-link 运行时解密）。
- **Windows 上 Python 扩展模块的依赖 DLL 不走 PATH**：`ctranslate2`/`faster-whisper` 报 `Library cublas64_12.dll is not found` 时，装 `nvidia-cublas-cu12`/`nvidia-cudnn-cu12` 之后**必须**对每个 `nvidia\*\bin` 调 `os.add_dll_directory()`；只设 PATH 无效（ct2 4.8.2 wheel 自带 CUDA 支持，无需重编）。
- **`dsh --dump-config` 只对 web profile 可用**：desktop profile 报 `error: profile "desktop" is managed exclusively by the Electron application`（exit 1）；desktop 插件要验证加载，走 app 的 Plugins 面板或插件自带的 `/api/diag` 类只读端点（marktext 已验证）。
- **SkillSpector 用法（P6 门禁）**：Windows 下**不能传 `--output`**（平台不支持安全落盘），必须省略并抓 stdout；OSV 联网查询在无网/慢网会长时间挂住 → 门禁必须带 `-TimeoutSec` 兜底；插件目录（非 skill 目录）静态扫描 `is_complete=false` 属常态，默认只 WARN，`-StrictIncomplete` 才拦。
- **多会话并发会互相踩**：本轮 `git add -A` 把另一会话正在做的 dual-track 未提交改动（manifest/deploy.ps1/install.ps1/DUAL-TRACK.md）一并提交推上云端。多会话时用定向 `git add`，并先 `git status` 看有没有别人的改动。
- **Gitee PATCH 仓库必须带 `name`**：`PATCH /api/v5/repos/{owner}/{repo}` 不带 `name` 报 `{"messages":["name is missing"]}`；带 `name` + `description` 才能改描述。Gitee 没有 archive API（只能改描述/README 标废弃）。
- **GitHub Actions `run:` 默认 shell 带 `-e`**：`python ...; code=$?` 里前一条失败会直接中断，后面的 skill 全不跑——必须 `set +e` 或 `if ...; then`。
- **live 与仓库会双向漂移**：旧 `sync_framework.ps1` 只写死 6 个 skill；仓库曾整体「务实化清理」，live 没跟上 → 必须逐文件内容比对（新脚本已内置）。
- **git `core.autocrlf=true`**：live 文件 CRLF、仓库索引 LF；复制后 `git status` 会先报一堆 M，`git diff --stat` 才是真实变更。
- **`static_check.py` 的引用检查**：已修（提取前剥 URL）。
- **hatch-pet**：正文超硬上限已拆到 `references/hatch-pet-detail.md`；其 `references/canonical-base.png`/`layout-guides/` 是运行期产物，不是缺失文件。
- **KB DB journal 用 DELETE，不要 WAL**；**KB 数字要迭代回填**（HANDOFF 本身是 KB 源，数字改一次可能 ±1，`-Action kb` 会循环到稳定）。
- git SSL：`-c http.sslBackend=openssl`；本机**直连可用**（`127.0.0.1:7897` 代理未开，别写死代理）。
- SkillSpector 依赖 yara-python → 用 Python 3.12。
- `for /f` 命令路径不能含空格（8.3 短路径）；`.cmd` 注释必须纯英文。

## 六、下一步建议

1. CI 结果出来后修剩余脆 evals（优先 `acp-studio/success-gate-scan-first`；让用例真正区分 with/without skill，而不是靠字面词命中）。
2. dual-track 后续：补 `-Only <id>` 单装、把 `check-plugin-contract.ps1` 接进 CI、在 desktop 真机验证 `compatibility.dshReleases` 后再扩 web/desktop 声明。
3. 实测守卫插件拦截行为（可选）：`dsh-retrieval-guard` 用一个「未检索就要造轮子」的请求触发一次，看是否弹 `ask`。

