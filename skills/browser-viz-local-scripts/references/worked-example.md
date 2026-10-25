# Worked Example: SolidWorks-to-browser Viewer

This skill was distilled from a real project that takes SolidWorks STEP/STL assemblies, converts them to glTF, and shows them in a three.js viewer with PBR materials, joints, sectioning, and an arena background. Its layout is a concrete reference for the architecture above:

```text
cad-viewer/
├── server.py                 # Python stdlib HTTP server (thin)
├── rust-server/              # alternative Rust+axum server, same API
├── index.html / main.js      # frontend entry, no build step
├── viewer/                   # joints.js, scene-tree.js, section.js, materials.js, state.js, panels.js
├── lib/                      # three.module.js, OrbitControls, GLTFLoader, STLLoader
├── tools/
│   ├── build.py              # orchestrates: scan -> translate -> convert -> manifest
│   ├── import_step.py        # OCP parse of STEP (hierarchy + instance transforms + colors)
│   ├── export_step.py        # Blender assemble STEP -> glb
│   ├── export_blender.py     # Blender single-part STL -> glb
│   ├── translate_names.py    # offline Chinese-name translation (no online API)
│   └── config.json           # Blender/python paths, auto-detected
├── assets/
│   ├── export/               # raw input STEP/STL (large files not committed)
│   ├── joints/               # joint descriptions (generated template, hand-edited)
│   └── materials/            # material library + textures
├── models/                   # output: *.glb + manifest.json + *.joints.json + *.meta.json
└── work/                     # intermediates, previews, vendored deps
```

The pieces map to this skill as follows:

- `server.py` / `rust-server` implement the thin server + JSON API in `references/architecture.md`.
- `tools/build.py` is the pipeline the server invokes through a subprocess.
- `models/manifest.json` is the output contract shared by the API and frontend.
- `index.html` + `viewer/*.js` implement the patterns in `references/threejs-viewer.md`.
- `assets/joints/*.json` and `user_state.json` are the joint and user-state persistence described in the architecture reference.

The reusable lesson is not the CAD specifics but the separation: keep parsing/export/translation in scripts, keep the server thin, and make the browser a dumb-but-capable client over a `manifest.json` contract.