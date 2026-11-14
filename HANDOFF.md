# 交接文档（长对话收口）

> 本文档供「下一个对话」接手。最新状态见「一」，收口三件套见「四」。
> 本轮同步提交：**1df4b9c**（agent-deploy）。

## 一、当前状态

- **HANDOFF 已纳入版本控制（2026-11-10 22:45）**：本文件为唯一事实源，随 `agent-deploy` 仓库三目标同步（GitHub/Gitee/GitCode）；旧的 `G:\CodexDS\DSH\INTRO\HANDOFF.md` 已改为指针；`sync_framework.ps1` 与 `build_kb.py` 的 KB 源路径同步切换。

- 仓库：`G:\CodexDS\DSH\INTRO\agent-deploy`（本地有 .git；云端基线曾追平 `8cac86f`，之后为本地提交）。
- **37 个 skill 全部并入仓库**（原 25 个 + 11 个 live-only + 1 个新增），`core-skills.txt` 同步为 37 行；live `~/.dsh/skills` 与仓库 `skills/` **内容零差异**（按行尾归一化比对）。
- **常驻铁律 = 三条**（铁律一 先检索 / 铁律二 收尾反思 / 铁律三 调用框架·SKILL 前先查 framework-kb）：`agent-deploy/AGENTS.md`、`agent-deploy/dsh-config/AGENTS.md`、live `~/.dsh/AGENTS.md` **三处完全一致**。
- 三云同步：GitHub `hpsks416/agent-deploy` = Gitee `hpsks416/agent-deploy` = GitCode `qq_60289026/agent-deploy`（= `1df4b9c`）；`agent-deployed` 与 `HASHRAP` 同样三目标一致。
- 知识库：`agent-deployed` 仓库只含框架本体（铁律/画像/偏离日志/HANDOFF/skill 及其 references），**KB chunks: 774 / 源: 79**；构建产物 `framework_kb.sqlite3` **已入库**，journal 用 DELETE（非 WAL）。
- 守卫插件 3 个全注册（`dsh-retrieval-guard` + `dsh-context-guard` + `dsh-secure-push-guard`）：bundle 已在 profile `package.json`，DSH 进程已重启（Web 端口 55900 → 57594 → 62497），判定已加载；实际拦截行为可择机实测。
- **framework-kb 检索链路可用**：正确调用 = `framework-kb\.uv-python\...\python.exe` + `PYTHONPATH=framework-kb\pylibs`（误用 runtime python 会 ImportError / `unable to open database file`，不是库坏）。
- **dual-track 重构已收口（2026-11-10 22:30）**：`framework-manifest.json`（**37 skills / 7 plugins**）取代 `core-skills.txt` 与 `install.ps1` 硬编码清单；`deploy.ps1`（`-Track/-Profile/-Rollback`）与 `dsh-config/install.ps1`（`-PluginsOnly/-Profile/-DryRun`、npm 轨、按 profile 过滤）已在**假 HOME 沙箱实测**：安装 37/37 skill + 5 插件、回滚删净并恢复 profile `package.json`、失败路径 exit 2。`core-skills.txt` 降级为人类可读摘要/兜底（头注释已写明）。契约检查器 `check-plugin-contract.ps1`：web PASS5/WARN2、desktop PASS5/WARN2（WARN 均为 profile 归属）。`dsh-marktext@0.1.13`（desktop，npm 轨）与 `dsh-context-guard`（随仓分发，3.4KB）已收进；随仓 6 插件 engines.dsh/license 全覆盖。剩余子项：`-Only` 单装、npm 化发布、CI 接检查器、compatibility 真机验证。

## 二、已完成（本轮 = 2026-11-10 待办处理）

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
- **2026-11-14 第二轮（CI 实测后）**：`13cd5b1` 在 CI 上只剩 3 红——`github-ready-packager`（模型写「不实际 commit」被旧正则漏掉→放宽否定措辞）、`resume-conversation-full` 与 `skill-evaluator`（同样因「无工具 → 只吐 tool_calls」；后者还有「拒绝时引用『建议删除/保留』被 not_contains 误判」）。统一修法：任务加「不要调用任何工具，直接文字回答」+ 判据改「正向断言 / 只拦真正给出裁决的形式」。**13 个 skill 本地全绿**，等下一轮 CI 确认。

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

1. **确认 CI 结果**（下一轮 commit 触发的 run）：本地 13 个已全绿；CI 静态体检与插件契约已过，dynamic-evals 需再确认。若仍有红，按 `run_evals.py` 输出的「失败 check + 答复预览」继续放宽同义判据，**不削闸门**。
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

