# 框架及各 SKILL 与其他轮子的区别（逐级对比 · 逐个对比）

> 铁律一「优先检索现成轮子」的完整答卷。分两级：**框架级**（整套框架 vs 其他 agent 框架 / 反思路径）→ **skill 级**（36 个 skill 逐个 vs 对应轮子）。

---

# 第一部分：框架级对比

## 1. 整套框架 vs 其他 agent 框架（CLI 工作台 / 编排框架）

| 维度 | 本框架（agent-deploy 这套） | Codex / Claude Code | LangGraph / AutoGen / CrewAI |
|------|---------------------------|--------------------|------------------------------|
| 定位 | 个人「自我改进」agent 环境 | 通用 coding agent 工作台 | 通用多智能体编排 SDK |
| 自我反思 | **外置**（skill-evaluator/optimizer 闭环） | 无（靠模型自身） | 无（编排不评估自身） |
| 用户画像 | **persona.md 六维** + 收尾积累 | CLAUDE.md 记忆（仅 Claude） | 无 |
| 自我优化 | **有**（rollout→reflect→edit→gate 防假改进） | 无 | 无 |
| 跨框架 | **有**（agent-deploy 一键铺） | 各自绑定 | SDK 框架无关但重 |
| 安全检查 | **有**（secret-scan 强制检查） | 无 | 无 |
| 可审计 | **高**（文件集合，人可读/diff/git） | 中 | 低（黑盒代码） |
| 依赖重量 | 轻（纯文件 + 脚本） | 中 | 重（SDK/服务） |

**一句话**：其他框架是「写代码的 agent」，本框架多了「自我评估、自我优化、记住用户偏好、可跨框架迁移」这几个 skill 和规则文件。

## 2. 反思路径：外置 vs 内化

| 维度 | 本框架（外置·文件集合） | 内化路径（架构/微调/RL） | SOFAI-LM（免训练控制器） |
|------|------------------------|------------------------|------------------------|
| 反思位置 | 工作区文件/脚本 | 模型权重/架构 | 外部代码控制器 |
| 可审计性 | **高**（可 diff/git） | 低（黑盒） | 中 |
| 可移植性 | **高**（Agent Skills（AAIF）规范 + agent-deploy） | 低（绑模型） | 中 |
| 成本 | 低（token 即成本） | 高（推理税/训练） | 中 |
| 防「假反思」 | **有**（gate + 防表面反思铁律） | 弱（微调易「礼貌性免责声明」） | 有（预算回退） |
| 原生性 | 低 | **高**（模型自己会） | 中 |

**一句话**：内化路径把反思写进模型权重（黑盒、贵），本框架写成文件——互补而非竞争。

---

# 第二部分：skill 级逐个对比（36 个）

判断三分类：**复用**（直接用轮子）· **借鉴**（吸收思想 + 自写）· **自写**（本机契约，无轮子覆盖）。

## A. skill 生命周期链（3 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `skill-evaluator` | promptfoo、LangSmith eval、skill-ab-eval | 轮子评估「代码/提示词」，本机评估「skill 是否有 lift」，且**全过程判定**（中间消息+最终答复）独有 | 借鉴 |
| `skill-optimizer` | **微软 SkillOpt**、DSPy | 思想同源（rollout→reflect→edit→gate），本机是轻量版 + 补了「防表面反思」铁律 | 借鉴（直接对标） |
| `skill-lifecycle-manager` | AutoSkill、skill-evolution | 轮子管「生成 skill」，本机管「自我反思触发 + 分层 + 脚本化迁移」全生命周期 | 借鉴 + 自写 |

