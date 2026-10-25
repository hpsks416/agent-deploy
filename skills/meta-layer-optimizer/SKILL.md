---
name: meta-layer-optimizer
description: Optimize the meta layer (铁律 in AGENTS.md + persona.md) through an evaluate→reflect→edit→gate loop, using the violation/drift log (~/.dsh/meta-drift-log.md) as the score signal and a held-out gate set plus human final review to prevent overfitting. Use when the agent repeatedly violates its own iron laws, drifts from its persona, or the user asks to improve the framework's behavior rules. Not for editing skills or one-off rule tweaks.
---

# Meta-Layer Optimizer（自我改进四环）

对称 `skill-optimizer`（能力层四环），把 evaluate→reflect→edit→gate 从「skill 文档」抬升到「规则资产」——**铁律（AGENTS.md）+ 画像（persona.md）**。核心：铁律层和能力层是同一个「认知资产自我改进四环」抽象的两个实例，唯一区别在 evaluate 信号源——能力层看任务 A/B 表现，铁律层看**违规率 / 偏离率 / 画像一致性**（来自 `~/.dsh/meta-drift-log.md`）。


## 何时用

- 铁律二「行为自检」反复命中同类违规（`meta-drift-log.md` 里某类型「第N次 ≥ 2」= 偏离 = 该规则失效）。
- 用户问「这套铁律/画像是不是该改了 / 有没有过时 / 怎么老犯同类错」。
- 画像「预测偏差」反复出现：预测用户决策屡屡偏差，画像没建模到位。

## 何时不用

- 改 skill 正文（那是 skill-optimizer）。
- 单次规则小改（直接 edit AGENTS.md/persona.md 即可）。
- `meta-drift-log.md` 不存在或空（没有 evaluate 信号，四环无从跑，先按铁律二积累数据）。

## 铁律（违反即失效）

1. **只产出草案，绝不覆盖原文件**：所有 edit 产出 `AGENTS_v2_draft.md` / `persona_v2_draft.md`，用户终审通过才替换。优化器自己不落地。
2. **隔离编辑者**：reflect 和 edit 用独立 subagent，编辑者不能是「写过这条铁律/画像」的同一上下文。
3. **evaluate 只认可判定信号**：违规率/偏离率来自 `eval_drift.py` 解析日志的计数，不来自「我觉得最近表现还行」这类自我评价。
4. **防假改进：gate 集与 rollout 集分离**：日志里的违规案例拆成 rollout 集（归因用）和 gate 集（验证用）。gate 集只在验证时用，绝不参与 reflect/edit。
5. **有界迭代 + 原则性回退**：最多 2 轮；未收敛就停下上报，人是更强判断力，不硬撑不假装成功。
6. **文本学习率**：每轮最多改 3 处（add/delete/replace 各算一处）。
7. **防表面反思**：改铁律/画像必须产生可判定行为差异——纯改措辞、加「以上内容可能存在局限」式免责声明不算改进。判据：改的是「不变式（目标/关系/约束）」还是「表面轨迹复述」。
8. **不可写面**：8 类违规枚举的定义、gate 集、人类已否决条目由**人类固定**，optimizer 只能改铁律/画像正文、绝不能改这些——否则「放宽成功标准」和「真变强」得分相同，从闭环内无法察觉。可信度由「optimizer 不可写的验证面」度量。
9. **防捷径（Reward Hacking）**：不能靠「把违规类型从枚举里删掉」「把日志清空」来让违规率假降。edit 前自检「这是真改进还是钻了统计空子」。

## 工作流

### 阶段 0 — 准备

- 读 `~/.dsh/meta-drift-log.md`、`~/.dsh/AGENTS.md`、`~/.dsh/persona.md` 三份原文。
- 若日志不存在或 0 条记录 → 停下：「无 evaluate 信号，四环无从跑」，建议先按铁律二积累违规数据。
- 拆分违规案例：取一半（至少 1 条）作 gate 集，其余作 rollout 集，全程不变。

