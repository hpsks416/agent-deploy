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
- `coupling` 沿用 `core-skills.txt` 的四档（none/light/env/hardcode），由 `deploy.ps1` 末尾打印提醒。
- 加一条 `engines.dsh` 就能让装插件前做版本断言（见下）。

## 4. 运行手册

```powershell
# 预览（不写盘）
pwsh deploy.ps1 -Framework dsh -Track all -DryRun

# 双轨都铺
pwsh deploy.ps1 -Framework dsh -Track all

# 只铺 skill（老行为，默认值）
pwsh deploy.ps1 -Framework codex -Track skills

# 只装/重接插件（= 委托 dsh-config/install.ps1 -PluginsOnly）
pwsh deploy.ps1 -Framework dsh -Track plugins

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

## 5. 本次顺带修掉的漂移

| 漂移 | 之前 | 之后 |
|---|---|---|
| 两套 skill 清单 | `core-skills.txt` 37 条 vs `install.ps1` 硬编码 21 条 | 都读 manifest；`core-skills.txt` 仅兜底 |
| 文档口径 | README/FRAMEWORK 写「36 个」，清单实际 37 条 | 以 manifest 计数为准，文档口径待统一（见 §6） |
| 插件不在主部署器 | 装插件要另跑 `install.ps1` 且无版本断言 | `deploy.ps1 -Track plugins` 一个入口；有 `engines.dsh` 就打印约束，未声明的告警 |
| 无回滚 | 只有 `~/.dsh/_backup_<ts>` 手工恢复 | `-Rollback` 读状态文件自动删/恢复 |

## 6. 限制与下一步（本轮不做）

1. **版本断言只打印不阻断**：本机 DSH 是 `0.1.5-rc.2`；`dsh-*` 五个插件里只有 `dsh-goat-vision` 声明了 `engines.dsh`，其余四个未声明（建议逐个补）。
2. **插件轨尚未 npm 化**：现在仍是「复制目录 + link」，不是 `dsh plugin add` 的正式分发；要正式化需给每个插件补 `engines.dsh` 与发布流程。
3. **回滚不覆盖「被覆盖的已有文件」之外的内容**：只删本次新建目录 + 恢复备份文件；如果本次覆盖了已有插件目录，备份在 `~/.dsh/_backup_<ts>/`，需手动确认。
4. **文档计数待统一**：README/FRAMEWORK/COMPARISON 里的「36」与 manifest 的 37 不一致，建议下一次统一改文档（本轮不动文档，避免与代码改动混在一个提交里）。
