# 双轨（Dual-Track）部署：skill 与 DSH 插件怎么分工

> 本文解决一个具体问题：同一个能力，什么时候该写成 **skill**，什么时候该写成 **DSH 插件**；
> 以及 deploy.ps1 如何用 **一份清单** 同时管住两条轨。

## 1. 两条轨是什么

| | **skills 轨** | **plugins 轨** |
|---|---|---|
| 载体 | 文本：`skills/<name>/SKILL.md` + references | 代码包：`dsh-config/<name>/`（package.json + cordis.patch.yml + lib/） |
| 生效 | 模型读进上下文，**自己按规程行动** | 宿主进程加载，**拿到 `ctx.*` 服务替你做事** |
| 能力上限 | 能教模型怎么做，不能扩展宿主 | 能加侧栏/路由/工具/钩子，能拦截写盘 |
| 框架 | codex / claude / dsh 通用 | **仅 DSH** |
| 安装 | 拷贝到 `~/.<framework>/skills/` | link 进 `~/.dsh`，注册 `profiles/web/package.json` 的 `dependencies(link:)` + `dsh.profile.bundles` |
| 版本 | 无 semver（内容即版本） | 包版本 + `engines.dsh` / `peerDependencies` |
| 卸载 | 删目录 | 删包 + 改 package.json + `pnpm install` + 重启 |
| 失败模式 | 软失败（模型不照做） | 硬失败（起不来/崩溃/写盘被拒） |
| 安全面 | 低（提示词注入） | **高（执行代码）** → 装前必须 `skill-supply-chain-scan` |

## 2. 判定规则（一个功能进哪条轨）

| 信号 | 归轨 |
|---|---|
| 需要 UI（侧栏/面板/编辑器/可视化） | plugins |
| 需要后台进程、定时、本地服务、网络端点 | plugins |
| 需要拦截或改写宿主动作（写盘、工具调用、消息流） | plugins |
| 只是「教模型按某规程做事 / 判断标准 / 模板 / 检查清单」 | skills |
| 两者都要 | **薄插件给能力 + skill 给规程**（参考 `dsh-marktext`：插件提供版本护栏，无教学内容） |

判断口诀：**「宿主得会做某件事」→ 插件；「模型得知道怎么做某件事」→ skill。**

## 3. 一份清单：framework-manifest.json

`framework-manifest.json` 是两条轨的**唯一事实源**。`deploy.ps1`、`dsh-config/install.ps1` 都从它读，
`core-skills.txt` 降级为「无清单时的兜底」。

```jsonc
{
  "schemaVersion": 1,
  "tracks": {
    "skills":  { "mode": "copy", "frameworks": ["codex","claude","dsh"], "targets": {".../skills": "..."} },
    "plugins": { "mode": "link", "frameworks": ["dsh"], "target": "~/.dsh", "postInstall": ["pnpm install","重启 DSH"] }
  },
  "items": [
    { "id": "design-qa", "kind": "skill", "source": "skills/design-qa",
      "frameworks": ["codex","claude","dsh"], "coupling": "none" },
    { "id": "dsh-retrieval-guard", "kind": "plugin", "source": "dsh-config/dsh-retrieval-guard",
      "frameworks": ["dsh"], "package": "dsh-retrieval-guard", "version": "0.1.0",
      "engines": {}, "link": true }
  ]
}
```

- `kind` 决定走哪条轨；`frameworks` 决定铺给谁（plugins 只有 `dsh`）。
- `profiles` 决定插件装进哪个 DSH profile：本机有**两条运行时**——
  - **web**（`dsh web` / CLI，`@deepseek-ai/dsh-base 0.1.5-rc.2`）：`deploy.ps1 -Track plugins` 默认写这里；
  - **desktop**（桌面 app，`0.2.2-rc.1`）：由 app 的 Plugins 面板/插件市场管理，`install.ps1 -Profile desktop` 只能重接 link。
  同一个插件可能在两个 profile 里都注册（如 `dsh-retrieval-guard`、`dsh-secure-push-guard`、`dsh-session-sync-flush`），
  所以 manifest 里写明 `profiles: ["web","desktop"]`，避免"改了 web 以为全改了"。
