---
name: secure-push-workflow
description: Orchestrate the full "package → security scan → push" pipeline for a local project, calling github-ready-packager, secret-scan, and acp-studio in order with a hard gate that stops on any security finding. Use when the user asks to publish, ship, or push a local project to GitHub/Gitee end-to-end and wants safety enforced automatically. Not for editing code, single commits, or sync-only requests.
---

# Secure Push Workflow

把「打包 → 安检 → 推送」这条链固化为一个显式的策略编排层。它自己不做任何底层脏活，只做**调度 + 决策 + 门控**：按顺序调用三个底层 skill，并在安检不通过时硬性停住。

## 何时用

- 用户说「把这个项目发布/推送到 GitHub（或 Gitee）」，希望一条链走完。
- 用户想要「推送前强制安检」的保证，而不是手动记得先 scan 再 push。
- 涉及从本地项目到远程仓库的端到端交付。

## 何时不用

- 只想提交/推送一次（无打包、无安检需求）→ 直接用 `acp-studio`。
- 只想检查安全性 → 直接用 `secret-scan`。
- 只想打包成 zip 不发布 → 直接用 `github-ready-packager`。
- 只想做 GitHub↔Gitee 双向同步（无安检）→ 直接用 `acp-studio` 的 sync。

## 铁律（门控，违反即失效）

1. **安检不过，绝不推送**：`secret-scan` 发现任何真实凭据泄露（非 false positive），必须停下，报告脱敏后的发现，并明确「未推送」。绝不带着发现继续 push。
2. **只调度，不重造**：本 skill 不复制三个底层 skill 的脚本或逻辑，只通过它们的既有接口调用。底层脚本的路径、参数、行为以各底层 SKILL.md 为准。
3. **顺序不可乱**：打包 → 安检 → 推送。安检必须在推送之前；打包可跳过（若用户已整理好）。
4. **每步有可判定信号**：打包=zip 产出且校验通过；安检=findings 计数；推送=commit hash 或远端确认。没有信号就停下，不靠「感觉做完了」。

## 工作流

### 阶段 0 — 确认目标与范围

- 确认项目目录、目标平台（github / gitee / both）、是否已整理好（决定是否打包）。
- 若用户没给全，用「现状 / 需要你给」收敛，不臆测路径。

### 阶段 1 — 打包（可跳过）

若项目需要整理成独立发布形态，**调用 `github-ready-packager` 技能**来完成打包（读它的 SKILL.md 并按它的工作流执行）：

- 把「项目目录 + 期望产出 zip 路径」作为输入交给它，它内部用什么脚本、什么参数由它自己决定，本层不关心。
- 校验信号：zip 产出 + 语法/烟测通过（以 github-ready-packager 的 SKILL.md 校验项为准）。
- 若用户已整理好、无需打包，跳过本阶段，直接进安检。

### 阶段 2 — 安检（门控，不可跳过）

**调用 `secret-scan` 技能**，扫描**打包产物目录**（不是原始工作目录的散落文件）：

- 读它的 SKILL.md 并按它的工作流执行本地扫描，本层只关心它的输出信号：`findings` 计数 + 逐条 `!` 发现。
- **决策门**：
  - `findings=0` → 通过，进入阶段 3。
  - 有 `!` 且为真实凭据（非 risky_filename 误报）→ **停**，报告脱敏后的发现，明确「未推送」，结束。
  - 仅 `risky_filename`（文件名可疑但无明文凭据）→ 按 secret-scan 的指引人工确认，确认无害才继续。

### 阶段 3 — 推送

调用 `acp-studio` 完成提交 + 推送：

- 优先走其本地 panel JSON API（`POST /api/commit` + `POST /api/push`），降级走 direct git。
- 只推送到用户指定的平台。
- 产出可判定信号：commit hash / 远端分支确认。把它回传用户。

### 阶段 4 — 汇报（只报事实）

- 打包：zip 路径 + 校验结果。
- 安检：findings 计数 + 门控结果（通过 / 拦截）。
- 推送：commit hash / 平台 / 分支。
- 若在安检被拦截，明确写出「**未推送**」和脱敏后的发现列表。

## 依赖的底层 skill（只调用，不复制）

| 底层 skill | 本层如何调用 | 在本链中的角色 |
|---|---|---|
| `github-ready-packager` | 调用该技能，读其 SKILL.md 执行 | 打包（可跳过）|
| `secret-scan` | 调用该技能，读其 SKILL.md 执行 | 安检门控（不可跳过）|
| `acp-studio` | 调用该技能，读其 SKILL.md 执行 | 提交 + 推送 |

## 边界

- 不处理：代码编辑、冲突解决、强制推送、license 选择（这些留给底层 skill 或用户）。
- 安检只拦截「真实凭据泄露」；risky_filename 误报需人工确认，不擅自放行也不擅自删除。
- 本 skill 不缓存凭据、不回显明文；凭据规则以 `secret-scan` 和 `acp-studio` 为准。

## References

- 底层 skill 的完整契约见各自 SKILL.md：`github-ready-packager`、`secret-scan`、`acp-studio`。
- `evals.yaml`：本编排层的验收测试。
