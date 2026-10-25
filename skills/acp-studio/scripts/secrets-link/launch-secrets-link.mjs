#!/usr/bin/env node
// secrets-link 跨平台启动器 —— Windows / macOS / Linux 通用。
// 用法：node launch-secrets-link.mjs
// 面板本身是 Node，本启动器不依赖 cmd 也不依赖 sh，任何装了 Node 的平台都能跑。
await import(new URL('./secrets-link-web.mjs', import.meta.url));
