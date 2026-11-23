---
name: deepseek-export-migration
description: 把 DeepSeek 官网导出的会话（deepseek_data ZIP / export_format_version 3）迁到别处继续用——落进 DSH 原生会话（官方 dsh-deepseek-chat-import 插件）、落进自建 chat-demo 静态站（手机端、数据存手机）、或转 .md 归档；含超长会话的 token 实测、尾部切片 + map-reduce 接续摘要，以及四层离线自检脚本。Use when 用户要把 chat.deepseek.com 的历史对话导出后迁移/备份/搬到手机、或导入时遇到"文件格式错误"/"无法转换"/"超出上下文"要定位。
---

# DeepSeek 导出迁移

## 0. 先做检索（铁律一，别跳）

本流程已经检索过一轮，结论可直接复用，但**换环境或隔了一段时间后要重跑一次**：

| 候选轮子 | 结论 |
|---|---|
| `DeepSeek2md`（Go TUI，MIT） | 输入是旧版 `conversations.json`，**不吃 v3 ZIP**；2026-05 版还要抓 `userToken`（等于交出账号凭据） |
| `ceyaima/deepseek-exporter`（油猴） | 能出 RAW/JSON 树/HTML/MD，保真最高（含重答分支），但要装 Tampermonkey、批量时页面来回跳 |
| `deepseek-json-to-markdown-converter`（PyPI, AGPL） | 同上，只吃 `conversations.json` |
| `@deepseek-ai/dsh-deepseek-chat-import` | **官方实验 bundle**，直接吃 v3 ZIP → 可续聊的原生 DSH 会话 |
| `deepseek-ai/chat-demo` | **官方 MIT 静态前端**，同一套 v3 ZIP 导入/导出，可自托管到手机 |
| `lz-jun/dsh-session-porter`、`double-coding-lab/dsh-session-import` | 搬 DSH 自己的会话 / 其他 agent 工具，不适用官网导出 |

**结论**：官网 ZIP 是唯一被官方两条消费端（DSH 插件、chat-demo）认的格式，别去写转换器。

## 1. 导出与格式

官网 → 设置 → 数据管理 → 导出所有历史对话 → `deepseek_data-<日期>.zip`（解压后可直接当目录用）：

```
manifest.json                 {"export_format_version":3}   ← 必须是第一个条目
chat_sessions/<uuid>.json     一篇会话：id,title,pinned,current_message_id,inserted_at,updated_at,messages
chat_sessions/<uuid>_files/   图片原件（png/jpg/jpeg/webp/gif）
chat_session_index.json       [{id,title,pinned,message_count,inserted_at,updated_at}, …]
```

- `messages`：`{id, parent_id, role(USER|ASSISTANT), status, thinking_enabled, search_enabled, accumulated_token_usage, inserted_at, fragments}`；**id 是递增整数**，`parent_id` 为整数或 null，树按 id 排序。
- `status` 枚举：`WIP | FINISHED | CONTENT_FILTER | FAILED | INCOMPLETE | CONTEXT_LENGTH_EXCEEDED | TIMEOUT`。
- `fragments` 类型：`REQUEST / RESPONSE / TEMPLATE_RESPONSE / THINK / TOOL_SEARCH / TOOL_OPEN / TOOL_FIND / READ_LINK / TOOL_IMAGE_SEARCH / PARTIAL_FILE_READ / TIP / CONTENT_RISK / FILE`。
- 当前分支 = 从 `current_message_id` 沿 `parent_id` 回到根；**其他分支不导入**。

## 2. 三条落地路径（按需求选，别默认选最费劲的）

| 需求 | 路径 | 判据 |
|---|---|---|
| 在 DSH 里接着聊 / 要能搜能导出 | 官方插件 `@deepseek-ai/dsh-deepseek-chat-import`（app.asar 内置，属实验性 bundle，默认关闭 → 插件页「更多 → 实验性插件」打开） | 电脑开机没问题；导入不花模型 token |
| 手机上用、**不依赖电脑开机**、数据存手机 | 官方 `chat-demo`（MIT）托管到静态站 + 手机浏览器加主屏（WebAPK） | 需要一个 https 地址；数据在手机 IndexedDB |
| 只是随时查历史 | 导出 → `.md` 归档 | 不占上下文、不能续聊 |

