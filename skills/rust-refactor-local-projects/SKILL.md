---
name: rust-refactor-local-projects
description: Refactor a local script/CLI project for efficiency, with Rust as the primary rewrite target for the hot or serving layer. Use when the user wants to speed up a slow local tool, replace a Python/Node server or worker with a single optimized binary, or asks whether a Rust rewrite is worth it. Covers profiling first and choosing Rust versus Go, C/C++, or optimizing the existing language.
---

# Refactor Local Projects for Efficiency (Rust and Alternatives)

## Purpose

Improve a slow or resource-heavy local script/CLI project by rewriting only the layer that actually needs to be faster. Rust is the usual target for a thin, hot layer (server, parsing loop, worker); heavy or rarely-touched logic often stays in its original language.

## When to use

- The user says a local tool is slow, uses too much memory, or starts too slowly.
- The user wants to replace a Python/Node server or worker with a compiled single binary.
- The user asks whether a rewrite in Rust (or another language) is worth it.

## When not to use

- Feature work with no performance or packaging complaint.
- The bottleneck has not been profiled yet: profile first, then decide.

## 第一段：先测再定范围（借 fast-anything）

**别整个重写。先证明哪 5% 慢。**

1. 先 profile（`py-spy` / `cProfile` / `perf` / Chrome trace），拿到**热路径**的真实占比。
2. 只对「占比高 + 边界清晰」的模块重写；其余保持原样。
3. 记录基线：同一输入、同一机器、至少 3 次中位数（单次跑赢是噪声）。

反模式：把「重写成 Rust」当目标 → 工期爆炸、收益不明。

## 第二段：逐块重写 + 行为对拍 + 回退（借 rust-anything）

**正确性靠对拍，不靠「跑一下看着没问题」。**

1. **先录行为**：用原实现跑一批真实输入，保存输出（含错误、边界、空值）。
2. **一块一块换**：每次只换一个函数/模块，换完立刻用录好的输入对拍。
3. **对不上就回退**：不回退到「半对」，直接回到上一版可对拍的实现，再缩小改动。
4. **最终验收**：整条链路对拍 + 性能中位数对比；只报「通过率 + 中位数」，不报感觉。

两段合起来才是完整方法论：**第一段决定改什么，第二段保证改对了**。

## Core method

1. Profile and locate the bottleneck. Do not rewrite the whole project.
2. Pick the rewrite boundary: usually the hot path, the I/O-bound serving layer, or the startup path, not the entire codebase.
3. Preserve the contract: same API, same file formats, same outputs. The rest of the system must not change.
4. Choose the target from the actual need (see the decision guide). Rust is the common pick for a small fast binary.
5. Validate parity: identical endpoints/outputs, plus a before/after benchmark.

## Non-obvious decisions that matter

- A rewrite rarely needs to port everything. Keep the heavy work (parsing, export, ML) in its existing language and have the new layer call it through a subprocess.
- On Windows, Rust needs an MSVC linker (Visual Studio Build Tools) in addition to rustup. Provide a build script that loads vcvars64, and set `lto = true` and `strip = true` for a small release binary.
- Commit `Cargo.lock` for reproducible builds.
- A thin server can be stdlib-only (zero dependencies, builds offline) or use axum/tokio for ergonomics; choose by how much the dependency tree matters.

## References

- `references/decision-guide.md` — profile first, and Rust vs Go vs C/C++ vs optimizing Python.
- `references/rust-rewrite.md` — Rust toolchain, MSVC on Windows, dependencies, release profile, parity validation.
- `references/worked-example.md` — replacing a Python stdlib server with Rust+axum.