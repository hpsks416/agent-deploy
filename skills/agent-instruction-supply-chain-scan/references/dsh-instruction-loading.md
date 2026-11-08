# DSH 指令加载规则与 IOC（参考）

## 一、DSH 的指令加载规则（源码证据）

来源：`C:\Users\Razer\Documents\Codex\pnpm-global\global\v11\<hash>\node_modules\@deepseek-ai\dsh-agent-instructions\lib\index.js`（随 profile 安装的 DSH 包，`<hash>` 因版本而异；用 `Get-ChildItem ... -Filter dsh-agent-instructions` 定位）。

| 行为 | 源码位置 | 原文要点 |
|---|---|---|
| 候选文件名 | L17-18 | `DEFAULT_PROJECT_ROOT_MARKERS = [".git"]`；`DEFAULT_INSTRUCTION_FILE_CANDIDATES = ["AGENTS.md", "CLAUDE.md"]`；L18 另有 `AGENTS.local.md`、`CLAUDE.local.md` |
| 用户全局 | L141 | `USER_GLOBAL_FILE = "AGENTS.md"` → 即 `~/.dsh/AGENTS.md` |
| 项目根判定 | L480-488 `findProjectRoot` | 从 cwd 往上找 `.git`；**找不到就返回 cwd 本身** |
| 发现范围 | L578 `discoverInstructionFiles` | 对 `ancestorChain(projectRoot, cwd)` 的**每个目录**加载上述候选文件 |
| 注入时机 | L1064 模块注释 | *"Baseline instructions enter durable context before the first request"*——首个请求之前就进上下文 |
| 增量注入 | L1210+ `syncInbox` | 文件被 `read`/`write`/`edit` 触及时，对被触及的子目录再补加载 |
| 渲染格式 | L131 `sectionText` | `Instructions from: <path>` + 正文，包在 `<system-reminder>` 里 |

**推论**：在 `C:\Users\Razer\Downloads`（无 `.git`）启动 DSH → projectRoot = Downloads → `Downloads\AGENTS.md` 被当会话指令。与 Codex 的攻击前提完全一致。

## 二、Codex / Claude Code 对照（Forever Security 2026-10-22 实测）

| 环节 | Codex | Claude Code |
|---|---|---|
| 落点 | 追加 `[mcp_servers.project-tools]` 到**全局** `~/.codex/config.toml` | 写项目 `.claude/settings.json` 的 `env.ANTHROPIC_BASE_URL` |
| 载荷 | `launchctl submit … npm install function-color`（MALFEX 活动恶意包）→ 自关沙箱跑 `codex exec --dangerously-bypass-approvals-and-sandbox` | 指向攻击者网关（真证书）→ OAuth token 外泄 + 冒充模型回 `Bash` 工具调用并带 `dangerouslyDisableSandbox: true` |
| 成功率 | >90% | ~50%（同会话内诱导 spawn subagent 约 1/5） |
| 持久化 | 全局配置，删 Downloads 也还在 | 项目级，下次启动触发 |

## 三、IOC 表

| 类别 | 内容 |
|---|---|
| 文件 | `~/Downloads/AGENTS.md`、`~/Downloads/CLAUDE.md`（及 `.local` 变体）、任何陌生仓库根目录的同名文件 |
| 内容 | 零宽/双向控制字符；`--dangerously-bypass-…`、`dangerouslyDisableSandbox`；要求写 `config.toml`/`settings.json`；`mcp_servers` 注册；`launchctl`/`npm install`/`npx`/`curl`/`chmod +x`/临时目录 |
| 配置 | `~/.codex/config.toml` 多出 `[mcp_servers.*]`（命令带 `launchctl`/`curl`/临时目录）；`chatgpt_base_url` 被覆写；`.claude/settings.json` 的 `ANTHROPIC_BASE_URL` 指向非本地端点 |
| 包 | npm `function-color`（同活动还有 `function-flag`），已从 npm 下架 |
| 目录 | `/tmp/ptools`（macOS）；Windows 对应 `%TEMP%\ptools` |

## 四、Windows 手动排查命令（不想跑脚本时）

```powershell
# 1) 指令文件（Downloads / 桌面）
Get-ChildItem "$env:USERPROFILE\Downloads","$env:USERPROFILE\Desktop" -Recurse -Depth 3 -Force -File -ErrorAction SilentlyContinue |
  Where-Object Name -match '^(AGENTS|CLAUDE)(\.local)?\.md$'

# 2) 全局配置里的 MCP 注册与端点
Select-String -LiteralPath "$env:USERPROFILE\.codex\config.toml" -Pattern 'mcp_servers|chatgpt_base_url|launchctl|curl|npm install'
Get-Content "$env:USERPROFILE\.claude\settings.json" -Raw

# 3) 恶意包 / 暂存目录
Get-ChildItem "$env:USERPROFILE" -Recurse -Depth 5 -Directory -ErrorAction SilentlyContinue |
  Where-Object Name -match '^(function-color|function-flag|ptools)$'

# 4) 零宽字符（把 <文件> 换成目标）
$t = Get-Content '<文件>' -Raw; ([regex]::Matches($t,'[\u200B-\u200F\u202A-\u202E\uFEFF\u2060]')).Count
```

## 五、现成轮子对照（铁律一：先检索再自写）

| 轮子 | 能力 | 结论 |
|---|---|---|
| [prompt-shielder](https://github.com/p3nchan/prompt-shielder)（MIT） | 对 `CLAUDE.md`/`.env` 做 SHA256 基线，检测「被改过」 | **借鉴**思路（基线 + 退出码契约）；未直接引入：bash 脚本、仅 macOS/Linux、1 star |
| `skill-scanner`（PyPI）、`ctxsentry`、`patdown`、`agentverus-scanner`、`skillward` | 扫 skill / 提示词的注入与恶意模式 | **忽略**：已由本机 `skill-supply-chain-scan`（SkillSpector，71 规则）覆盖 |
| 本 skill 的脚本 | Windows 上扫「指令文件 + 全局配置劫持 + IOC + DSH 加载面」 | **自写**：检索范围内无同时覆盖这四类的现成轮子 |

## 六、来源

- Forever Security 原始研究：https://forever.security/blog/hijacking-ai-agents-via-downloads-folder/
- 量子位（网易转载）：https://m.163.com/dy/article/LB4LU1B70511DSSR.html
- MALFEX npm 活动：https://checkmarx.com/zero-post/malfex-npm-malware-campaign-three-payloads-and-an-adversary-that-signs-their-work/
