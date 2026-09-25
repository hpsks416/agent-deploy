---
name: resume-conversation-full
description: 在对话中用 `/resume-conversation-full <对话名>` 继承既有对话的完整细节——遍历可插拔的会话源（conversation-sources 注册表）定位对话，全文直读（大文件分段），不搬移文件。Use when the user types "/resume-conversation-full <名字>" or asks to read a conversation's full detail. Not for creating summaries or moving files.
---

# Resume Conversation (Full)

继承既有对话的**完整细节**。用法：`/resume-conversation-full <对话名>`。只读、不搬移。

## 何时用

- 用户输入 `/resume-conversation-full 3D管线` 这类斜杠指令。
- 需要对话的**精确细节**（具体排障步骤、代码片段、中间讨论），不能只靠摘要。

## 何时不用

- 只要主干/结论 → 用 `resume-conversation-brief`。
- 要搬移/复制项目文件 → 本 skill 不做，直接拒绝。

## 定位对话（会话源遍历，框架无关）

1. 读 `references/conversation-sources.md`（会话源注册表），按里面的优先级**从上到下遍历**每个会话源。
2. 对每个源，用该源声明的「定位」方法尝试定位「对话名」。
3. 命中 → 用该源声明的「读取全文」方法读。
4. 全部源都未命中 → 报告「未找到对话『X』」，列出各源返回的可用清单，不猜测。

**本正文不写死任何框架的会话机制**：`session_query`、`.zstd` 解压、迁移目录路径等，都在注册表里。换框架/换机器 = 改注册表，本正文不动。

## 读取全文

按命中源在注册表里声明的「读取全文」方法读（大文件分段读完，不静默丢内容）。

读完后向用户输出：来源类型（源名）、路径、总规模、已完整读取的确认。

## 铁律

- **只读、不搬移**：绝不复制、移动、修改任何项目文件或 .md。
- **不静默丢内容**：大文件必须读完，读不完要明说「读到 X 处，还有 Y 未读」。
- **引用来源**：转述对话内容时，标注出自哪个来源（「据 <文件名>」或「据会话 <session-id>」）。
- **遍历所有会话源**：按注册表优先级逐个试，不在第一个源就放弃。
