---
name: resume-conversation-brief
description: 在对话中用 `/resume-conversation-brief <对话名>` 继承既有对话的主干——遍历可插拔的会话源（conversation-sources 注册表）定位对话，分段 map-reduce 精炼成可追溯快照（每结论引用来源），不搬移文件。Use when the user types "/resume-conversation-brief <名字>" or asks for a conversation's distilled gist. Not for full-detail reading or moving files.
---

# Resume Conversation (Brief)

继承既有对话的**主干**。用法：`/resume-conversation-brief <对话名>`。只读、不搬移。

## 何时用

- 用户输入 `/resume-conversation-brief 3D管线` 这类斜杠指令。
- 只要**主干**（结论、进展、决策、待办），不读全部细节。

## 何时不用

- 要精确细节 → 用 `resume-conversation-full`。
- 要搬移/复制项目文件 → 本 skill 不做，直接拒绝。

## 定位对话（会话源遍历，框架无关）

1. 读 `references/conversation-sources.md`（会话源注册表），按里面的优先级**从上到下遍历**每个会话源。
2. 对每个源，用该源声明的「定位」方法尝试定位「对话名」。
3. 命中 → 用该源声明的「读取主干」方法读。
4. 全部源都未命中 → 报告「未找到对话『X』」，列出各源返回的可用清单，不猜测。

**本正文不写死任何框架的会话机制**：`session_query`、`.zstd` 解压、迁移目录路径等，都在注册表里。换框架/换机器 = 改注册表，本正文不动。

## 精炼快照（map-reduce，每结论引用来源）

按命中源在注册表里声明的「读取主干」方法读（分段精炼，不静默丢内容）。

快照固定结构，且**每一条结论标注来源**（哪个文件或哪个 session-id）：

```markdown
# 对话快照：<对话名>

- 来源：<文件路径 / session-id>

## 这是什么
（一句话：对话在做什么/解决什么）

## 当前进展
- <结论1>（据 <文件名>）
- <结论2>（据 <文件名>）

## 关键决策
- <决策 + 为什么>（据 <文件名>）

## 待办 / 未解决
- <待办1>
- <待办2>

## 环境/约束
- <关键环境、路径、凭据约定>
```

## 铁律

- **只读、不搬移**：绝不复制、移动、修改任何文件。
- **每结论可追溯**：快照里的每一条结论/决策/待办，标注出自哪个 .md 或哪个 session-id。
- **不静默丢内容**：大文件分段读完再合并，读不完明说。
- **快照是摘要，不是原文**：明确告诉用户「这是主干，需要细节请用 resume-conversation-full」。
- **遍历所有会话源**：按注册表优先级逐个试，不在第一个源就放弃。
