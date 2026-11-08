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