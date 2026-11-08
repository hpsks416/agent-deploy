---
name: hatch-pet
description: Create, repair, validate, visually QA, and package Codex-compatible v2 animated pets from character art, generated images, company or prospect brand cues, or visual references. Use for any new Codex pet, custom mascot, non-pixel pet style, brand-inspired pet, existing-pet repair, or 8x11 spritesheet workflow requiring all 9 standard animation rows, 16 look directions, deterministic assembly, QA artifacts, and spriteVersionNumber 2 packaging.
---

# Hatch Pet

## Overview

Create a Codex-compatible v2 animated pet from a concept, brand cue, company/prospect name, one or more reference images, or any combination of those inputs. Every newly hatched pet is an 8x11 atlas with the 9 standard animation rows plus 16 clockwise look directions and is packaged with `spriteVersionNumber: 2`. The intermediate 8x9 atlas exists only to assemble and review rows 0-8; never package it as a new pet.

User-facing inputs are optional. If the user omits a pet name, infer one from the concept, brand, company, or reference filenames; if that is not possible, choose a short friendly name. If the user omits a description, infer one from the concept or references. If the user omits reference images, generate the base pet from text first, then use that base as the canonical reference for every animation row.
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