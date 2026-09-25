---
name: agent-workflow-orchestration
description: Use when the task is a meta-workflow — decomposing a complex request, delegating to subagents or fanning out across many units, running a long multi-round goal, or managing skills — and the agent must decide how to split, parallelize, verify, and converge its own work. Not for single-step or single-file edits.
---

# Agent Workflow Orchestration

一套 agent 编排自身工作的元工作流：把复杂请求拆解、并行、验证、收敛，并管理长任务与技能。分两层——**通用工作法**（跨工具成立的方法论内核，主体）与 **DSH 工具落地层**（四维度可操作用法）。

## 何时用

- 请求含多个独立子任务、可并行或需扇出的工作。
- 任务要跨多轮、多会话推进，需要长目标与进度管理。
- 需要决定「何时派子代理、何时用 workflow、何时建 goal、如何管理 skill」这类元决策。
- 不用于：单步任务、单文件编辑、一次性问答。

## 通用工作法（主体）

### 1. 需求消歧与决策收敛

模糊需求先查证名词身份，不臆测。
- 用「现状 / 不确定 / 需要你给」三段式汇报，把已知、未知、缺什么分开。
- 开放问题收敛成「二选一 / 三选一」有限选项，让用户低成本作答。
- 复述理解请用户确认「没跑偏」；硬阻塞项单独点名追问。
- 给结论时先一句话结论，再拆正交维度给组合表/对比矩阵，收口成可执行建议 + 低成本验证路径。

### 2. 最小实证取代盲从/臆测

外部结论、上个对话结论、文档声称影响方向时，不盲信。
- 设计最小代价探针（1 token 补全、单次 API 请求、最小输入→输出样例）只验证争议点。
- 用探针返回的真实状态码/结果作唯一裁决，不基于推测。
- 歧义规则用最小具体样例锁定语义；边界异常（奇数配对、越界）先指出并请求确认，不擅自补全。

### 3. 接口/产物先验身

先验证外部契约再编码；下载产物先验身再使用。
- 下载前读文件头魔数（如 MZ=4d5a）判型；下载后比对 SHA-256 与官方发布值。
- npm/包先确认官方名与版本存在再安装；外部接口先确认契约再动手搭骨架。

### 4. 骨架先行 + 夹具解耦

整体结构清楚但部分输入未到位时，不空转等待。
- 先搭可落地骨架，内容留占位符，再回填。
- 先跑通最小端到端管线（MVP）；上游真实输入缺位时用 sample 夹具解耦阻塞。
- 更大粒度上重复同一节奏：最小管线跑通后再逐个增量叠加。

### 5. 改动即时验证 + 中间产物可观测

改配置/文件/多步流水线时，每步可判定。
- 改前时间戳备份；只做最小必要改动（能追加不重写）。
- 锚点断言防静默失败（改动后复读、编译、运行时冒烟）。
- 每步埋可判定检查点并打印；长步骤加增量进度，区分「卡住」与「在跑」。
- 主动声明「跳过哪些回归及原因」，不做无声省略。

### 6. 根因分层定位，不盲重试

症状与根因不在同一层时，先定位再修。
- 先定失败发生在哪一层（网络→TLS→依赖→进程→GUI）。
- 用最小可复现命令隔离单变量；报错先归类（用户操作/环境/代码缺陷/进程未重启），代码缺陷主动认领。
- 定位到具体根因后才开修；修复后用同一探针复验。

### 7. 降级兜底链，失败即停

关键动作有多条等价路径时，按序降级。
- 默认走最常规路径；失败读输出定位类别。
- 按「成本从低到高、侵入性从小到大」逐级降级；每级失败显示原始输出并停，不盲目重试。
- 多实现链路（如双服务）必须对称维护：写进约束清单，每处改动各链路单独验证。

### 8. 凭据全程脱敏不落盘

涉及 token / key / auth.json / .env 时。
- 统一脱敏函数（正则保留前缀打 `***`），套用到所有可能含密钥的输出；只报「长度/value hidden」，不打印明文。
- 配置用引用（如 `apiKeyEnv`）而非明文；密钥走凭据缝。
- 内联凭据用完立即在捕获输出里替换为 `***`。

### 9. 任务上下文交接块

会话超长、跨会话/跨模型续作时，把认知状态整体打包。
- 固定结构：项目根 + 流程一句话 + 「最新请求（尚未实现）」+「已完成并已验证」+ 关键环境约束 + 代码导航线索 + 用户偏好。
- 「最新请求」与「已完成」严格分开，避免把已交付的当待办重做。
- 导航线索直指具体文件，并诚实标注「尚未细读、必须完整读一遍」。
- 记录用户可执行的验收动作（刷新哪个地址、点哪个按钮、预期行为）。

注：跨会话延续优先用 DSH 原生 resume（含换模型）或 `dsh-session-ref` 引用，交接块是「会话内压缩/交接」的产物，不额外落快照文件。

### 10. 交付物结构化校验

交付多文件产物（代码 + 配置 + 前端资源）时，验证「完整且自洽」而非「文件都在」。
- 静态：语法检查 / 编译通过。
- 动态：最小 HTTP 烟测或真实功能测试（临时仓库跑真实链路），避免直接跑 main 触发副作用。
- 跨文件一致性：如 JS 引用的元素 ID 是否都存在于 HTML。
- 打包内容干净：无运行时产物 / 密钥 / state 残留。

