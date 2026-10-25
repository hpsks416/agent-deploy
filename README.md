# agent-deploy

一套 DSH / Codex / Claude Code 可复用的 skill 集合 + 一键部署脚本。

## 包含什么

| 类别 | skill |
|---|---|
| 提交推送 | `acp-studio`、`secure-push-workflow`、`github-ready-packager` |
| 安全 | `secret-scan`（密钥扫描） |
| 检索 | `open-source-scout`、`iron-law-retrieval-first` |
| 运维 | `dsh-upgrade-ops`（升级/闪退定位） |
| 文档 | `doc-to-markdown`（Word/PDF 转 Markdown） |
| 会话 | `resume-conversation-full`、`resume-conversation-brief`、`migrate-conversation-prompt` |
| 评估优化 | `skill-evaluator`、`skill-optimizer`、`meta-layer-optimizer`、`skill-lifecycle-manager` |
| 编排决策 | `agent-workflow-orchestration`、`agents-md-skill-layering`、`long-sentence-structurizer` |
| 画像 | `persona-manager` |
| 学习可视化 | `directed-article-learning`、`browser-viz-local-scripts` |

完整清单见 `core-skills.txt`。

## 快速上手

```bash
git clone https://github.com/hpsks416/agent-deploy.git
cd agent-deploy
./deploy.sh --framework codex --provider commandcode --model deepseek-v4-pro   # Linux / macOS
# Windows 用 pwsh deploy.ps1 -Framework codex -Provider commandcode -Model deepseek-v4-pro
```

> skill 从本仓 `skills/` 复制部署，不再 clone 独立子仓库（子仓库仅保留初版）。

三个参数独立可换：

| 维度 | 参数 | 可选 |
|---|---|---|
| 框架 | `-Framework` | `codex` / `claude` / `dsh` |
| 中间商 | `-Provider` | `providers.json` 的键 |
| 模型 | `-Model` | 该中间商 `models` 的别名 |

## 目标框架落点

| 框架 | skill 目录 | 指令文件 | 配置 |
|---|---|---|---|
| Codex | `~/.codex/skills/` | `~/.codex/AGENTS.md` | `~/.codex/config.toml` |
| Claude Code | `~/.claude/skills/` | `~/.claude/CLAUDE.md` | `~/.claude/claude-env.ps1` |
| DSH | `~/.dsh/skills/` | `~/.dsh/AGENTS.md` | `~/.dsh/settings.yaml` |

DSH 本机一键恢复：`pwsh dsh-config/install.ps1`

## 环境依赖

- Linux / macOS / Windows
- git + python3（`deploy.sh` 解析 providers.json 用）；Windows 用 `deploy.ps1` 需 PowerShell
- 目标框架（Codex / Claude Code / DSH 任选）

## 新增中间商 / 模型

编辑 `providers.json`，每个中间商需要 `openai_base_url`（OpenAI 兼容端点）、`api_key_env`（密钥环境变量名）、`models`（逻辑别名 → 模型 id）、`default_model`。

## 换框架后的核对

skill 正文里有少量框架相关引用（DSH 工具名、会话路径、环境硬编码），按 `FRAMEWORK-COUPLING.md` 核对即可。

> 注：本仓库的 `evals.yaml` 是**自创评测格式**，不兼容官方 AAIF 的 `evals.json`/`grading.json`——evals 是内部评测、不对外交互，故未迁移；要对官方生态交换 eval 数据时再迁。

## 仓库管理约定

与总框架相关的子仓库（`dsh-config/` 下的 dsh-goat-vision、dsh-skill-studio-patched、dsh-retrieval-guard、dsh-secure-push-guard、dsh-session-sync-flush）**仅保留初版、不再独立更新**；后续改动只进本仓库。新建与总框架相关的子仓库后即废弃、纳入 `dsh-config/`。

## License

[MIT](LICENSE)
