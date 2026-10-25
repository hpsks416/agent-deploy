---
name: browser-viz-local-scripts
description: Add a browser-based visualization or UI on top of a local script/CLI project using a local HTTP server and a no-build web frontend (three.js for 3D). Use when the user wants to view local tool/script output in the browser, wrap an existing Python/Rust pipeline with a web UI, serve a local 3D viewer, or build a local service launcher/dashboard (start/stop/status across several local services). Not for hosted web apps, browser games, or asset-only preparation.
---

# Browser Visualization for Local Script Projects

## Purpose

Turn a local script/CLI project into something the user can inspect and drive interactively in the browser. The reusable shape is a small local HTTP server that serves a static frontend and a thin JSON API, and that shells out to the existing scripts for any heavy work.

A second shape the same skeleton supports is a local service launcher/dashboard: list several local services, show their live status, and start/stop them from one page.

## When to use

- The user has a local script or CLI that processes data and wants to view or interact with the results in a browser.
- The user wants a web UI over an existing Python/Rust pipeline without a hosted backend.
- The user wants a local 3D viewer (three.js) for generated assets.
- The user wants one page to start/stop/check several local services (a launcher/dashboard).

## When not to use

- Hosted, multi-user, or authenticated web apps, or anything needing deployment.
- Browser games (use the game-studio skills).
- Asset preparation/optimization only (use web-3d-asset-pipeline).

## Core architecture

1. Local server = static files + JSON API. Use Python stdlib `http.server` for zero dependencies, or Rust (axum) when a single optimized binary matters. The server is thin: it never does heavy work itself.
2. Heavy work stays in the existing scripts. The server invokes them through a subprocess (e.g. `python tools/build.py`) and serves the artifacts they produce.
3. Frontend is no-build: ES modules loaded directly by the browser (`import * as THREE from './lib/three.module.js'`). Avoid bundlers for local tools.
4. Output contract: the pipeline writes artifacts plus a `manifest.json` that the frontend and API both read. Do not hardcode the artifact list in either layer.
5. Service launcher shape: a `services.json` registry drives everything — each entry declares name, start/stop command, port, and health URL. The server probes status (port + health endpoint) and spawns/kills the scripts; the frontend is a list of status-light cards with start/stop buttons.

## Non-obvious decisions that matter

- Keep the server thin; move pipeline logic into the existing scripts, not the server.
- Persist user state (materials, camera, layout) as a JSON file the server GET/POSTs, written atomically (tmp file + rename), so it survives reloads and is shared across browsers.
- Put external tool paths (Blender, Python, converters) in a config file with auto-detection and a fallback search list, never hardcoded.
- For 3D: normalize units/scale/up-axis on import, use an unbounded orbit camera, and render any background scene so it is excluded from picking, scene tree, and sectioning.

## References

- `references/architecture.md` — server, API, data flow, state persistence, config, long-running jobs.
- `references/launcher-dashboard.md` — the service launcher/dashboard shape: registry, status probing, start/stop, Windows pitfalls.
- `references/threejs-viewer.md` — three.js runtime patterns (camera, PBR, selection, sectioning, joints, background).
- `references/worked-example.md` — concrete structure distilled from a SolidWorks-to-browser viewer.
