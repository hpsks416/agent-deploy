---
name: windows-node-spawn-cli
description: Use when a Node script on Windows must invoke pnpm/npm or another CLI installed as a .cmd/.ps1 shim, and needs the cross-platform-correct way to do it.
---

## 概述
在 Windows 上让 Node 脚本稳定调用 pnpm/npm 等 `.cmd`/`.ps1` 垫片 CLI。**优先复用标准轮子 `cross-spawn`，不要自造直调方案。**

## 何时用
- Node 脚本里用 `spawnSync('pnpm', ...)`，结果 `status` 为 `null`、`exit: unknown`、且没有任何输出。
- 需要从脚本里跑包管理器命令并读它的真实输出。

## 核心模式

1. **优先用 `cross-spawn`（业界事实标准）**：
   - 安装 `cross-spawn`，用它的 `spawn`/`spawnSync` 替代 node 原生 `child_process.spawn`。它自动处理 Windows 上 `.cmd`/`.bat` 垫片需要 `shell: true` 的问题，跨平台行为一致。
   - 同族可选：`execa`（更强的现代封装，带 promise API + 错误处理）。
2. **零依赖兜底（只在无法引入依赖时）**：定位真实入口，全路径直调 `node.exe` + `.mjs` 入口，绕开 shell 与 `.cmd` 解析。
3. 需要看实时输出时用 `stdio: 'inherit'`；需要判断结果时读取 `status`。

## 常见错误
- 直接用命令名 + 不加 `shell: true` → 解析不到垫片且不报错。
- 加了 `shell: true` 又没处理参数引用/空格路径。
- 只检查 `status !== 0` 就断定「命令失败」，其实命令根本没跑起来（应为 `status === null`）。
- **自造直调方案而不先查 cross-spawn**——这是「写更弱的轮子」的反模式。

## References

- `cross-spawn`: https://github.com/moxystudio/node-cross-spawn
- `execa`: https://github.com/sindresorhus/execa