- `coupling` 沿用 `core-skills.txt` 的四档（none/light/env/hardcode），由 `deploy.ps1` 末尾打印提醒。
- 加一条 `engines.dsh` 就能让装插件前做版本断言（见下）。

## 4. 插件契约清单（Phase 1：先跟进契约）

> 顺序：**先把插件轨做成契约合规（本节）→ 再谈跨平台迁移（§8）**。
> 契约事实来自本机实测：`dsh plugin` 只是把参数转发给 profile 目录里的 pnpm（`dsh plugin --profile web add <pkg>` = `pnpm add`）；
> 插件靠 `dsh.bundle.patch` 注册、靠 `dsh.compatibility`/`engines.dsh` 声明版本、靠 `dsh.client.inject` 声明客户端依赖。

一个 DSH 插件要算「契约合规」，逐条：

| # | 检查项 | 依据 | 现状 |
|---|---|---|---|
| 1 | `package.json` 可解析，有 `name`/`version` | pnpm 包基本要求 | ✅ 全部 |
| 2 | `type: module` + `main`/`exports['.']` 指向真实 `lib/index.js` | 实测 5/5 均如此 | ✅ 全部 |
| 3 | `dsh.bundle.patch` 指向存在的 `cordis.patch.yml`，且内含 `- insert:` | 注册进 profile bundles 的唯一入口 | ✅ 全部 |
| 4 | `files` 包含 `cordis.patch.yml` | 否则 npm 打包会漏，装完起不来 | ✅ 全部 |
| 5 | 版本声明 `engines.dsh` 或 `dsh.compatibility.dsh`（含 `dshReleases`） | 实测两种写法都在用 | ✅ 全部（本轮修了 1 处错位） |
| 6 | 声明的范围覆盖目标 profile 版本（web 0.1.5-rc.2 / desktop 0.2.2-rc.1） | 跨 profile 时最容易翻车 | ✅ 3 个守卫插件已补 `engines.dsh = ^0.1.5-rc.2 \|\| ^0.2.2-rc.1` |
| 7 | 有 `lib/client.js` 就必须有 `dsh.client.inject`（+ `platform`） | 客户端插件注入契约 | ✅ skill-studio 合规 |
| 8 | `license` / `description` / `keywords`（分发元数据） | npm 可见性 | ✅ 本轮补齐 license |

**两类插件源**：
- **仓库内（link 轨）**：源码在 `dsh-config/<dir>/`，`install.ps1` 复制到 `~/.dsh/<dir>` 再 `link:` 进 profile；
- **外部 npm（npm 轨）**：源码**不 vendor**，manifest 里写死 `install: {mode:"npm"}` + 版本，`install.ps1` 执行 `pnpm add <pkg>@<ver>` 并把包名追加进 `dsh.profile.bundles`。
  `dsh-marktext@0.1.13` 就是这一类（MIT，但 unpacked **11MB / 698 文件**、自带构建产物，vendor 进来等于把上游快照冻死；固定版本从 npm 装更干净）。

**检查器**：`pwsh check-plugin-contract.ps1 [-Profile web|desktop] [-Json]`，只读、有退出码（0=无 FAIL），可直接进 CI。
它会检查仓库内插件的 8 项契约，**外加** manifest 里 npm 轨插件在当前 profile 是否已按版本装好、是否注册进 bundles。

当前基线：

```
web     : 6 个插件 | PASS 5 | WARN 1 | FAIL 0   # marktext 只属 desktop，web 视角 WARN
desktop : 6 个插件 | PASS 4 | WARN 2 | FAIL 0   # goat-vision / skill-studio 只属 web
```

