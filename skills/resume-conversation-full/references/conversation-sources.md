# 会话源注册表（可插拔接口）

本文件是「对话继承」能力的**会话源接口**：`resume-conversation-full` / `resume-conversation-brief` 的 SKILL.md 只负责「遍历源 → 定位 → 读取」，每个会话源**怎么定位、怎么读**全在本文件。

**换框架 / 换机器 = 只改本文件，SKILL.md 正文不动。**

## 会话源契约

一个「会话源」必须能回答两件事：

1. **定位（locate）**：给定「对话名」→ 返回命中位置（文件路径 / session-id）。
2. **读取（read）**：给定命中位置 → 返回内容（全文 / 主干 outline）。

## 已知会话源（按优先级从上到下）

### 源 1：`codex-md` —— Codex 迁移的 .md 文件

- **适用**：对话是从 Codex 迁移来的 `.md`（在迁移目录里）。
- **定位**（两步，都在迁移目录内）：
  1. 用 `pwsh Get-ChildItem -Recurse` 在迁移目录找 `conversations\*.md`，文件名去 `.md` 后缀后**前缀匹配**对话名（如「3D管线」→ `3D管线.md`）。
     - ⚠️ 别用 `glob`：Windows 绝对路径 + 反斜杠 + `**` 会静默返回空，改用 `pwsh Get-ChildItem -Recurse`。
  2. 若文件名无语义名（形如 `2026-09-13--<sessionid>.md`），读索引文件，用「标题」列把对话名映射到 session-id 文件。
- **读取全文**：`.md` ≤ 约 40k 字符 → 直接全文读入；> 40k → 用 `read` 的 offset/limit 分段读完，不静默丢中间。
- **读取主干**：分段读 + 逐段提炼「段摘要」，最后合并（map-reduce）。
- **路径配置**（换机器改这里）：
  - 迁移目录：`G:\CodexDS\DSH\MAIN`
  - 索引文件：`G:\CodexDS\DSH\MAIN\_migrated_codex\conversations\index.md`

### 源 2：`dsh-native` —— DSH 原生会话

- **适用**：对话是 DSH 原生会话（不是 `.md`，是 `.zstd` 日志 + projcache 投影）。
- **定位**：用 `session_query`（query=对话名）查 DSH 原生会话注册表，命中得 session-id。
- **读取全文**：优先读 projcache 的 turn outline（已含 prompt/response 摘要）；需要原始全文时，解压 `.zstd` 日志——本机无 zstd 二进制、python 无 zstandard，但 **node v24 内置 `zstdDecompressSync`**，且日志是**多帧追加写**，须逐帧解压（扫帧边界 + 逐帧 decompress），单次解压只出第一帧。
- **读取主干**：读 projcache JSON 的 turn outline 即可，不必解压 `.zstd`。
- **路径配置**（换机器改这里）：
  - projcache：`~/.dsh\storages\session_projcache\sessions\<session-id>.json`
  - zstd 日志：`~/.dsh\sessions\--<workspace>--\<session-id>\session.v3.jsonl.zstd`

## 如何新增一个会话源（换框架时）

在「已知会话源」里追加一节，写清四件事：**适用条件、定位方法、读取全文方法、读取主干方法**。SKILL.md 正文不用改——它会自动遍历本文件所有源。

示例（换到 Codex 原生会话时加）：

> ### 源 3：`codex-native` —— Codex 原生会话
> - **适用**：对话是 Codex 原生会话（非迁移 .md）。
> - **定位**：用 Codex 的会话列表工具，按对话名匹配 session-id。
> - **读取全文**：读 Codex 会话存储的完整 rollout。
> - **读取主干**：读会话的 turn 摘要。
> - **路径配置**：`~/.codex\sessions\...`（按实际填）。
