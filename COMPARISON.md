# 框架及各 SKILL 与其他轮子的区别（逐级对比 · 逐个对比）

> 铁律一「优先检索现成轮子」的完整答卷。分两级：**框架级**（整套框架 vs 其他 agent 框架 / 元认知路径）→ **skill 级**（23 个 skill 逐个 vs 对应轮子）。

---

# 第一部分：框架级对比

## 1. 整套框架 vs 其他 agent 框架（CLI 工作台 / 编排框架）

| 维度 | 本框架（agent-deploy 这套） | Codex / Claude Code | LangGraph / AutoGen / CrewAI |
|------|---------------------------|--------------------|------------------------------|
| 定位 | 个人「自演进」agent 环境 | 通用 coding agent 工作台 | 通用多智能体编排 SDK |
| 元认知 | **外置**（skill-evaluator/optimizer 闭环） | 无（靠模型自身） | 无（编排不评估自身） |
| 用户画像 | **persona.md 六维** + 收尾积累 | CLAUDE.md 记忆（仅 Claude） | 无 |
| 自我优化 | **有**（rollout→reflect→edit→gate 防过拟合） | 无 | 无 |
| 跨框架 | **有**（agent-deploy 一键铺） | 各自绑定 | SDK 框架无关但重 |
| 安全门控 | **有**（secret-scan 硬门控） | 无 | 无 |
| 可审计 | **高**（文件生态，人可读/diff/git） | 中 | 低（黑盒代码） |
| 依赖重量 | 轻（纯文件 + 脚本） | 中 | 重（SDK/服务） |

**一句话**：其他框架是「能干活的 agent」，本框架是「会自我评估、自我优化、记住你、且能跨框架带走的 agent」——差异不在「能不能写代码」，在「有没有把元认知外置成可审计的文件生态」。

## 2. 元认知路径：外置 vs 内化

| 维度 | 本框架（外置·文件生态） | 内化路径（架构/微调/RL） | SOFAI-LM（免训练控制器） |
|------|------------------------|------------------------|------------------------|
| 元认知位置 | 工作区文件/脚本 | 模型权重/架构 | 外部代码控制器 |
| 可审计性 | **高**（可 diff/git） | 低（黑盒） | 中 |
| 可移植性 | **高**（AgentSkills 规范 + agent-deploy） | 低（绑模型） | 中 |
| 成本 | 低（token 即成本） | 高（推理税/训练） | 中 |
| 防「假反思」 | **有**（gate + 防表面反思铁律） | 弱（微调易「礼貌性免责声明」） | 有（预算回退） |
| 原生性 | 低 | **高**（模型自己会） | 中 |

**一句话**：内化路径让模型「长出」元认知（黑盒、贵），本框架承认前馈架构长不出「看到自己」的眼睛，于是**从外部装上这只眼睛并做成文件**——互补而非竞争。

---

# 第二部分：skill 级逐个对比（23 个）

判断三分类：**复用**（直接用轮子）· **借鉴**（吸收思想 + 自写）· **自写**（本机契约，无轮子覆盖）。

## A. 元认知链（3 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `skill-evaluator` | promptfoo、LangSmith eval、skill-ab-eval | 轮子评估「代码/提示词」，本机评估「skill 是否有 lift」，且**全过程判定**（中间消息+最终答复）独有 | 借鉴 |
| `skill-optimizer` | **微软 SkillOpt**、DSPy | 思想同源（rollout→reflect→edit→gate），本机是轻量版 + 补了「防表面反思」铁律 | 借鉴（直接对标） |
| `skill-lifecycle-manager` | AutoSkill、skill-evolution | 轮子管「生成 skill」，本机管「元认知触发 + 分层 + 脚本化迁移」全生命周期 | 借鉴 + 自写 |

## B. 编排 + 检索（2 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `agent-workflow-orchestration` | LangGraph、A2A 协议 | 轮子是「编排框架/协议」，本机是「agent 编排自身」的方法论 + DSH 工具落地，A2A 的 Agent Card/不透明性已吸收 | 借鉴 |
| `open-source-scout` | OSSInsight、libraries.io、fossick-mcp | 轮子各覆盖「搜索/指标」一环，本机做「找→核实→评估→结论」闭环 | 借鉴（轮子作信号源） |