本轮只做**可安全修复**的四项：补 `license: MIT`（repo LICENSE 是 MIT）、把 skill-studio 的 `dsh.engines.dsh` 提到顶层 `engines.dsh`、检查器支持 `>=` 覆盖判断、加契约检查器。
**不在本轮改**：`dsh.compatibility.dshReleases` 是否要加 `0.2.2-rc.1`（web 侧插件在 desktop 里也注册着，但没在 desktop 上逐个验证过——改了等于替真实兼容性背书）。

## 5. 运行手册

**实测记录（2026-11-10，假 HOME 沙箱，未碰真实 profile）**：

```
install  : deploy.ps1 -Track all -SkipConfig → skills 37/37 OK，插件 5 个目录落到 ~/.dsh/，
           profile package.json 的 link 路径改写到沙箱，状态文件 createdPlugins=5 backups=1，exit 0
rollback : deploy.ps1 -Rollback → 删 37 个 skill 目录 + 5 个插件目录，恢复 profile package.json
           （link 路径回到原值），exit 0
失败路径  : 缺 profile package.json 时 → 插件轨 x 报错 + exit 2，且不再提示 pnpm/重启
```

```powershell
# 预览（不写盘）
pwsh deploy.ps1 -Framework dsh -Track all -DryRun

# 双轨都铺
pwsh deploy.ps1 -Framework dsh -Track all

# 只铺 skill（老行为，默认值）
pwsh deploy.ps1 -Framework codex -Track skills

# 只装/重接插件（= 委托 dsh-config/install.ps1 -PluginsOnly，默认 profile=web）
pwsh deploy.ps1 -Framework dsh -Track plugins

# 桌面 profile（app 管理：只重接 link，装/卸请用 app 的 Plugins 面板）
pwsh deploy.ps1 -Framework dsh -Track plugins -Profile desktop -DryRun

# 回滚最近一次（删本次新建的 skill/插件目录，恢复备份的指令与配置）
pwsh deploy.ps1 -Rollback
pwsh deploy.ps1 -Rollback -DryRun

# 换机全量恢复
pwsh dsh-config/install.ps1 -Source gitee
```

每次非 DryRun 运行都会写状态：`~/.agent-deploy/state/<ts>-<framework>-<track>.json`
（记录本次新建的 skill/插件目录、跳过项、备份的配置文件），`-Rollback` 读最近一条。

**插件轨装完必须**：`cd ~/.dsh/profiles/web; pnpm install; 重启 DSH`。
启动失败看日志：`~/.dsh/logs/startup-*.log`、`~/.dsh/sessions/<工作区>/<session-id>/session.v3.jsonl.zstd`。

## 6. 本次顺带修掉的漂移

| 漂移 | 之前 | 之后 |
|---|---|---|
| 两套 skill 清单 | `core-skills.txt` 37 条 vs `install.ps1` 硬编码 21 条 | 都读 manifest；`core-skills.txt` 仅兜底 |
| 文档口径 | README/FRAMEWORK 写「36 个」，清单实际 37 条 | 以 manifest 计数为准，文档口径待统一（见 §6） |
| 插件不在主部署器 | 装插件要另跑 `install.ps1` 且无版本断言 | `deploy.ps1 -Track plugins` 一个入口；有 `engines.dsh` 就打印约束，未声明的告警 |
| 无回滚 | 只有 `~/.dsh/_backup_<ts>` 手工恢复 | `-Rollback` 读状态文件自动删/恢复 |

## 7. 跨平台迁移（Phase 2：契约稳了再做）

插件轨的能力天然绑 DSH。要「迁移到跨平台」，先按**能力半径**把 5 个插件分三类，别整包搬：