## B. 编排 + 检索（3 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `agent-workflow-orchestration` | LangGraph、A2A 协议 | 轮子是「编排框架/协议」，本机是「agent 编排自身」的方法论 + DSH 工具落地，A2A 的 Agent Card/不透明性已吸收 | 借鉴 |
| `open-source-scout` | OSSInsight、libraries.io、fossick-mcp | 轮子各覆盖「搜索/指标」一环，本机做「找→核实→评估→结论」闭环 | 借鉴（轮子作信号源） |
| `iron-law-retrieval-first` | Anthropic「先搜后写」提示、Aider repo-map 前置 | 轮子只是提示建议；本机把「先检索」做成可评估载体（evals/gate）+ 与 `dsh-retrieval-guard` 插件联动 | 借鉴 + 自写 |

## C. 安全 + 发布（6 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `secret-scan` | **gitleaks**、trufflehog、detect-secrets | gitleaks 最吻合（--redact 脱敏），但本机=零依赖 stdlib + Gitee 规则 + 本机凭据 | 借鉴（gitleaks 规则） |
| `secure-push-workflow` | CI/CD secret gate、agent-skills-workflows | 轮子是「CI 里的门禁」，本机是「本地打包→安检→推送」强制检查编排 | 自写（本机契约） |
| `github-ready-packager` | git archive、scaf/docwiz | 轮子各做「排除/补文件」一环，本机做「整理+安检+打包」三步编排 | 自写（复用 git 原语） |
| `acp-studio` | gh CLI、git GUI、gitsync | 无单一轮子覆盖「GitHub+Gitee+AtomGit 三目标 + ff-only + 安检门禁」，本机=薄编排层复用 git 原语 | 自写 |
| `security-audit` | **Cloudflare security-audit-skill**、semgrep、CodeQL | 静态分析器找代码模式；本机是「6 阶段 + 覆盖账本 + 隔离猎手 + 对抗验证 + 独立复核」的审计流程，只报可判定漏洞 | 借鉴（Cloudflare 骨架） |
| `skill-supply-chain-scan` | **NVIDIA SkillSpector**（71 模式/17 类）、OWASP LLM Top 10 | 直接复用 SkillSpector 当扫描器，本机只加「命中即拒绝安装」的闸门与 exit code 断言 | 复用 |

