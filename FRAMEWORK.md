# AGENT 框架总览

> 一个「文件原生」的自我演进 agent 框架——把「元认知」外置到工作区文件里（Markdown + 脚本 + 铁律），让 agent 能自我评估、自我优化、记住用户、跨框架迁移，且全程人可读、可 diff、可 git、可审计。

---

## 一、分层架构（8 层）

| 层 | 载体 | 职责 |
|----|------|------|
| ① 铁律层 | `AGENTS.md` | 三条常驻触发：优先检索轮子 + 元认知反射 + 画像积累 |
| ② 画像层 | `persona.md` + `persona-manager` | 记「用户是谁、怎么想」（六维），一键清空/导入 |
| ③ 元认知链 | 3 个 skill | skill 的生老病死：建 → 测 → 优 → 门控 |
| ④ 编排层 | `agent-workflow-orchestration` | 复杂任务分解 / 并行 / 收敛 |
| ⑤ 检索层 | `open-source-scout` | 铁律一的支柱（找现成轮子） |
| ⑥ 安全发布层 | 4 个 skill | 打包 → 安检 → 推送，硬门控 |
| ⑦ 对话继承层 | 3 个 skill | 可插拔会话源，续接历史对话 |
| ⑧ 部署层 | 本仓库（agent-deploy） | 换框架/中间商/模型一键铺 |

---

## 二、核心 skill（15 个，跨框架迁移）

| 层 | skill | 一句话 |
|----|-------|--------|
| 画像 | `persona-manager` | 画像一键清空/导入 |
| 元认知 | `skill-lifecycle-manager` | 判断「要不要做成 skill」+ 建/分层/脚本化 |
| 元认知 | `skill-evaluator` | 测量 skill 是否有效（静态+A/B+lift） |
| 元认知 | `skill-optimizer` | 自动优化 skill（rollout→reflect→edit→gate 防过拟合） |
| 编排 | `agent-workflow-orchestration` | 元工作流：拆解/并行/验证/收敛 |
| 检索 | `open-source-scout` | 找现成开源项目 + 对比 |
| 安全 | `secret-scan` | 扫描密钥泄露（只读、脱敏报告） |
| 安全 | `secure-push-workflow` | 编排「打包→安检→推送」+ 硬门控 |
| 安全 | `github-ready-packager` | 整理成 GitHub 项目（写 README 等） |
| 安全 | `acp-studio` | git 提交/推送/双向同步 |
| 对话 | `resume-conversation-full` | 续接对话完整细节 |
| 对话 | `resume-conversation-brief` | 续接对话主干快照 |
| 对话 | `migrate-conversation-prompt` | 生成迁移/续聊提示词 |
| 决策 | `agents-md-skill-layering` | 规则放 AGENTS.md 还是 skill |
| 决策 | `long-sentence-structurizer` | 冗长需求改写成结构化提示词 |

## 三、非核心 skill（8 个，专业领域/个人，不参与框架迁移）

`web-3d-asset-pipeline`(3D) · `rust-refactor-local-projects`(重构) · `browser-viz-local-scripts`(可视化) · `homophone-pun-analysis`(谐音梗) · `hpsks416`(个人透镜) · `windows-node-spawn-cli`(DSH/Windows) · `dsh-plugin-lazy-adapter-resolution`(DSH 插件) · `hatch-pet`(已退役，本地保留)

---

## 四、关键文件（3 个）

| 文件 | 内容 |
|------|------|
| `~/.dsh/AGENTS.md` | 两条铁律 + 画像积累 |
| `~/.dsh/persona.md` | 用户六维画像：人格/思维习惯/决策偏好/纠错模式/语言风格/环境约定 |
| `~/.dsh/settings.yaml` | LLM provider + 默认模型配置 |

---

## 五、元认知闭环（自我演进怎么转）

```
铁律一（检索轮子）→ 动手前先看世界
        ↓
做事（用 15 个核心 skill）
        ↓
铁律二（收尾反思）→ 命中就申请：要不要固化 skill？要不要提炼画像？
        ↓
skill-lifecycle-manager → 建 / 分层 / 脚本化
        ↓
skill-evaluator → 测量（只报数据，不给裁决）
        ↓
skill-optimizer → 优化（gate 防过拟合，产出 _draft）
        ↓
人类终审 → 永远是裁决者
```

---

## 六、仓库结构

```
agent-deploy/                    ← 本仓库（框架总仓库）
├── FRAMEWORK.md                 ← 本文件（框架地图，总领全文）
├── README.md                    ← 仓库入口
├── deploy.ps1                   ← 跨框架部署器
├── providers.json               ← 中间商 + 模型目录
├── core-skills.txt              ← 15 个核心 skill 清单（含耦合等级）
├── templates/agents-core.md     ← 框架无关的两条铁律模板
├── FRAMEWORK-COUPLING.md        ← 框架耦合清单
└── dsh-config/                  ← DSH 本机架构（合并进来的子仓库）
    ├── AGENTS.md
    ├── settings.yaml
    ├── install.ps1              ← DSH 本机一键恢复
    ├── profile-web/
    └── dsh-skill-studio-patched/
```

---

## 七、云端状态

- **22 个 skill 仓库** + `agent-deploy`（本仓库），全部双推 GitHub + Gitee、MIT 开源、Gitee 公开
- `dsh-config` 已合并进本仓库的 `dsh-config/` 子目录
- 隐私文件（`persona.md`、`secrets.cmd`、`.credentials.yaml`）不进公开仓库

---

## 附：这一路建了什么（时间线）

22 个 skill 生态 → 三条铁律 + 画像 → 元认知链（评估/优化）→ 跨框架部署器 → 会话源可插拔 → persona 画像 + 管理 → 全套 README 开源化 → dsh-config 并入总仓库。

**核心一句话**：用 DSH 给模型装了一双「元认知的眼睛」，并把这只眼睛做成了能跨框架带走、能自我迭代、能记住你的文件系统。
