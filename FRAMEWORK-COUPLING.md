# 框架耦合清单

本清单说明：14 个核心 skill 在「换框架」时，哪些需要人工核对、哪些可以直接用。

## 前提

skill 资产本身是**框架无关**的 AgentSkills 格式（`SKILL.md` + frontmatter `name`/`description` + `scripts/`/`references/`），Codex / Claude Code / DSH 共用同一套约定。所以「换框架」对 skill 正文而言是「复制到不同目录」，不是「转译」。

但 skill 正文里会**散落少量「框架相关」的引用**——DSH 的工具名（`skillmgr_*`、`session_query`）、DSH 的会话路径（`~/.dsh\sessions`、projcache、`.zstd`）、以及环境硬编码（proxy、owner、凭据）。这些是「换框架/换机器」后需要核对的点，按耦合度分四档：

| 等级 | 含义 | 处理 |
|------|------|------|
| `none` | 框架无关 | 直接用，零改动 |
| `light` | 轻耦合（工具名/会话源在可插拔处） | 换框架后改可插拔处（工具名 / `conversation-sources` 注册表），正文不动 |
| `env` | 环境硬编码 | 换机器/换网络/换 owner 时改（与框架无关） |
| `hardcode` | owner 硬编码 | 换 owner 时改 |

## 逐项清单

### none —— 框架无关（直接可用）

| skill | 说明 |
|-------|------|
| `skill-lifecycle-manager` | 元认知生命周期方法论，用泛化措辞，具体工具操作委托给对应 skill |
| `open-source-scout` | 检索轮子方法论 |
| `secure-push-workflow` | 发布编排逻辑（依赖的 acp-studio/secret-scan 有 env/hardcode 耦合，见下） |
| `github-ready-packager` | 打包整理 |
| `migrate-conversation-prompt` | 生成迁移提示词 |
| `agents-md-skill-layering` | AGENTS.md vs skill 分层决策 |
| `long-sentence-structurizer` | 长难句结构化 |

### light —— 轻耦合（换框架时改可插拔处，正文不动）

| skill | 框架相关点 | 处理 |
|-------|-----------|------|
| `skill-evaluator` | `skillmgr_get` | 框架「目录即加载」，直接读 `SKILL.md` 路径 |
| `skill-optimizer` | `skillmgr_get` | 同上 |
| `agent-workflow-orchestration` | `subagent`/`subagent_fork`/`list_agents`/`send_message`/`session_call`/`session_query`/`board_*`/`skillmgr_*` | 换成目标框架的多智能体机制；`skillmgr_*` → 目录即加载 |
| `resume-conversation-full` | 会话源在 `conversation-sources` 注册表 | 换框架 = 在注册表追加目标框架源（如 `codex-native`），正文不动 |
| `resume-conversation-brief` | 同上 | 同上 |

### env —— 环境硬编码（换机器/网络/owner 时改）

| skill | 硬编码点 |
|-------|---------|
| `acp-studio` | proxy `127.0.0.1:7897`、`http.sslBackend=openssl`、owner `hpsks416`（脚本 default）、`GITEE_USERNAME`/`GITEE_TOKEN` 凭据 |

### hardcode —— owner 硬编码

| skill | 硬编码点 |
|-------|---------|
| `secret-scan` | owner `hpsks416`（SKILL.md 第 20、54 行 + `scripts/scan_secrets.py`） |

## 换框架操作建议

1. 跑 `deploy.ps1 -Framework <codex|claude> ...` 铺目录 + 配置。
2. 按上表核对 `light` 档：`skillmgr_*` → 目录即加载；多智能体工具 → 目标框架等价机制。
3. `resume-conversation-*` 正文已框架无关，换框架时在 `conversation-sources.md` 注册表追加目标框架会话源（如 `codex-native`）即可，正文不动。
4. `env`/`hardcode` 档与框架无关，只在换机器/换网络/换 owner 时改。

## 换模型（模型特异）

skill 不仅「框架特异」，还**「模型特异」**——元认知是索引性的，它依赖「自己是谁、能力边界在哪」，而这个信息是模型自己的运行状态，不随 skill 迁移。

- `description` 的触发依赖模型的「描述匹配能力」：同一个 description，DS v4 能正确触发，换到 Claude/Kimi 后匹配率可能下降或误触发。
- skill 的 lift（A/B 基线）是**相对某个模型**的：在 DS v4 上「有没有都一样」的 skill，换到更强/更弱的模型后 lift 可能翻转为有效或无效。

所以**换模型后要重估，不能假设原 skill 的触发和 lift 依然成立**：跑一遍 `skill-evaluator` 的静态体检 + A/B（新模型下的新基线），`skill-optimizer` 的 gate 集也要按新模型重新标定。
