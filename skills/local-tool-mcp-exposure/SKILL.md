---
name: local-tool-mcp-exposure
description: 把本地工具/脚本/项目做成「agent 可全权驱动」——用 MCP server 暴露操作、自带 SKILL.md（写作规则+官方示例，经 MCP resource 下发）、根 llms.txt 供发现。Use when the user wants to make a local tool/CLI/project drivable by an agent (Claude Code/Cursor/DSH) or asks to expose a local app via MCP/skill/llms.txt. Not for one-off scripts or browser-only visualization (见 browser-viz-local-scripts).
---

# Local Tool MCP Exposure（本地工具自暴露 MCP + skill + llms.txt）

把本地工具/脚本/项目做成「agent 可全权驱动」，用**三件套**：MCP server + 自带 SKILL.md + llms.txt。模式源自 YuE2-Studio 的实测（162 个 MCP 工具 + `studio://skill` 资源 + llms.txt，Claude Code/Cursor 可全权接管）。

## 三件套

1. **MCP server** —— 把工具的操作暴露成 MCP 工具。
   - Python 用官方 MCP SDK 的 `FastMCP`（`pip install mcp`，`from mcp.server.fastmcp import FastMCP`）；Node 用 `@modelcontextprotocol/sdk`。
   - 每个操作 = 一个带 typed 参数的 tool 函数，agent 直接调用；返回要结构化、可判定。
2. **自带 SKILL.md** —— 把「怎么用这个工具、写作规则、官方示例」写成一份 skill，**经 MCP resource 下发给 agent**。
   - 用 `@mcp.resource("tool://skill")`（或 `studio://skill`）暴露 SKILL.md 全文。
   - agent 先 `read_resource` 读这份说明书，再开始用工具——等于「工具自带说明书」。
3. **llms.txt** —— 项目根放一份 [llms.txt](https://llmstxt.org/)，一句话说明「这是什么 + MCP 地址 + 如何连接」，供 agent 发现入口。

## 步骤

1. 把工具的核心操作列成清单（tool 名 + 参数 + 返回）。
2. 用 FastMCP 写 server（见 `templates/fastmcp_server.py`），每个操作一个 tool。
3. 把「写作规则 + 官方示例」写进 SKILL.md（见 `templates/SKILL.md.tpl`），用 `@mcp.resource("tool://skill")` 暴露。
4. 写根 `llms.txt`（见 `templates/llms.txt`），给出 MCP 连接命令。
5. 验证：`claude mcp add --transport http <name> http://127.0.0.1:<port>/mcp`，让 agent 读 skill 后跑一个最小任务。

## 工具集分层与进程生命周期（借 craft-anything）

工具一多（几十上百个）就会吃掉上下文、也被误调用。参考 `dsh-craft-anything` 的接入层设计，把「暴露多少」和「进程怎么活」做成显式契约：

### 1. 分层暴露（Essentials + 按需工具集）

- 默认只暴露 **Essentials**（约 30 个高频工具），命名统一 `<server>__<tool>`（如 `mcp__craft__core_target_open`）。
- 深层能力按**工具集**分组（browser / android / java / formats / native …），运行时按需开启：
  - `<server>__list_toolsets` —— 列出可用工具集与工具数；
  - `<server>__enable_toolset <name>` —— 开启一个工具集（或整体切「深度模式」）。
- **能力发现做成工具，不要写成文档**：agent 用 `list_toolsets` 自己查，比在 SKILL.md 里列 162 个工具更省 token、更不会过期。

### 2. 模式切换要连带重启服务进程

- 模式开关（净室 / 深度）写到 `mode.json`，然后**重启 MCP 子进程**让新工具表生效。
- 依赖宿主 MCP client 的自动重连：重启后 1–2 秒内工具列表重新同步，调用方不需要知道重启发生过。
- 不要试图热改工具表——协议层没有增量注册，重启是最稳的。

### 3. 重启必须带兜底，别拖住宿主

进程不响应 SIGTERM 时按阶梯处理，绝不无限等：

1. 发 `SIGTERM`；
2. 等 1.5s 仍未退出 → `SIGKILL`；
3. 再等 3s → 强制退出并向宿主报告失败（宿主继续可用）。

### 4. 给一个状态工具

`<server>_status` 一次返回：CLI 路径与版本、是否 portable、当前模式、工具集与工具数、可用引擎（chromium/gdb/java…）、依赖是否就绪。排障时先看它，不猜。

## 参考

- YuE2-Studio：162 个 MCP 工具（分组）；`studio://skill` 资源 + `studio` prompt；根 llms.txt；把「写作规则 + 官方示例」随服务下发，agent 自己写 style/lyrics。
- MCP 规范：https://modelcontextprotocol.io/ ；FastMCP：https://gofastmcp.com/ ；llms.txt：https://llmstxt.org/

## 模板

- `templates/fastmcp_server.py` —— FastMCP 最小骨架（`@mcp.tool` + `@mcp.resource("tool://skill")`）。
- `templates/llms.txt` —— 根 llms.txt 模板。
- `templates/SKILL.md.tpl` —— 工具自带 skill 骨架（frontmatter + 工具清单 + 写作规则 + 示例）。

## 何时用 / 不用

- **用**：本地工具要被 agent 反复驱动（生成、扒谱、渲染、批量操作）；想把「工具说明书」随工具分发。
- **不用**：一次性脚本；纯浏览器可视化（→ `browser-viz-local-scripts`）；托管 Web 应用。

## 铁律

- 复用 MCP / FastMCP / llms.txt 标准，不重造协议（铁律一）。
- served-skill 必须含「写作规则 + 官方示例」，否则 agent 无从下手。
- 动手前先检索是否已有现成 MCP server / 现成封装（铁律一）。
