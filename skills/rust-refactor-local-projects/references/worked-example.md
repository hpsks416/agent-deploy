# Worked Example: Python stdlib server -> Rust + axum

This skill was distilled from a local 3D viewer that originally served its frontend with a Python stdlib `http.server`. The refactor replaced only the HTTP layer with Rust; the heavy CAD pipeline (OCP parse, Blender export, offline translation) stayed in Python and is invoked as a subprocess.

## What changed

- `server.py` (Python `http.server`) -> `rust-server/` (Rust + axum + tokio + serde).
- Same four endpoints, byte-compatible responses:
  - `GET /` and static files
  - `GET /api/manifest`
  - `GET /api/files`
  - `GET /api/state` / `POST /api/state`
  - `POST /api/build`
- `POST /api/build` still spawns `python tools/build.py --files <json>`; the Rust binary never does CAD work.

## Result

- A single ~1.3 MB `cad-viewer-server.exe` (LTO + strip) replaces the Python server.
- Serving already-built models no longer needs Python; only the conversion path does.
- The frontend and pipeline required no changes because the contract was preserved.

## Structure

```text
cad-viewer/
├── server.py                 # original, kept as a reference/fallback
├── rust-server/
│   ├── Cargo.toml            # axum, tokio, serde; release: lto + strip
│   ├── Cargo.lock            # committed
│   └── src/main.rs           # routes + static serving + subprocess orchestration
├── build-rust.cmd            # locates MSVC via vswhere, loads vcvars64, then cargo build
└── tools/build.py            # unchanged heavy pipeline
```

## The reusable lesson

The win came from rewriting the thin, I/O-bound serving layer, not from porting the parser/exporter. Measure the before/after (binary size and startup) and keep the API contract stable so nothing else has to move.