## C. 安全发布（4 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `secret-scan` | **gitleaks**、trufflehog、detect-secrets | gitleaks 最吻合（--redact 脱敏），但本机=零依赖 stdlib + Gitee 规则 + 本机凭据 | 借鉴（gitleaks 规则） |
| `secure-push-workflow` | CI/CD secret gate、agent-skills-workflows | 轮子是「CI 里的门禁」，本机是「本地打包→安检→推送」硬门控编排 | 自写（本机契约） |
| `github-ready-packager` | git archive、scaf/docwiz | 轮子各做「排除/补文件」一环，本机做「整理+安检+打包」三步编排 | 自写（复用 git 原语） |
| `acp-studio` | gh CLI、git GUI、gitsync | 无单一轮子覆盖「GitHub+Gitee 统一 + ff-only + 安检门禁」，本机=薄编排层复用 git 原语 | 自写 |

## D. 对话继承（3 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `resume-conversation-full` | claude-handoff、Context Shift | 轮子做「会话→上下文交接」，本机做「可插拔会话源（codex-md/dsh-native）+ 全文直读」 | 借鉴（分块思路） |
| `resume-conversation-brief` | 同上 | 本机做「map-reduce 精炼 + 每结论引用来源」快照 | 借鉴 |
| `migrate-conversation-prompt` | Claude Context Shift、infinite-context-mcp | 轮子覆盖「会话→可移植上下文」一半；读 DSH conversations/*.md + 完整性校验是 DSH 私有 | 借鉴 + 自写 |

## E. 决策 + 画像（3 个）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `agents-md-skill-layering` | Anthropic Agent Skills、CircleCI《AGENTS.md vs skills》 | 分层规则已现成（小且恒真→AGENTS.md，大且情境化→skill），本机落地成决策 skill | 借鉴 |
| `long-sentence-structurizer` | RePrompter、flompt | 轮子重（带评分+section 化），本机=轻量四段模板，吸收了 section 拆分 | 借鉴 |
| `persona-manager` | Mem0、cicada（金蝉脱壳） | Mem0=向量记忆重依赖；cicada=身份跨框架迁移。本机=persona.md 文件 + 一键清空/导入，零依赖 | 借鉴（cicada 的 export/import 模式） |

## F. 专业领域（8 个，保留独立仓库）

| skill | 对应轮子 | 核心区别 | 判断 |
|-------|---------|---------|------|
| `web-3d-asset-pipeline` | **glTF-Transform**、meshoptimizer | 压缩/纹理/校验全被 glTF-Transform 覆盖，本机应只做编排胶水 | 复用 |
| `rust-refactor-local-projects` | C2Rust、py2many | transpiler 全量翻译，给不了「profile-first 决策 + 边界选择」 | 借鉴（迁移管线思想） |
| `browser-viz-local-scripts` | Gradio/Streamlit/NiceGUI、three.js | 框架重依赖，不满足「零依赖+无构建+3D」；Python 且接受依赖时优先框架 | 借鉴 + 复用 three.js |
| `homophone-pun-analysis` | CodedLang、homo_gen、pypinyin | 本机独有「情感反转」视角无对应，taxonomy + pypinyin 复用 | 借鉴 + 复用 |
| `windows-node-spawn-cli` | **cross-spawn、execa** | 业界事实标准，本机「全路径直调」是更弱自造方案 → 已改写为复用 | 复用 |
| `dsh-plugin-lazy-adapter-resolution` | deepseek-harness 本体、universal_llm_adapter | 懒解析模式可借，DSH 契约须自写 | 借鉴 + 自写 |
| `hatch-pet` | openai/skills 官方版（v1）、awesome-codex-pet | **本机是 v2 规格（8x11+16方向）升级版，非重复**；已退役 | 复用（校验工具） |
| `hpsks416` | 无强对应 | 纯个人透镜组合，模型权重没有 | 自写 |

---

# 结论：一句话总纲

**23 个 skill 逐个对比完成。真正的「重复造轮子」只有 1 处（windows-node-spawn-cli，已改复用 cross-spawn）。其余全部是「现成轮子覆盖某几环、本机契约补上缺的那一环」，或「本机是升级版/独有视角」。框架级的差异不在「能不能干活」，在「有没有把元认知外置成可审计、可移植、可防假、人类可裁决的文件生态」。**
