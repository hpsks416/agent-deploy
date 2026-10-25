# three.js Viewer Patterns

These are the runtime decisions that recur when turning a local pipeline into a three.js viewer. They assume the frontend is loaded as ES modules with no bundler.

## Loading without a build step

Serve three.js from a local copy (`lib/three.module.js`) and import the pieces you use:

```js
import * as THREE from './lib/three.module.js';
import { OrbitControls } from './lib/controls/OrbitControls.js';
import { GLTFLoader } from './lib/loaders/GLTFLoader.js';
```

Import the loaders and controls from the same version as `three.module.js`. Keeping them in `lib/` means the viewer works fully offline.

## Renderer and lighting

- Use `WebGLRenderer` with `outputColorSpace = THREE.SRGBColorSpace` and `toneMapping = THREE.ACESFilmicToneMapping`.
- For PBR materials to read correctly, add an environment/IBL (a `RoomEnvironment` or a loaded HDR), not just a couple of directional lights. A background scene usually needs its own brighter light setup so the model and background do not share one light rig.

## Camera

- Default OrbitControls clamps polar angle to `[0, PI]`, so the camera cannot cross the top and bottom poles and the view feels restricted. Set `controls.minPolarAngle = -Infinity; controls.maxPolarAngle = Infinity` (or a much larger range) for a fully free orbit.
- If the user wants a fully free viewpoint, leave no azimuth/polar clamp. Add zoom and pan limits only when there is a concrete reason.

## Normalization on import

Do this once when an asset loads, not per frame:

- Detect units (CAD exports are often millimeters) and scale to a sensible working unit (meters or a scene unit that keeps the model near 1-10 units).
- Normalize orientation to Y-up. STEP/STL exports frequently come in rotated 90 degrees or upside down; correct the up-axis here.
- Compute the bounding box and use it to set the camera target and initial distance, and to place the model on the ground plane rather than floating.

## Selection, highlight, and scene tree

- Use `Raycaster` against a list of selectable meshes for click-to-select.
- Highlight by swapping the material emissive or adding a distinct color; keep the original material to restore.
- Build the expandable tree from the glTF node hierarchy (`gltf.scene`), keyed by node name. Keep it separate from the visual scene so hidden/background objects are excluded.

## Sectioning

- Use renderer-level clipping: `renderer.clippingPlanes = [plane]` plus `material.clippingPlanes` and `material.clipShadows`, or `localClippingEnabled` for per-object clipping.
- Provide a default plane (for CAD usually XZ), allow switching to XY/YZ, and let the user drag or tilt it. Exclude the background scene and non-model helpers from clipping.

## Joints / articulation

- Drive joints by mutating a node transform in the glTF hierarchy, not by moving meshes in world space.
- Model a joint as: target node, type (`revolute`/`continuous`/`prismatic`), axis, optional pivot, and min/max/default. Apply `revolute` as a rotation around the axis about the pivot.
- For a revolute with an offset pivot, translate so the pivot is at the origin, rotate, then translate back. Draw a visible axis marker only when the joint panel is open.

## Background scene

- Load the background (a room, arena, or ground) as a separate object/group and mark it non-interactive: skip it in raycasting, the scene tree, sectioning, and material editing.
- When the camera gets near the ground plane, fade the background transparent so it does not occlude the model.

## Materials

- Decouple color, metalness, and roughness into independent controls; CAD imports often only carry a diffuse color, so treat metalness/roughness as user-chosen, not as imported data.
- Imported CAD meshes usually have no UVs. Sample normal/roughness maps with triplanar projection (`three.js` triplanar mapping or a small shader) so textures do not rely on UVs.