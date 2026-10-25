# Server and API Architecture

## Server layer

Two reasonable options for a local tool:

- **Python stdlib `http.server`** — zero dependencies, fine for a single user. Use a `ThreadingHTTPServer` so the static frontend and a slow build request do not block each other.
- **Rust + axum** — one small optimized binary, good when the user explicitly wants a compiled/single-file artifact. It still needs the pipeline runtime (Python/Blender) for heavy work, so Rust only replaces the HTTP layer, not the pipeline.

Either way the server is thin. It serves static files, reads JSON, and spawns the pipeline. Do not port parsing/conversion logic into the server.

## Endpoints

A minimal but sufficient set:

- `GET /` and static files — the frontend (`index.html`, `main.js`, `viewer/*.js`, `lib/*`). Map URLs to files under the repo root, percent-decode the path, and reject any `..` segment or path that escapes the root.
- `GET /api/manifest` — read `models/manifest.json` (or equivalent) and return it; return an empty model list if absent.
- `GET /api/files` — list input files that are candidates for conversion, joined with what has already been built (slug, output path, preview, metadata).
- `GET /api/state` / `POST /api/state` — read/write a local user-state JSON.
- `POST /api/build` — take the files to convert, spawn `python tools/build.py --files <json>`, capture stdout/stderr, and return success/error plus the refreshed manifest.

## Data flow

```
input assets (raw files)
   -> pipeline script(s): parse / transform / export  (heavy work, subprocess)
   -> intermediate files under work/
   -> output artifacts + manifest.json under models/ (or similar)
   -> browser reads manifest and artifact URLs via the API
```

Keep the contract explicit: the pipeline writes a `manifest.json` whose entries carry the human name, the slug, the output path, and any metadata. The server and frontend both read it, so a new asset needs no server or frontend code change.

## State persistence

- Store user state (materials, camera, panel layout, defaults) as `user_state.json` at the repo root.
- Write to a `.tmp` file first, then atomically rename over the target, so a crash mid-write never leaves a corrupt file.
- This also makes the state shared across browsers because it lives server-side rather than in `localStorage`.

## Configuration

- Put external tool paths (Blender executable, a specific Python interpreter, converter paths) in `tools/config.json`.
- Auto-detect on startup: check common install locations, then let the config override.
- Let the user override the Python interpreter for the build subprocess via an env var (e.g. `CAD_VIEWER_PYTHON`).

## Long-running jobs

- Prefer a synchronous `POST /api/build` for short jobs: run, return the result.
- For jobs that can take minutes (large exports), emit periodic heartbeats from the subprocess so the user can tell it is still alive, and surface the last line of stderr on failure.
- If a job can outlast an HTTP request, switch to start/poll (`POST /api/build` returns an id, `GET /api/build/<id>` reports status), but only add this when a real job needs it.

## Naming and non-ASCII filenames

- Never use raw Chinese/space-heavy filenames as URLs or artifact keys. Generate a slug per file and keep a naming map: original name -> slug -> machine translation/display name.
- The UI shows the human name; the filesystem and URLs use the slug. Keep the mapping in a JSON file so it survives rebuilds.