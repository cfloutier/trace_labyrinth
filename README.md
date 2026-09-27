# trace_labyrinth

Processing sketch for experimenting with maze drawings for the pen plotter, built on the
shared xLib (settings load/save, GUI tabs, clipping, direct SVG export).

## Quick Start

1. Open `trace_labyrinth.pde` in Processing (requires the ControlP5 library).
2. Run the sketch — values are loaded from `Settings/default.json`.
3. Adjust parameters in the tabs (Maze, Style, Files), export from the Files tab.

## Maze

Rectangular grid maze carved by the "growing tree" algorithm: a "perfect" maze,
exactly one path between any two cells. River and Straightness change its texture live.

| Parameter | Role |
|-----------|------|
| `maze_cols` / `maze_rows` | Grid size in cells |
| `maze_cell_size` | Cell size (drawing units) |
| `maze_seed` | Random seed — the "New Seed" button draws a new one; same seed + params = same maze |
| `maze_river` | 1 = always grow from the newest cell (depth-first: long winding corridors, few dead ends, long solution); 0 = from a random cell (Prim-like: many short dead ends, short direct solution) |
| `maze_straightness` | Chance to keep carving in the same direction — higher = long straight corridors |
| `maze_openings` | Opens an entrance (top-left) and an exit (bottom-right) in the outer wall |
| `maze_show_solution` | Draws the solution path (entrance → exit, through cell centers) |
| Solution Color | Color of the solution path (display only) |

Note: the direct SVG export ("SVG direct") only contains the walls, not the solution.

Walls are emitted as polylines with consecutive segments on the same grid line merged
into one stroke, to minimize pen lifts on the plotter.

## Files

- `trace_labyrinth.pde`: setup / draw loop, rebuilds the lines when Maze or Page changes.
- `DataGlobal.pde`, `DataGUI.pde`: data chapters and tabs.
- `DataMaze.pde`: maze parameters + Maze tab.
- `MazeGenerator.pde`: maze carving and wall-to-polyline conversion.
- `xLib_*.pde`: shared library, synchronized from `processing_xlib` (don't edit here
  without pulling the change back there — see `processing_xlib/sync-tools/README.md`).

Note: ControlP5 controller names must be unique across the whole sketch, even on
different data objects — hence the `maze_` prefix on every field.