| 插件 | 干的事 | 可移植形态 |
|---|---|---|
| `dsh-retrieval-guard` | 写代码前要求先检索，未检索弹确认框 | 能力本质是**规程 + 一次阻断**：规程已在 `AGENTS.md`/`iron-law-retrieval-first`；阻断可退化为「skill 里的证据门」或 MCP 侧校验 |
| `dsh-secure-push-guard` | 推送前强制 secret-scan | 已是 `secure-push-workflow` skill 的编排；跨平台直接用 skill 版（无需插件） |
| `dsh-session-sync-flush` | 会话落盘同步 | 纯宿主生命周期钩子，**不可移植**；跨平台等价物是各框架的会话落盘机制 |
| `dsh-skill-studio` | CTX 面板里可视化/编辑 skill | UI 面板不可移植；但「skill 提取」逻辑可做成 **MCP server**（跨 agent 通用） |
| `dsh-goat-vision` | 给纯文本模型装眼睛（识图路由） | LLM provider 适配层，**不可移植**；跨平台靠各框架自己的 provider 配置 |

迁移判据（三条，按顺序）：
1. **能做成 MCP 的优先做成 MCP**（MCP 是三个框架都认的通用面），skill 只留规程；
2. 只能靠宿主钩子的（会话落盘、写盘拦截、面板）→ **在插件轨保留**，不同步到 codex/claude，并在 manifest 标 `portable: false`；
3. 纯提示词能力 → 落 skill，天然跨框架。

Phase 2 第一件事不是写代码，而是给 manifest 的每个插件补 `portable` 与 `migration` 两个字段（`mcp` / `skill` / `none`），让「哪些能力跨得过去」可被查询。

## 8. 限制与下一步（本轮不做）

1. **两条运行时要分开看**：本机 `web` profile / `dsh` CLI 是 `0.1.5-rc.2`，桌面 app 是 `0.2.2-rc.1`。插件轨默认写 `web`；`desktop` 由 app 管（本机 desktop 里已注册 `dsh-retrieval-guard`、`dsh-secure-push-guard`、`dsh-session-sync-flush`，另有本仓未收录的 `dsh-context-guard`）。**生态里要求 DSH ≥0.2.1 的插件（如 `dsh-marktext`）只能在 desktop 装，web 装不了。**
2. **版本断言只打印不阻断**：`dsh-goat-vision` 有 `engines.dsh`，其余四个插件没有——建议逐个补 `engines.dsh`，再把断言升级为阻断。
3. **插件尚未 npm 化**：仍是「复制目录 + link」，不是 `dsh plugin add` / 插件市场的正式分发；正式化需补发布流程。
4. **回滚不覆盖「被覆盖的已有文件」之外的内容**：只删本次新建目录 + 恢复备份文件；覆盖的已有插件目录备份在 `~/.dsh/_backup_<ts>/`，需手动确认。
5. **文档计数待统一**：README/FRAMEWORK/COMPARISON 写「36」，manifest 实际 37——本轮不动文档，避免与代码改动混在一个提交。

## 9. 第三方插件门禁（P6，fail-closed）

**为什么加**：DSH「破甲」插件连续 4 天出现（`dsh-jailbreak-workflow` → `fujiang-pojia` → `dsh-purge` → `dsh-purge-safe`）。第三方插件是**执行代码**，不是提示词。

**契约**（SkillSpector v2.12.0，来自其 `docs/DEVELOPMENT.md`）：

- 退出码：`0` = 扫描完成且 `risk_score <= 50`；`1` = `risk_score > 50`；`2` = 出错。
- JSON 字段：`findings` / `filtered_findings` / `risk_score` / `risk_severity`（LOW|MEDIUM|HIGH|CRITICAL）/ `risk_recommendation`（SAFE|CAUTION|DO_NOT_INSTALL）/ `analysis_completeness.is_complete` / `execution_successful`。
- **Windows 不能传 `--output`**（平台不支持安全落盘）——必须省略，改为抓 stdout。

**门禁脚本** `thirdparty-gate.ps1`（仓库根）：

- 只读扫描一个目录，输出 `[PASS]/[BLOCK]/[ERROR]` 与一行证据（score/severity/findings 数/完整性）；
- 拦截条件：`DO_NOT_INSTALL`、`HIGH|CRITICAL`、`exit 1`、分析不完整（可用 `-AllowIncomplete` 明确放行）、扫描器缺失或出错；
- 退出码：`0` 通过 / `3` 拦截 / `4` 扫描器缺失或出错（同样不通过）。

