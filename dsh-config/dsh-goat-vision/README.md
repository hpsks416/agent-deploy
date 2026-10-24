# dsh-goat-vision

**给纯文本的 V4 Pro 装上眼睛，双链路可切换。** 注册两条 provider 路由，贴图即用：图片先由各自链路的 V4.1-Flash 转译成文字，再交给 V4 Pro 推理作答。

| 路由（模型选择器显示名） | 内层供应商 | 大脑 | 眼睛（转译 VLM） | 走哪条链路 |
|---|---|---|---|---|
| **GOAT + 自动识图**（`goat-vision`） | `commandcode` | `deepseek/deepseek-v4-pro` | `deepseek/deepseek-v4.1-flash` | GOAT / Command Code |
| **官方直冲 + 自动识图**（`deepseek-vision`） | `deepseek-official` | `deepseek-v4-pro` | `deepseek-flash`（V4.1，官方原生多模态） | api.deepseek.com 直连 |

```
用户贴图 ──▶ vision 路由（声明 image 输入，附件预检放行）
                 │  对应链路的 V4.1-Flash 转译（OCR + 版式 + 细节，reasoning_effort: low）
                 ▼
           V4 Pro 作答 ◀── 纯文本对话（图片已替换为 [图片转译] 文字）
```

GOAT 链路是主力，官方链路是**兜底**：GOAT 挂掉/限速时切到「官方直冲 + 自动识图」即可，无需改配置。

## 为什么不用现成的 dsh-vision-proxy

`dsh-vision-proxy` 是为**单路由的 `deepseek-official` 适配器**写的：它把自己的路由 id（`deepseek-vision`）原样传给内层适配器的 `listModels`/`resolveModel`/`stream`。而 pi-ai 适配器（`commandcode` 等）所有方法都按 `provider` 字符串查路由——`deepseek-vision` 在 pi-ai 里不存在，会直接抛 `no configured provider`。本插件做对那层「外层路由 id → 内层路由」的映射，任何适配器都能包。

## 验证状态（已实测）

- ✅ GOAT 链路 VLM：`deepseek/deepseek-v4.1-flash` 经 Command Code 收图 200，正确转译。
- ✅ 官方链路 VLM：`deepseek-flash` 经 `api.deepseek.com` 收图 200，正确转译（`reasoning_effort: low` 有效，102 推理 token）。
- ✅ 多路由冒烟测试 17 项全绿（两条路由各自映射到正确内层 provider，图片在进内层前被转成文字）。
- key 全走 credentials 服务（`COMMANDCODE_API_KEY` / `DEEPSEEK_API_KEY`），**不写明文**。

## 安装

```powershell
dsh plugin --profile web add G:\CodexDS\DSH\INTRO\dsh-goat-vision
```

> 本插件**零运行时依赖**（只用 node 内置 + 全局 fetch），无 build 脚本、无 sharp，不触发 pnpm 的 build 拦截。

装完**重启 `dsh web`** 才会加载（web 的 ESM 缓存不会自动更新）。

## 使用

1. 重启后模型选择器出现 **GOAT + 自动识图** 与 **官方直冲 + 自动识图** 两条路由。
2. 选 **GOAT + 自动识图** + `deepseek/deepseek-v4-pro`（GOAT 主力）；或选 **官方直冲 + 自动识图** + `deepseek-v4-pro`（官方兜底）。
3. 直接粘贴/拖入图片发送 → 图片被对应 V4.1-Flash 转译（`[图片转译]` 前缀），V4 Pro 基于文字作答。

## 配置（默认已适配本机，可省略）

配置在插件自带的 `cordis.patch.yml`（`routes` 数组）。要覆盖，在 profile 的 `cordis.patch.yml` 用 **id 定向覆盖**（不要用 `insert`，否则重复注册）：

```yaml
# C:\Users\Razer\.dsh\profiles\web\cordis.patch.yml
- id: dsh-goat-vision
  config:
    routes:
      - providerId: goat-vision
        displayName: GOAT + 自动识图
        innerProvider: commandcode
        baseURL: https://api.commandcode.ai/provider/v1
        model: deepseek/deepseek-v4.1-flash
        apiKeyEnv: COMMANDCODE_API_KEY
      - providerId: deepseek-vision
        displayName: 官方直冲 + 自动识图
        innerProvider: deepseek-official
        baseURL: https://api.deepseek.com
        model: deepseek-flash
        apiKeyEnv: DEEPSEEK_API_KEY
```

每条路由的键：

| 键 | 含义 |
|---|---|
| `providerId` | 注册的路由 id |
| `displayName` | 模型选择器显示名 |
| `innerProvider` | 被包装的内层路由（大脑所在） |
| `baseURL` | VLM 端点（OpenAI 兼容，`/chat/completions` 自动追加） |
| `model` | 眼睛模型（转译 VLM） |
| `apiKeyEnv` | credentials 服务里解析的 key 名 |
| `apiKey` | 可选：写死明文 key（覆盖 apiKeyEnv） |
| `maxTokens` | VLM 输出上限（默认 4096，思考模型给足） |
| `timeoutMs` | VLM 超时（默认 120000） |
| `reasoningEffort` | 转译请求 reasoning_effort（`low`/`off`/空串；官方 V4.1 用 `low` 压推理 token） |
| `marker` | 转译文字前缀（默认 `[图片转译]`） |
| `failureMode` | `placeholder`=失败插占位继续；`error`=整轮失败 |

## 已知边界

- 描述文本计入 V4 Pro 的 context（每图几百 token，仅首次；进程内按图片 SHA-256 缓存，同图只转译一次）。
- 转译质量受 V4.1-Flash 视觉能力上限约束；重度 OCR 可调大 `maxTokens`，或把官方链路的 `model` 换成 `deepseek-v4-flash-vision-exp`。
- 插件不做图片降采样；超大图由 VLM 端点自身限制决定。

## License

MIT