不符合上述判据的常见误选：DSH Mobile（手机只是遥控，电脑必须开机）、第三方 `dsh-plugin-my-deepseek`（同样存电脑磁盘）、来源不明的"chat-demo 安卓 APK"（无源码不可扫描，别装）。

## 3. 硬约束速查（两次返工都出在这里）

### 3.1 DSH 插件（宽松）

- 只吃 **ZIP**（不吃解压目录）；上限 512 MiB / 单条目 256 MiB / 一次最多 1000 篇（按 `updated_at` 取最新）。
- `exportFormatVersion` 必须 3。
- `messages[].id`、`parent_id` 必须是**数字**（`z.number().int().nonnegative()`）——塞字符串 GUID 会整篇"无法转换"。
- 分支从 `current_message_id` 往父走，**父节点缺失直接抛错**（不是静默截断）。
- 失败会话不写入，对话框只报数量，原因只在 Host 日志里。

### 3.2 chat-demo（严格，四处都会挂）

1. **条目顺序是契约**：`manifest.json → 全部 chat_sessions/<id>.json → chat_session_index.json → 全部图片`。它按物理顺序跑状态机，`index` 若排在会话之前，后面每个会话都会落进 `else` → `fail('backupIncomplete')`，界面只说"文件格式错误或旧版导出"。也支持"会话 JSON 紧接它自己的图片"交错、index 在末尾。
2. **消息 id 必须是数字**，且 **父 id < 子 id**。
3. **角色必须交替**（USER/ASSISTANT 严格交替）、**根必须是提问**（role=USER、parent_id=null）；按**全部消息升序**校验，不只当前分支。
4. **时间严格** `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$`；`status` 必须在上面的枚举里。
5. 导入**整体替换**本地全部会话（不能分批累积）；缺失原件的图片只保留文件名与大小。

**推论**：给 chat-demo 打包时，DSH 能过的包它不一定能过；反之 chat-demo 能过的包 DSH 一定能过（DSH 更宽松）。

## 4. 超长会话：先量再决定，别猜

- 上下文：桌面路由与 `api.deepseek.com` 的 `deepseek-flash` **都是 1,048,576 token**，最大输出 384K。
- 换算实测：**0.591 token/字符**（中文 + markdown + 思考混排）；用 `inventory.csv` 里的正文字符 × 0.591 估算 message tokens。
- 判据：`估算 token + 期望输出上限 < 1,048,576` 才能整篇续聊。实测样本：1272 轮 / 273 万字 = 1,613,141 token → 单个会话直接 `CONTEXT_WINDOW_EXCEEDED`（`maximum context length is 1048576 … 1613141 in the messages`）。
- 处置：**尾部切片 + 接续摘要**，不要试图硬塞：
  1. `split_parts.ps1` 把（去思考的）`.md` 按约 5 万字切块；
  2. 每块一个 subagent 提炼"主题/关键事实/已定决定/未决问题"，再合并成 `概要-<会话名>.md`。注意 **subagent 并发上限 8**（一次 fan-out 40 个会报 `subagent limit reached`），分批跑；
  3. `slice_conv.ps1 -AlternateRoles`：保留最后 N 轮（默认 150），把摘要挂成**第一条 USER 消息（id=1）**，插一条合成 ASSISTANT 回执（id=2，给 chat-demo 满足"角色交替"），其余重编号 3..N，重写 `current_message_id`。
  4. 切片后约 21 万 token，可续聊；标注清楚"摘要 + 原文"边界。

## 5. 四层离线自检（改包后必跑，别靠"应该没问题"）

