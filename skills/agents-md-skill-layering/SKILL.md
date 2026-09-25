---
name: agents-md-skill-layering
description: Use when deciding whether a rule belongs in the global AGENTS.md or inside a skill.
---

## 概述
把「每次都要自动触发」的内容放进全局 AGENTS.md，把「需要时才展开的流程」留在 skill，两层不重复。

## 何时用
- 你想让某条规则「每次结束都自动判断」，而不只是被召唤时才生效。
- 你发现 AGENTS.md 和某个 skill 正文里写了同一段口诀/步骤。

## 核心模式
| 内容类型 | 放哪 |
|---|---|
| 触发判断、阈值、先申请后执行的授权规则 | AGENTS.md（常驻） |
| 具体步骤、分层细节、脚本、迭代流程 | skill 正文 |

- AGENTS.md 只保留「何时触发 + 要不要申请」；详情一律指向对应 skill。
- skill 里不要再复述 AGENTS.md 已写的触发规则。
- 改完确认系统注入了新版本（会话里会出现 updated instructions 提示）。

## 常见错误
- 把长流程塞进 AGENTS.md → 常驻提示膨胀、和 skill 内容漂移。
- 把「每次自动触发」的规则只写进 skill → 实际不会自动生效。
