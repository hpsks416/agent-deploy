# agent-deploy

AGENT 框架的跨框架部署器：**换框架 / 换中间商 / 换模型，一键铺到位**。

核心资产（14 个元能力链 skill + 两条铁律）是框架无关的 AgentSkills 格式；本部署器只做三件「薄壳」适配：

1. 铺 skill 到目标框架的全局 skill 目录
2. 铺铁律到目标框架的全局指令文件（`AGENTS.md` / `CLAUDE.md`）
3. 生成目标框架的中间商/模型配置（`config.toml` / env / `settings.yaml`）

## 三个维度独立可换

| 维度 | 参数 | 可选 |
|------|------|------|
| 框架 | `-Framework` | `codex` / `claude` / `dsh` |
| 中间商 | `-Provider` | `providers.json` 的键（当前：`commandcode` / `deepseek`） |
| 模型 | `-Model` | 该中间商 `models` 的别名 |

## 用法

```powershell
git clone https://github.com/hpsks416/agent-deploy.git
cd agent-deploy

# 换框架：DSH -> Codex（中间商 Command Code，模型 DS v4 pro）
pwsh deploy.ps1 -Framework codex -Provider commandcode -Model deepseek-v4-pro

# 换框架 + 换中间商 + 换模型：-> Claude Code + DeepSeek 官方 + flash
pwsh deploy.ps1 -Framework claude -Provider deepseek -Model deepseek-flash

# 只预览不写入
pwsh deploy.ps1 -Framework codex -DryRun

# 国内直连（Gitee 源）
pwsh deploy.ps1 -Framework codex -Source gitee
```

## 目标框架落点

| 框架 | skill 目录 | 指令文件 | 配置文件 |
|------|-----------|---------|---------|
| Codex | `~/.codex/skills/` | `~/.codex/AGENTS.md` | `~/.codex/config.toml` |
| Claude Code | `~/.claude/skills/` | `~/.claude/CLAUDE.md` | `~/.claude/claude-env.ps1` |
| DSH | `~/.dsh/skills/` | `~/.dsh/AGENTS.md` | `~/.dsh/settings.yaml` |

## 目录结构

```text
agent-deploy/
├── deploy.ps1             # 部署器
├── providers.json         # 中间商 + 模型目录
├── core-skills.txt        # 14 个核心 skill 清单（含耦合等级）
├── templates/
│   └── agents-core.md     # 框架无关的两条铁律模板
├── FRAMEWORK-COUPLING.md  # 框架耦合清单
└── README.md
```

## 新增中间商 / 模型

编辑 `providers.json`，每个中间商需要：

- `openai_base_url`：OpenAI 兼容端点（Codex / DSH 用）
- `anthropic_base_url`：Anthropic 兼容端点（Claude Code 用，无则 `null`）
- `api_key_env`：API key 的环境变量名
- `models`：逻辑别名 → 该中间商的模型 id
- `default_model`：默认模型别名

## 换框架后的核对

skill 正文里有少量框架相关引用（DSH 工具名、会话路径、owner 硬编码），按 [FRAMEWORK-COUPLING.md](FRAMEWORK-COUPLING.md) 核对即可。核心 skill 的「心智」（铁律 + 元认知链 + 编排 + 检索 + 安全 + 发布）是框架无关的。

## License

MIT License. See [LICENSE](LICENSE).
