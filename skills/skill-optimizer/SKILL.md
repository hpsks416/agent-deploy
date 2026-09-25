---
name: skill-optimizer
description: Optimize an existing skill's SKILL.md through a rollout→reflect→edit→gate loop, using the skill's own evals as the score signal and a held-out gate set to prevent overfitting. Use when a skill scored as dead weight or negative by skill-evaluator, or when the user asks to improve, tune, or auto-fix a skill. Not for creating new skills or one-off edits.
---

# Skill Optimizer

轻量版 SkillOpt：把「skill 文档当可训练参数」，用 rollout→reflect→edit→gate 四步循环自动改进一个 skill 的正文。核心是**用验证门控防过拟合**——只有能通过留出验证集的改进才被接受。产出永远是 `_draft`，人类终审。

**理论底座**：前馈 Transformer 无法内化「对思考的思考」（元认知）——它只能模仿反思的文本，不能真正执行反思。所以元认知必须外置：本 skill 是「外部元认知引擎」的**优化回路**（rollout→reflect→edit→gate 即评估→反馈→迭代→门控），对标业界共识的外部 Critic/Reviser 循环，不是权宜之计。

## 何时用

- 一个 skill 被 `skill-evaluator` 判为 dead weight 或 negative（有 lift 数据）。
- 用户问「把这个 skill 改好 / 优化 / 调优」。
- 一个 skill 在真实使用中报错、漏判、误判，需要迭代修正。

## 何时不用

- 创建新 skill（那是 skill-lifecycle-manager 的职责）。
- 单次小改（直接 edit 即可）。
- 目标 skill 没有 evals.yaml（没有可判定的成功标准，优化无从谈起）。

## 铁律（违反即失效）

1. **只产出草案，绝不覆盖原文件**：所有 edit 产出 `SKILL_v2_draft.md`（或 `_draft`），人类审查通过才替换。优化器自己不落地。
2. **隔离编辑者**：reflect 和 edit 必须用独立 subagent 执行——编辑者不能是写这个 skill 的同一个上下文，创作者给自己放水是系统性偏差。
3. **防过拟合：gate 集与 rollout 集分离**：evals 的用例拆成 rollout 集（训练信号）和 gate 集（留出验证）。gate 集只在最后验证时用，绝不参与 reflect/edit 的分析。改进必须让 gate 集严格变好，才防「只对训练用例有效的假改进」。
4. **有界迭代 + 原则性回退**：rollout→reflect→edit→gate 最多跑 2 轮。超过则停下，把「优化未收敛」上报人类终审——人是更强的判断力（SOFAI-LM 的 Principled Fallback），不降标准、不硬撑、不假装成功。
5. **文本学习率**：每轮 edit 最多改 3 处（add/delete/replace 各算一处）。小步修改保证稳定，防止一次大改引入新问题。
6. **防表面反思**：edit 必须产生可判定的行为差异——gate 集通过率或 lift 必须真实变化。纯改措辞、加「以上内容可能存在局限」式免责声明、改标点都不算改进（「礼貌性免责声明」陷阱：文本在反思但行为没变）。

## 工作流

### 阶段 0 — 准备

- 用 `skillmgr_get <name>` 读目标 skill 全文 + 其 evals.yaml。
- 若没有 evals.yaml，停下并说明「无成功标准，无法优化」。
- 拆分 evals 用例：取一半（至少 1 个）作 gate 集，其余作 rollout 集。记录这个拆分，全程不变。
  - 例：3 个用例 → rollout 2 个 + gate 1 个。

### 阶段 1 — Rollout（测量基线）

用独立 subagent 跑 rollout 集的每个用例（注入当前 skill 正文），对输出跑 checks，记录 pass/fail。

判定脚本复用 `skill-evaluator` 的 judge：先 `skillmgr_get skill-evaluator` 拿它的 base 目录，再运行其 `scripts/` 下的 judge 脚本（含 lift 量化），本层不复制该脚本。

基线 = rollout 集通过率。

### 阶段 2 — Reflect（失败归因）

派一个独立 subagent，输入：
- 当前 skill 正文
- rollout 集里**失败用例**的 task + 输出 + 哪个 check 没过

要求它输出：失败用例暴露了 skill 的哪条规则缺失/错误/含糊。**只看失败，不改成功通过的用例逻辑**（成功用例的规则是「不能动的资产」）。

### 阶段 3 — Edit（小步修改）

派另一个独立 subagent（或同一隔离 subagent），输入：
- 当前 skill 正文
- reflect 的失败归因

要求它产出 `_draft` 正文，约束：
- 最多改 3 处（add/delete/replace）。
- 只针对失败用例暴露的问题，不重构成功路径。
- 保持 frontmatter 的 name 不变。

### 阶段 4 — Gate（留出验证，防过拟合）

- 用独立 subagent 跑 **gate 集**用例（注入 `_draft` 正文），判定 pass/fail。
- **严格优于基线**：gate 集通过率 > 原版在 gate 集的通过率，且 rollout 集不能退化。
- 通过 → 报告 `_draft` 与前后对比数据，请用户终审。
- 不通过 → 报告「优化被 gate 拒绝」，不声称成功，不覆盖。

### 阶段 5 — 人类终审

- 只报告 `_draft` 路径 + gate 前后对比数据（事实），不替用户决定是否替换。
- 用户同意后，才把 `_draft` 替换为正式 SKILL.md。

## 边界

- 优化器不创建新 skill、不删 skill、不自动覆盖。
- 没有 evals 或 evals 用例 < 2 时，无法做 gate 拆分，退化说明「防过拟合门控不可用」，如实告知。
- 2 轮未收敛就停，不陪它无限递归。

## References

- 判定脚本：复用 `skill-evaluator` 的 judge 脚本（含 lift 量化），经 `skillmgr_get skill-evaluator` 解析 base 目录。
- `evals.yaml`：本 skill 的验收测试。
