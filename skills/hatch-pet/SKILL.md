---
name: hatch-pet
description: Create, repair, validate, visually QA, and package Codex-compatible v2 animated pets from character art, generated images, company or prospect brand cues, or visual references. Use for any new Codex pet, custom mascot, non-pixel pet style, brand-inspired pet, existing-pet repair, or 8x11 spritesheet workflow requiring all 9 standard animation rows, 16 look directions, deterministic assembly, QA artifacts, and spriteVersionNumber 2 packaging.
---

# Hatch Pet

## Overview

Create a Codex-compatible v2 animated pet from a concept, brand cue, company/prospect name, one or more reference images, or any combination of those inputs. Every newly hatched pet is an 8x11 atlas with the 9 standard animation rows plus 16 clockwise look directions and is packaged with `spriteVersionNumber: 2`. The intermediate 8x9 atlas exists only to assemble and review rows 0-8; never package it as a new pet.

User-facing inputs are optional. If the user omits a pet name, infer one from the concept, brand, company, or reference filenames; if that is not possible, choose a short friendly name. If the user omits a description, infer one from the concept or references. If the user omits reference images, generate the base pet from text first, then use that base as the canonical reference for every animation row.
## 四视图 → 假 3D 可旋转（借 sprite-stacking）

手里只有 4 个方向的像素/插画素材，也能做出「可旋转」的观感，不必建真 3D：

1. **4 视图**：front / back / left / right（各自带透明底、同一比例、同一枢轴点）。
2. **深度层叠**：每视图切 2–4 层（主体 / 部件 / 阴影），按视角偏移层间位移，旋转时逐层插值。
3. **旋转序列**：按 8 或 16 个角度采样，插值生成中间帧；转角处用最近视图做形变而非硬切。
4. **交付**：导出 spritesheet 或逐帧 PNG，附一张角度-帧号映射表。

**何时够用**：桌宠、卡片、图标集、轻度 2D 游戏。
**何时不够**：需要真实遮挡、透视、光影一致（如 3D 车/建筑）——那时老实上真 3D。

## 详细章节（references/hatch-pet-detail.md）

正文超过静态体检测试的硬上限，已按原章节顺序整段拆到 `references/hatch-pet-detail.md`，需要时再读：

- Existing Inputs And Upgrades
- Generation Delegation
- Runtime Dependencies
- Storage Controls
- Brand Discovery
- Generation Contract（Visual Job Graph / Look Direction Sequence / Visual Provenance And Grounding）
- Pet-Safe Styles
- Transparency And Effects
- Visible Progress Plan
- Time Budget And Convergence
- Default Workflow
- Required V2 Look-Direction Stage（Direction Acceptance Policy / Blind Review Severity Resolution）
- Lightweight Visual Workers
- Subagent Delegation
- Repair Workflow
- Rules
- Acceptance Criteria