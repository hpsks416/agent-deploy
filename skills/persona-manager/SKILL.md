---
name: persona-manager
description: 管理用户画像 persona.md 的一键操作——清空（备份后重置为空白六维模板）或导入（从来源文件导入，备份旧的 + 校验六维）。Use when the user says "清空画像/重置画像" or "导入画像/恢复画像". Not for accumulating persona from a conversation (that's the metacognition 铁律二's job).
---

# Persona Manager

管理 `~/.dsh/persona.md` 的一键清空 / 导入。实际文件操作由 `scripts/` 下的脚本执行，本 skill 只负责触发 + 确认。

## 何时用

- 用户说「清空画像 / 重置画像」——画像积累跑偏想重来，或换人用机器做隐私清理。
- 用户说「导入画像 / 恢复画像 <文件路径>」——换机器迁移、备份恢复。

## 何时不用

- 从会话中「积累」画像（那是铁律二的收尾提取，不是本 skill）。
- 单条画像的增删改（直接 edit persona.md 即可）。

## 工作流

### 清空画像

1. 向用户确认（选项弹窗）：「清空将备份当前画像并重置为空白六维模板，继续？」
2. 同意后运行 `python "<skill-dir>\scripts\persona_clear.py"`。
3. 报告：备份路径 + 已重置。

### 导入画像

1. 拿到来源文件路径（用户给；拿不到就先 `read` 让用户确认内容）。
2. 运行 `python "<skill-dir>\scripts\persona_import.py" "<来源文件>"`。
3. 报告：备份路径 + 已导入 + 若缺维度则警告。

## 铁律

- **先确认后执行**：清空 / 导入都先弹窗确认，不擅自覆盖画像。
- **必备份**：两个操作都先备份旧 persona.md（脚本已内置），绝不裸删。
- **脚本只碰 persona.md**：不碰其他任何文件。
