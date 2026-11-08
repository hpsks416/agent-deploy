---
name: web-3d-asset-pipeline
description: Prepare and optimize browser-game 3D assets. Use when the user asks for GLB or glTF shipping work, including Blender cleanup and export, collision or LOD setup, compression, texture packaging, and runtime validation.
---

# Web 3D Asset Pipeline

## Overview

Use this skill for shipped 3D assets, not runtime scene code. The default output format for browser 3D work for this skill is GLB or glTF 2.0. The goal is predictable runtime assets, not whatever the DCC tool happened to export first.

This guidance is engine-agnostic and can serve Three.js, React Three Fiber, Babylon.js, or PlayCanvas.

## Use This Skill When

- the task is about GLB or glTF shipping format
- the task is about model cleanup, texture packaging, compression, LOD, or collision proxies
- the runtime stack is already chosen and the remaining problem is asset quality or size

## Do Not Use This Skill When

- the task is about scene, camera, renderer, or game-loop structure
- the task is purely about React versus vanilla Three.js routing
- the user is still deciding between runtime engines

## Default Pipeline

1. Author and clean the source asset in a DCC tool such as Blender.
2. Export to GLB or glTF 2.0.
3. Optimize with glTF Transform.
4. Validate naming, pivots, transforms, material reuse, and texture budgets.
5. Add collision proxies, LOD strategy, and baked-lighting assumptions as needed.
6. Ship the optimized asset and load it with engine-native GLTF support.

## Format Rules

- Default shipping format: GLB or glTF 2.0.
- Do not treat FBX, OBJ, or DCC-native formats as the long-term runtime contract.
- Apply or normalize transforms before shipping.
- Keep units, pivots, and orientation conventions consistent across the whole asset set.

## Optimization Rules

- Use glTF Transform for pruning, deduplication, simplification, and packaging.
- Use geometry compression intentionally.
  - Draco is a valid option when decode cost and compatibility fit the runtime.
  - Meshopt is often a strong default for web delivery.
- Compress textures deliberately.
  - Use KTX2 or BasisU when the runtime stack supports it.
  - Use WebP or AVIF where they make sense in the broader asset pipeline.
- Reuse materials and textures where possible to cut memory and draw-call cost.

## Runtime-Ready Asset Rules

- Keep model hierarchy names stable and meaningful.
- Set pivots and origins for gameplay interaction, not just for DCC convenience.
- Author explicit collision proxies for physics-heavy scenes.
- Decide whether lighting is dynamic, baked, or hybrid before final export.
- Plan LODs for large environments or repeated props.
- Keep texture resolution proportional to on-screen use, not source-art ambition.

## Agent-Ready Rules

Beyond production quality, 3D assets consumed by an agent workflow must be "agent-ready" (not just "production-ready"):

1. **Divisible, not monolithic**: prefer models that can be split into parts an agent can select and edit later (separate meshes for replaceable components), rather than one fused mesh.
2. **Meaningful hierarchy names**: an agent needs stable, semantic node names to target a part by name ("fan_grill", "base") instead of `Cube.017`. This is a prerequisite for natural-language editing and parameterized adjustment.
3. **Parametric over baked where possible**: keep materials, transforms, and dimensions adjustable; bake only what must be final. An agent can then change a part's color, size, or material without regenerating the whole asset.
4. **Callable by other agents**: prefer assets/outputs that can be consumed through a tool/MCP interface, not only a GUI export button.

Division of labor when an agent is the caller:
- **General model** (task understanding, decomposition, mechanical/industrial parts via code + primitives) — "figures out what to do".
- **Specialized 3D model** (organic/curved, dense-detail objects: humans, animals, complex props) — "makes the complex model well".
Pick the right path per asset type, rather than forcing one tool for everything.

### Agent-Ready 落地轮子（开源，已核实）

把上面的抽象原则落到具体开源工具（对应「Agent-Ready」三层）：

- **可拆分/分件** → [Hyper3D BANG Parts Skill](https://github.com/DeemosTech/rodin3d-bang-skills)：单图/提示词 → Rodin Gen-2 生成源资产 → BANG 智能分件 → 下载分段零件（glb/usdz/fbx/obj/stl）+ `manifest.json` 记录每 part 的 UUID 与路径。
- **agent 操控 Blender + 生 3D** → [BlenderMCP + Rodin 集成](https://github.com/DeemosTech/blender-mcp-rodin-integration)：MCP 让 agent 直接操控 Blender（建/改对象、材质、执行 Python）+ 经 Hyper3D Rodin 生成 3D。
- **agent 调生成** → [Rodin MCP Server](https://antigravity.codes/mcp/rodin)：经 MCP 描述需求 → agent 调 Rodin 生成 → 查进度 → 取回结果，把 3D 生成接入更长的 agent 任务链。

使用原则：本机是「DSH 单机环境」，这些轮子需 API key（Hyper3D）或 Blender+uv 环境，属**按需引入**而非默认依赖。当任务确实需要「分件/agent 操控/agent 调用生成」时，优先复用它们，而不是在 DSH 里自造一套。

## Common Failure Modes

- Shipping raw DCC exports without cleanup
- Too many unique materials
- Texture sizes far above visible need
- Missing collision proxies
- Scale or pivot mismatches between assets
- Runtime code compensating for asset mistakes that should be fixed upstream
- Fused/monolithic meshes with unnamed nodes — agent cannot target parts for later editing

## References

- Three.js stack: `references/threejs-stack.md`
- React Three Fiber stack: `references/react-three-fiber-stack.md`
- GLB loader starter: `references/gltf-loading-starter.md`
- Rapier starter: `references/rapier-integration-starter.md`
- 3D asset pipeline reference: `references/web-3d-asset-pipeline.md`
- Alternative engines: `references/alternative-3d-engines.md`