## D. 对话继承（3 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `resume-conversation-full` | claude-handoff、Context Shift | 轮子做「会话→上下文交接」，本机做「可插拔会话源（codex-md/dsh-native）+ 全文直读」 | 借鉴（分块思路） |
| `resume-conversation-brief` | 同上 | 本机做「map-reduce 精炼 + 每结论引用来源」快照 | 借鉴 |
| `migrate-conversation-prompt` | Claude Context Shift、infinite-context-mcp | 轮子覆盖「会话→可移植上下文」一半；读 DSH conversations/*.md + 完整性校验是 DSH 私有 | 借鉴 + 自写 |

## E. 决策 + 画像 + 元层（4 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `agents-md-skill-layering` | Anthropic Agent Skills、CircleCI《AGENTS.md vs skills》 | 分层规则已现成（小且恒真→AGENTS.md，大且情境化→skill），本机落地成决策 skill | 借鉴 |
| `long-sentence-structurizer` | RePrompter、flompt | 轮子重（带评分+section 化），本机=轻量四段模板，吸收了 section 拆分 | 借鉴 |
| `persona-manager` | Mem0、cicada（金蝉脱壳） | Mem0=向量记忆重依赖；cicada=身份跨框架迁移。本机=persona.md 文件 + 一键清空/导入，零依赖 | 借鉴（cicada 的 export/import 模式） |
| `meta-layer-optimizer` | DSPy/TextGrad、promptfoo | 它们优化「提示词」，本机优化「铁律+画像」元层：以违规/偏离日志为分数信号 + 留出集闸门防过拟合 | 借鉴 |

## F. 代码导航 + 界面评审（2 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `code-map` | Sourcegraph code graph、Aider repo-map、floorplan | repo-map 给 LLM 压缩上下文；本机是「改前画牵连地图 + 改后按图验证」的轻量 grep 编排 | 借鉴 |
| `design-qa` | impeccable、superdesign、v0 审查清单 | 把「AI 味」拆成**可判定清单**（Inter 字体/紫蓝渐变/卡片套卡片…），产出严重度+位置+改法的结构化 findings | 借鉴（清单化） |

## G. 文档 + 可视化（2 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `doc-to-markdown` | **MarkItDown**、pandoc、docling | 不复刻转换器：本机只做「选对工具 + Windows Word COM 兜底 + 直接喂 read」的编排 | 复用（MarkItDown/pandoc） |
| `browser-viz-local-scripts` | Gradio/Streamlit/NiceGUI、three.js | 框架重依赖，不满足「零依赖+无构建+3D」；Python 且接受依赖时优先框架 | 借鉴 + 复用 three.js |

## H. 运维 + 环境 + 工具暴露（4 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `dsh-upgrade-ops` | 官方升级文档、npm/pnpm 升级指南 | 官方不覆盖本机「两处安装 + 非标准 store + 沙箱 Schannel TLS」等坑；本机=升级前后四步强制检查 + 版本矩阵 | 自写（本机契约） |
| `mindspore-gpu-wsl` | 官方 MindSpore GPU 安装文档、WSL2 CUDA 指南 | 官方走 Linux 原生或自编译；本机是「官方预编译包 + WSL2 + compute_86 PTX JIT」的非标准可行路线 + sm_89 坑 | 自写（本机路线） |
| `windows-node-spawn-cli` | **cross-spawn、execa** | 业界事实标准，本机「全路径直调」是更弱自造方案 → 已改写为复用 | 复用 |
| `local-tool-mcp-exposure` | fastmcp、mcp-python-sdk、llms.txt 规范 | 轮子给传输层；本机补「SKILL.md 写作规则 + 示例经 MCP resource 下发 + 根 llms.txt 发现」三件套 | 复用（MCP SDK）+ 自写 |

## I. 学习 + 领域（5 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `directed-article-learning` | paper-to-agent、awesome-prompts 学习法 | 本机把「读文章」变成三分类（吸收/借鉴/忽略）+ 先申请后落地，且对照当前项目 | 借鉴 |
| `metro-traffic-prediction` | LibCity、DCRNN/STGCN 论文、MindSpore 官方模型仓 | 不是训练框架，是本机实测口径 + 文献速查卡（数据口径 / 收敛口径） | 借鉴 |
| `homophone-pun-analysis` | CodedLang、homo_gen、pypinyin | 本机独有「情感反转」视角无对应，taxonomy + pypinyin 复用 | 借鉴 + 复用 |
| `hpsks416` | 无强对应 | 纯个人透镜组合（控制论/递归/可证伪性），模型权重没有 | 自写 |
| `restricted-download-mirror-first` | 无强对应（下载器/镜像站各做一段） | 本机是流程契约：同渠道 ≤3 次即停、禁账号硬刚、镜像+校验交付 | 自写 |

## J. 专业领域（4 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `web-3d-asset-pipeline` | **glTF-Transform**、meshoptimizer | 压缩/纹理/校验全被 glTF-Transform 覆盖，本机应只做编排胶水 | 复用 |
| `rust-refactor-local-projects` | C2Rust、py2many | transpiler 全量翻译，给不了「profile-first 决策 + 边界选择」 | 借鉴（迁移管线思想） |
| `hatch-pet` | openai/skills 官方版（v1）、awesome-codex-pet | **本机是 v2 规格（8x11+16方向）升级版，非重复**；已退役 | 复用（校验工具） |
| `dsh-plugin-lazy-adapter-resolution` | deepseek-harness 本体、universal_llm_adapter | 懒解析模式可借，DSH 契约须自写 | 借鉴 + 自写 |

---

# 结论：一句话总纲

**36 个 skill 逐个对比完成。真正的「重复造轮子」只有 1 处（windows-node-spawn-cli，已改复用 cross-spawn）。其余是「现成轮子覆盖某几环、本机补上缺的那一环」或「本机是升级版」。**
