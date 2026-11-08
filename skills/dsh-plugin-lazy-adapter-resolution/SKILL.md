---
name: dsh-plugin-lazy-adapter-resolution
description: Use when writing a DSH plugin that depends on an LLM provider adapter registered by another plugin.
---

## 概述
DSH 插件在 `apply()` 阶段不要同步解析「可能还没注册好」的内层 provider 适配器，改为请求时懒解析。

## 何时用
- 你的插件包裹/代理另一个 provider（例如识图转译插件查 commandcode 适配器）。
- 插件依赖的适配器由另一个插件在 settings 注入后才注册。

## 核心模式
1. `apply()` 里只记录配置，**不要**调用 `ctx.llm.registration(provider)` 这类查询。
2. 在真正需要适配器的路径（`listModels` / `resolveModel` / `stream`）里才去解析。
3. 给那些「注册时就会被调用」的钩子（如 `providerRetryPolicy`）加 `try/catch` 兜底，允许它暂时拿不到适配器。
4. 加回归测试：「内层适配器缺失时 `apply()` 不抛异常」。

## 关键点
- `registration()` 对未注册的 provider 是 **直接 throw**，不是返回 `undefined`；用 `?.` 无法兜住。
- 启动期一次抛异常会让整个插件树加载失败，典型症状是启动闪退。

## 常见错误
- 用 `registration(p)?.adapter` 以为查不到会静默返回 undefined。
- 把解析结果缓存到模块顶层 → 仍然是启动期求值。
