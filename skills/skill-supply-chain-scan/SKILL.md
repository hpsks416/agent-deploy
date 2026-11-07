---
name: skill-supply-chain-scan
description: 装任何第三方 skill/插件/MCP 前先做供应链扫描（SkillSpector 71 漏洞模式/17 类：提示注入、数据外泄、提权、供应链投毒、过度代理、记忆投毒、工具滥用、流氓 agent 等），断言 exit code，命中恶意模式就拒绝安装（吸收 NVIDIA SkillSpector）。Use when 要装第三方 skill/插件/MCP、或要审查某个 skill 是否有恶意模式。
---

# skill-supply-chain-scan（供应链扫描门禁）

框架缺口：本机 skill + 插件均为「隐式信任安装」。装前扫描补上这个门禁。

## 流程

1. 拿到第三方 skill / 插件的源码目录。
2. 用 SkillSpector 本地静态扫描（`--no-llm`，不调 LLM）：
   `skillspector scan <目录> --no-llm --format sarif`
   > 本机 skillspector 装在 `G:\CodexDS\DSH\INTRO\SkillSpector\.venv\Scripts\skillspector.exe`（Python 3.12 venv，v2.12.0）。
3. **断言 exit code**：非 0 = 命中漏洞模式，**拒绝安装**。
4. 读报告，按 17 类漏洞模式分类（提示注入、数据外泄、提权、供应链投毒、过度代理、输出处理、系统提示泄露、记忆投毒、工具滥用、流氓 agent、反拒答、危险代码 AST、污点、YARA、MCP 最小权限/投毒等）。
5. 命中 `DO_NOT_INSTALL` / exit 1 → 拒绝安装 + 报告原因；干净 → 放行。

## 铁律

- **装前必扫**：装任何第三方 skill / 插件 / MCP 前，没有扫描报告不放行。
- **断言 exit code**：靠 exit code 判定，不靠「看起来没事」。
- **不装破甲 / 流氓 agent**：命中「反拒答 / 流氓 agent / 系统提示泄露」模式的一律拒绝（生态已出现针对本 harness 的破甲插件，见安全域 KB）。