**接入点**：`dsh-config/install.ps1` 的 npm 轨（外部插件）在 `pnpm add` 之后、注册 `dsh.profile.bundles` **之前**强制扫描；未通过则不注册 bundle 并 `exit 2`。绕过只能显式 `-SkipSupplyChain`（日志留痕）。

**手动用法**：

```powershell
pwsh thirdparty-gate.ps1 -Path <插件目录>          # 通过=0 / 拦截=3 / 工具错误=4
pwsh thirdparty-gate.ps1 -Path <目录> -Json        # 机器可读
```

## 10. 兼容性与打包验证（2026-11-14）

**行为验证（context-guard，不需要起 app）**：用假 ctx 驱动 `tools/pre-execute` 瀑布，四档全 PASS——`0.50 pass` / `0.72 warn（只日志）` / `0.86 ask ⚠️ 接近上限` / `0.96 ask 🚨 即将爆窗`。脚本：`G:\DSH\CMAIN\UPDATE\research\context-guard-test.mjs`。

**npm 打包验证**：`pnpm pack` 在 `dsh-config/dsh-retrieval-guard` 产出 `dsh-retrieval-guard-0.1.0.tgz`（6.4 KB），说明 6 个随仓插件具备打包成 npm 包的形态（含 `engines`/`license`/`files`）；**发布到 npm 未做**（缺账号与 2FA），分发目前仍是「复制目录 + link」。

**Phase 2 落地字段**：manifest 每个插件已加 `portable` + `migration`：

| 插件 | portable | migration |
|---|---|---|
| dsh-retrieval-guard / dsh-secure-push-guard / dsh-context-guard | true | skill（规程可写进 AGENTS/skill） |
| dsh-skill-studio | false | mcp（提取逻辑拆 MCP server） |
| dsh-goat-vision / dsh-session-sync-flush / dsh-marktext | false | none（宿主能力/UI，不可移植） |

## 11. npm 发布约定（@hpsks416/*，2026-11-14）

**命名**：6 个随仓插件统一为 `@hpsks416/dsh-*`。原因（实测 npm registry）：`dsh-context-guard` 已被 `greenlv` 占用、`dsh-skill-studio` 已被上游作者 `zhengjunyao` 占用（本仓那份正是它的 patched fork，见 `NOTICE.md`）；其余 4 个名字无人占用，但统一 scope 归属更清楚。

**发布前检查**：`pwsh tools/publish-plugins.ps1 -DryRun`
- 逐包 `pnpm view <pkg> version` 看名称/版本是否已被占用
- `pnpm pack` 出 tarball（发布物 = tarball，不是目录）
- 发布不可逆：同名同版本发过就不能再发，必须先升版本

**真正发布**：`pwsh tools/publish-plugins.ps1`
- token 来自 secrets-link：`G:\KEY\NPM token\416.txt.zip`（运行时解密进 `NODE_AUTH_TOKEN`，不落盘）
- scoped 包必须 `--access public`（否则默认私有、403）
- **token 怎么加**（若还没有）：
  1. npmjs.com 登录/注册（账号名建议 `hpsks416`）并开 2FA；
  2. Access Tokens → **Granular Access Token**：名称 `dsh-plugins-publish`、过期 90 天、权限 **Read and write**、包范围 All；
  3. 明文存临时文件 → `python <acp-studio>\scripts\secrets-link\encrypt-token.py "<明文>" "G:\KEY\NPM token\416.txt.zip"`（自动三层加密并删明文）；
  4. `links.json` 加 `{ "var": "NPM_TOKEN", "file": "G:\\KEY\\NPM token\\416.txt.zip" }`。

**迁移旧名**：已装过旧短名的 profile 在下次 `deploy.ps1 -Track plugins -Profile web|desktop` 时会自动把 `dependencies` 与 `dsh.profile.bundles` 里的旧短名改成 scoped 名（`install.ps1` 内置迁移），改完需重启对应运行时。