脚本在 `G:\CodexDS\DSH\MAIN\PARTNER\deepseek_migrate\`（工作区本地，属 env 耦合）：

| 脚本 | 抓什么 |
|---|---|
| `zip_probe.ps1 -Path <zip>` | ZIP 结构：EOCD 连续、无 ZIP64、无 data descriptor、重名、extra 字段 |
| `zip_crc_check.ps1 -Path <zip>` | 逐条目解压 + 比对 CRC32 与声明大小 |
| `verify_chatdemo.ps1 -Root <导出目录>` | chat-demo 字段校验 + 消息树（父 id<子 id、根为提问、角色交替）；必须用 `JsonNode` 读原始字符串，**别用 `ConvertFrom-Json`**（它会把 ISO 时间转成本地格式，把格式问题藏起来） |
| `simulate_import.ps1 -Path <zip>` | 按 `importArchive.ts` 的状态机走条目顺序，直接报出第一个会落进 `else` 的条目 |

配套脚本：`inventory.ps1`（逐篇轮次/字数/思考量 → `inventory.csv`）、`make_zip.ps1`（按契约顺序打包，`-Ids` 选篇）、`convert_md.ps1`（出 `.md`，`-NoThink` 可选）、`slice_conv.ps1`（切片）、`split_parts.ps1`（切块）、`extract_asar.ps1`（从 `app.asar` 里取插件源码查行为）。

## 6. 症状 → 根因

| 症状 | 根因 / 修法 |
|---|---|
| 插件报"1 个会话无法导入"，无细节 | 多半是 id 用了字符串；查 `verify_export.ps1` / 读 `src/format.ts` |
| chat-demo 报"文件格式错误或使用了旧版的对话导出 ZIP 文件" | ①条目顺序（index 提前）②角色不交替 ③id 字符串 ④时间格式；依次跑第 5 节四件套 |
| 单会话发一句话即 `CONTEXT_WINDOW_EXCEEDED` | 该篇超 1M token，走第 4 节切片 |
| 站点打开 401 Login Redirect | Netlify Drop 的部署是 draft：Deploys 列表点 **Publish deploy**，或 Site configuration → Access & security 关掉 Password protection |
| 手机加主屏后数据丢 | 清站点数据 / 卸载浏览器；导入成功后**立刻在设置里导出一次 ZIP** 当快照 |
| 换手机不同步 | 设计如此（IndexedDB 按 origin+浏览器隔离），靠导出/导入搬 |

## 7. 手机端托管要点（chat-demo）

1. 下载官方 Releases 静态包（`chat-demo-v0.1.1.zip`，约 1.88 MB，解压即 `dist`，**不需要 Node/pnpm**）。
2. 拖到 Netlify Drop（登录后才有拖拽区）或 Cloudflare Pages（Direct Upload）。
3. **必须发布成非 draft**，否则 401。
4. 手机浏览器打开 → 设置填 API Key（`platform.deepseek.com`，需充值）→ 数据管理 → 导入 ZIP。
5. Chrome「添加到主屏幕」→ WebAPK（独立图标/全屏），数据仍在该 origin 的 IndexedDB。
6. 立刻「导出所有历史对话」存一份到手机文件，作为快照备份。

计费参考（`deepseek-flash`）：输入 cache-miss $0.15/M（off-peak）/ $0.3/M（peak），输出 $0.6 / $1.2，搜索与抓取 $0.75/千次，文档解析 $0.225/千页；一次 20 万 token 上下文 ≈ $0.03。

## 8. 边界（明确不做）

- 不往**官方 App / chat.deepseek.com 写回**会话：没有导入接口，官方导出是单向的。
- 不装来源不明的 APK / 第三方客户端；需要 App 形态用 PWA（WebAPK）。
- 不改写原文内容；摘要与合成回执必须显式标注是迁移产物（`（迁移说明）` / `【迁移接续摘要】`）。
- 不重跑已成功的导入（DSH 插件不记已导过，重复导入会产生重复会话；chat-demo 是整体替换）。