### 11. 权限边界分离

产物需落到受限目录时。
- 先在可写区完成构建与校验，最后一步才对受限目录单独申请权限，并把 reason 写清。
- 权限只申请最小范围（仅目标目录写），不扩权。

### 12. 能力边界显式化

任务有自动化与人工两可部分时，明确划界。
- 自动化可自动化的部分；人工部分给精确步骤（装什么、点哪里），不模糊划界。

### 13. 经验沉淀为 SKILL + 前向实测

稳定工作流/踩过的坑，沉淀为可复用 skill。
- 提炼触发场景 + 确定性工作流 + 类型/映射表。
- 隐性排障经验写进 references（而非塞进主流程）；内嵌安全边界（何时不 push、不提交密钥、失败即停）。
- 校验产物结构完整（name 与目录一致、无 TODO、描述一致），并用真实任务验证产出质量（不只校验格式）。

## DSH 工具落地层

### 多智能体编排

工具：`subagent`、`subagent_fork`、`list_agents`、`send_message`、`interrupt_agent`、`session_call`、`session_query`、`board_*`

- **独立任务用 `subagent`**：自包含、不依赖本对话上下文的任务，给完整 standalone prompt。
- **延续上下文用 `subagent_fork`**：继承本对话已完成轮次，做后续分析/审查/续作，不消耗本对话上下文。
- **后台并行为默认**：`run_in_background: true` 是默认；多个独立子代理在同一消息里一起启动。只有「下一步依赖结果」时才设 false。
- **不轮询**：子代理完成会收到通知，不 busy-poll/sleep；后台 job 用 `job_output` 收结果。
- **收敛点**：真正需要全部结果汇合时才用 barrier（workflow `parallel` / `job_output wait:true`）；否则边等边做独立步骤。
- **Agent Card（能力声明，借鉴 A2A）**：派子代理前，先在其 prompt 里显式声明「它能做什么、要什么输入、只产出什么、不做什么」——像一张能力卡片。这比只给任务描述更可靠，避免子代理越权或产出失控。
- **不透明性铁律（借鉴 A2A）**：子代理协作时，只回传**结构化结果**（结论 + 数据），不暴露内部推理链、中间日志、原始工具输出。内部状态是子代理自己的，协作方只需要「答案」，不需要「过程」。这既省 token，也防中间过程泄露（如明文密钥）。

### 目标与长任务驱动（goal）

工具：`create_goal`、`get_goal`、`update_goal`（edit/pause/resume/complete/blocked）

- 长目标才建 goal；单轮任务不建。
- 每次 update 前先 `get_goal` 拿准确 goal_id + revision（并发/恢复后 revision 会变）。
- `blocked` 只在「同一阻塞条件连续 ≥3 轮」才标记，且必须写具体 blocked_reason；困难/不确定/还有活干 ≠ blocked。
- `resume` 用于会话恢复/fork 后重新武装（goal 在 resume/fork 后会 disarm）。

### 工作流脚本扇出（workflow）

工具：`workflow`（script 内 hook：`agent()` / `pipeline()` / `parallel()` / `phase()` / `log()` / `args`）

- 多独立单元的大规模编排（审计多文件、迁移、多角度调研、对抗性验证）用 workflow，而非逐轮派发。
- `pipeline(items, ...stages)`：无 barrier 逐项流式推进，首选。
- `parallel(thunks)`：有 barrier，仅在「某阶段真需要所有先前结果一起」时用。
- hook 误用（坏参数/未知选项/越界）会抛错杀死整个脚本，不会降级为 per-item null。
- script 是纯 JS body（非 TS、无 `export const meta`），`meta` 走参数。
- `agent()` 可用 `opts.schema`（JSON Schema 仅 type/properties/required/additionalProperties/items/enum/const/oneOf）拿到结构化结果。

### 技能元管理（skillmgr）

工具：`skillmgr_list/get/save/policy`、`skillmgr_extract_*`

- 任务命中某 skill 描述时，先 `skill` 加载全文，不要只看摘要就照做。
- 编辑 skill 用 `skillmgr_save`（frontmatter + 正文一起写回），只对文件系统来源可用；frontmatter name 必须与 skill 名一致。
- 开关用 `skillmgr_policy`（enabled / modelInvocable / userInvocable）。
- 会话提取：`extract_run` 扫日志产出候选 → `extract_list` 查看 → `extract_accept/reject` 决定；需先 `extract_config` 配 LLM。

## 横向支撑

- `todo_write`：多步工作先建清单，每步 in_progress 不空置，完成后立即标记。
- `present`：产出交付物文件后调用，比在回复里提路径更正式。
- 后台 job 用 `job_list`/`job_output`/`job_kill` 管理。
- 跨会话共享状态用 board（`board_post`/`board_list`）；定向通知用 `session_call`。

## 边界

- 不用于单步任务、单文件编辑、一次性问答——那些直接做即可。
- 通用工作法按需取用，不必每条都套；过度流程化会拖慢简单任务。
- 编排决策以「是否真正并行/是否跨轮/是否大规模扇出」为准，不为流程而流程。
