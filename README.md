# agent-deploy

> **一个「文件原生」的自我演进 agent 框架** —— 把元认知外置成可审计、可移植、人类可裁决的文件生态，换框架 / 换中间商 / 换模型一键带走。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 这是什么

一句话：**不是「部署脚本集」，而是一套让 AI agent 会自我评估、自我优化、记住你、跨框架迁移的文件生态。**

它把「元认知」从模型内部外置到工作区文件（Markdown + 脚本 + 铁律），六条能力线：

- 🔍 **自我评估**（`skill-evaluator`）—— 测量 skill 是否真有 lift，只报数据、不替人裁决
- ♻️ **自我优化**（`skill-optimizer`）—— rollout→reflect→edit→gate，留出验证集防过拟合、防表面反思
- 🧠 **记住用户**（`persona.md`）—— 六维画像（人格/思维习惯/决策偏好/纠错模式/语言风格/环境约定），收尾持续积累
- 🧵 **续接历史**（`resume-conversation-*`）—— 可插拔会话源，不绑死某个框架
- 🛡️ **安全发布**（`secret-scan` + `secure-push-workflow`）—— 安检不过，绝不推送
- 🚚 **跨框架带走**（`deploy.ps1`）—— 遵循 AgentSkills 事实标准，一个参数换框架

## 为什么需要它（和别的方案差在哪）

| 对比对象 | 它缺什么 | 本框架补什么 |
|---------|---------|-------------|
| 直接 `git clone` / `scp` | 只复制文件，不铺配置、不跨框架 | 一键铺 skill + 铁律 + provider/model 配置 |
| Codex / Claude Code | 无元认知（不自评自优）、无画像 | 外置评估/优化闭环 + persona 画像 |
| LangGraph / AutoGen / CrewAI | 编排但不评估自身、重 SDK | 文件生态、零依赖、可审计 |
| Mem0 / Letta（记忆框架） | 向量库重依赖、黑盒 | `persona.md` 文件，可 diff / 可 git |

**一句话独特性**：别人造「能干活的 agent」，本框架造「**会反思、会记住你、能跨框架带走的 agent**」。完整逐级/逐个对比见 [COMPARISON.md](COMPARISON.md)。

## 核心能力（独特架构）

1. **元认知外置**：前馈 Transformer 长不出「看到自己」的眼睛，所以从外部装上——`skill-evaluator`（测量）+ `skill-optimizer`（优化 + gate 防过拟合）。
2. **可插拔会话源**：对话继承不绑死 DSH，`conversation-sources` 注册表换框架只需追加一个源，正文不动。
3. **跨框架部署**：遵循 AgentSkills 事实标准（`skills/<name>/SKILL.md`），Codex / Claude Code / DSH 共用同一套 skill 正文，换框架只改薄壳。
4. **人类裁决**：铁律二「先申请后执行」——skill 建立、优化、画像积累，最终都由人拍板，不擅自落地。

## 快速上手（3 分钟）

```powershell
git clone https://github.com/hpsks416/agent-deploy.git
cd agent-deploy

# 一键部署到目标框架（换框架 / 中间商 / 模型各一个参数）
pwsh deploy.ps1 -Framework codex -Provider commandcode -Model deepseek-v4-pro

# 或国内 Gitee 源直连
pwsh deploy.ps1 -Framework codex -Source gitee
```

三个维度独立可换：

| 维度 | 参数 | 可选 |
|------|------|------|
| 框架 | `-Framework` | `codex` / `claude` / `dsh` |
| 中间商 | `-Provider` | `providers.json` 的键（当前 `commandcode` / `deepseek`） |
| 模型 | `-Model` | 该中间商 `models` 的别名 |

目标框架落点：

| 框架 | skill 目录 | 指令文件 | 配置文件 |
|------|-----------|---------|---------|
| Codex | `~/.codex/skills/` | `~/.codex/AGENTS.md` | `~/.codex/config.toml` |
| Claude Code | `~/.claude/skills/` | `~/.claude/CLAUDE.md` | `~/.claude/claude-env.ps1` |
| DSH | `~/.dsh/skills/` | `~/.dsh/AGENTS.md` | `~/.dsh/settings.yaml` |

DSH 本机一键恢复（换机器）：`pwsh dsh-config/install.ps1`

## 环境依赖

- 操作系统：Windows
- 运行时：PowerShell（pwsh）+ git
- 目标框架：Codex / Claude Code / DSH（任选其一）

## 文档导航

- [FRAMEWORK.md](FRAMEWORK.md) — 框架地图（8 层架构 + 15 核心 skill + 元认知闭环）
- [COMPARISON.md](COMPARISON.md) — 与 23 个轮子的逐级 / 逐个对比
- [FRAMEWORK-COUPLING.md](FRAMEWORK-COUPLING.md) — 换框架时的耦合核对清单

## 目录结构

```text
agent-deploy/
├── FRAMEWORK.md            # 框架总览（总领全文，先读这个）
├── COMPARISON.md           # 框架及各 skill 与其他轮子的区别
├── deploy.ps1              # 跨框架部署器
├── providers.json          # 中间商 + 模型目录
├── core-skills.txt         # 15 个核心 skill 清单（含耦合等级）
├── skills/                 # 15 个核心 skill（已合并，废弃独立仓库）
├── templates/agents-core.md  # 框架无关的两条铁律模板
├── FRAMEWORK-COUPLING.md   # 框架耦合清单
├── dsh-config/             # DSH 本机架构（含 install.ps1）
└── README.md
```

## 新增中间商 / 模型

编辑 `providers.json`，每个中间商需要：`openai_base_url`（OpenAI 兼容端点，Codex/DSH 用）、`anthropic_base_url`（Anthropic 兼容端点，Claude Code 用，无则 `null`）、`api_key_env`（密钥环境变量名）、`models`（逻辑别名 → 模型 id）、`default_model`。

## 换框架后的核对

skill 正文里有少量框架相关引用（DSH 工具名、会话路径、owner 硬编码），按 [FRAMEWORK-COUPLING.md](FRAMEWORK-COUPLING.md) 核对即可。核心 skill 的「心智」（铁律 + 元认知链 + 编排 + 检索 + 安全 + 发布）是框架无关的。

## License

[MIT](LICENSE)
