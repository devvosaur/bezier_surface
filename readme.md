# Bézier Surface Editor for Godot

Godot editor plugin for creating and editing bicubic Bézier surfaces made of rectangular patches.

## Features
- Bicubic Bézier patch grids with C0 continuity: boundary control points of adjacent patches are shared (compact representation).
- Surface position and tangent evaluation.
- Patch extrusion and row/column removal.
- Multi-selection and proportional editing with a smoothstep falloff.
- Blender-style transform tools with axis and plane constraints.

## Installation
1. Copy the plugin folder to `addons/bezier_surface/`.
2. Enable it in *Project Settings → Plugins*.


## Controls
| Key | Action |
|---|---|
| Shift + click | Multi-select (click again to deselect) |
| G / S / R | Grab / Scale / Rotate the selection |
| X, Y, Z | Lock to an axis while a tool is active |
| Shift + X, Y, Z | Lock to a plane (YZ, XZ, XY) |

## Limitations / Roadmap
- C0 continuity only (no G1/C1 enforcement across patches).