### 阶段 1 — Evaluate（测量基线）

跑 `python scripts/eval_drift.py --json`，产出：
- `total` 总违规数、`by_type` 各类型计数（违规率）。
- `drift_types`（第N次 ≥ 2 的类型 = 偏离 = 规则失效候选）。
- `unknown_types`（日志里出现但不在 8 类枚举里的类型 = 枚举或记录有误，先修日志不归因）。

基线 = 当前违规率/偏离类型清单。**先取证再归因**：区分「环境变了（外部依赖/路径变了）」vs「铁律本身缺陷」——环境变了不改铁律。

### 阶段 2 — Reflect（失败归因，隔离 subagent）

派独立 subagent，输入：当前铁律/画像正文 + rollout 集里**违规案例**（类型/场景/违反条款）。

要求输出：每个偏离类型暴露了哪条铁律/画像「失效 / 过时 / 缺失 / 含糊」。**只看违规，不改没违规的条款**（没违规的条款是「不能动的资产」）。

画像归因用 PERMA 视角：判断画像条目是否「跨时间/跨场景仍一致、还是已过时」，不只看「是否记录了某条」。

### 阶段 3 — Edit（小步修改，隔离 subagent）

派另一个独立 subagent，输入：当前正文 + reflect 归因。产出 `_draft`，约束：
- 最多改 3 处（add/delete/replace）。
- 只针对违规暴露的问题，不重构没违规的部分。
- **可编辑面声明**：编辑前声明「能改什么、不能改什么」——可改：铁律/画像正文；不可改：8 类枚举定义、gate 集、人类已否决条目。
- 画像 edit 遵守 persona 追加规则：去重 / 更新 / 不臆造 / 记规律不记孤立行为。

### 阶段 4 — Gate（留出验证，防假改进）

分两层，**结构门（确定性）+ 行为门（LLM 判定）**：

- **结构门（脚本可判定，先跑）**：`_draft` 不得触碰不可写面（枚举/gate 集/已否决条目）、改动 ≤3 处、未新增违规类型。
- **行为门（LLM 判定）**：用 gate 集违规案例「重放」——把 `_draft` 铁律/画像代入，判定「若当时用新版，这条违规是否会被避免」，且「不会引入新的违规类型」。
- **诚实局限（必须向用户声明）**：铁律层没有能力层那种「跑 evals 出 pass/fail」的确定性执行面——行为门是 LLM 判定，**比 skill 层的 gate 弱**。因此铁律层的最终 gate 是**用户终审**，不是脚本。这是铁律层自我改进天生的不对称，不掩盖。
- 通过 → 报告 `_draft` + 前后对比，请用户终审。不通过 → 报告「被 gate 拒绝」，不覆盖、不声称成功。

### 阶段 5 — 用户终审

- 只报告 `_draft` 路径 + 违规率前后对比（事实），不替用户决定。
- 用户同意后，才把 `_draft` 替换为正式 AGENTS.md/persona.md（并同步 `agent-deploy/dsh-config/` 副本）。
- **重标定自我认知**：铁律/画像被改后，其边界已变，需同步检查「触发描述、行为自检四模式」是否仍一致。

## 边界

- 不创建新 skill、不删铁律、不自动覆盖、不清空日志。
- **版本谱系管理**：每次迭代保留 `_draft` 历史（版本号 + 谁淘汰谁 + 选择依据），可回溯。
- 违规案例 < 2 条时无法做 gate 拆分，退化为「只有结构门 + 用户终审」，如实告知防假改进检查不可用。
- 2 轮未收敛就停，不陪它无限递归。

## References

- `scripts/eval_drift.py` — 解析 `~/.dsh/meta-drift-log.md` 计数（read-only，stdlib）。
- `references/meta-evals-schema.md` — 违规/偏离日志的 schema 与 8 类枚举规范（框架规则版 evals）。
- 能力层对应物：`skill-optimizer`（四环范式）、`skill-evaluator`（判定脚本复用思路）。
