# Rust Rewrite Reference

## Toolchain

- `rustup` installs `cargo` and `rustc`. That alone can compile, but on Windows linking requires an **MSVC linker** (Visual Studio Build Tools with the "Desktop development with C++" workload, or a full Visual Studio install). Without it, the build fails at link time even though the code compiles.
- Locate the MSVC environment with `vswhere`, then load `vcvars64.bat` before building. Provide a `build-rust.cmd` (or similar) that does this so a new machine can build without remembering the steps.

## Project layout

```text
rust-server/
├── Cargo.toml
├── Cargo.lock          # commit this for reproducible builds
└── src/main.rs
```

## Dependencies vs stdlib-only

- For a small server, `axum` + `tokio` + `serde` + `serde_json` is the ergonomic path, at the cost of a dependency tree that needs network access to fetch.
- A stdlib-only server (`std::net::TcpListener` + manual request parsing) has zero dependencies and can build fully offline, but you write the routing/parsing yourself. Prefer this only when offline builds or a truly minimal footprint matter more than development speed.
- Choose deliberately; do not add a framework by reflex.

## Release profile

In `Cargo.toml`:

```toml
[profile.release]
lto = true
strip = true
```

This produces a small, single-binary artifact (a simple server is usually on the order of ~1-2 MB). Report the binary size and startup time as the measurable win.

## Keep the heavy work where it is

The new binary replaces only the hot/serving layer. Keep parsing, export, or ML in the original language and call it through a subprocess:

- Spawn `python tools/build.py` (or the equivalent), pass the needed arguments as JSON, and capture stdout/stderr.
- On failure, surface the last line of stderr rather than a generic message.
- Let an environment variable override the interpreter path so the user can point at a specific Python.

This keeps the rewrite small and avoids porting code that was never the bottleneck.

## Preserve the contract

The routes, JSON shapes, on-disk files, and output formats must stay byte-for-byte compatible with the old layer. The frontend and pipeline should not need any changes.

## Validate parity

- Start the new binary and hit every endpoint.
- Diff each response against the old server's response for the same request.
- Confirm error paths (404, malformed input) behave the same.
- Run a before/after benchmark of the measurable metric (startup time, request latency, memory, binary size) and record both numbers.

## Offline builds

If the build machine has no access to crates.io, either commit a `vendor/` directory (`cargo vendor`) or use a local registry mirror. Lock the dependency versions in `Cargo.lock` so the vendored set is exactly what is needed.