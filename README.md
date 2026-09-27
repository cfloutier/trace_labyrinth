# trace_labyrinth

Processing sketch for experimenting with maze drawings for the pen plotter, built on the
shared xLib (settings load/save, GUI tabs, clipping, direct SVG export).

## Quick Start

1. Open `trace_labyrinth.pde` in Processing (requires the ControlP5 library).
2. Run the sketch — values are loaded from `Settings/default.json`.
3. Adjust parameters in the tabs (Maze, Style, Files), export from the Files tab.

## Maze

Rectangular grid "perfect" maze (exactly one path between any two cells), with the
same two knobs as [mazegenerator.net](https://www.mazegenerator.net/Help.aspx),
independent of each other:
- **Elitism (E)** — solution length: the solution path is carved first, by a
  depth-first walk from entrance to exit whose steps lean toward the exit (E=1: short,
  direct solution) or away from it (E=0: solution wandering through almost the whole
  maze).
- **River (R)** — dead-end texture: the rest of the maze then grows off that path by
  the "growing tree" algorithm, extending the newest cell (R=1: few but long dead ends)
  or a random one (R=0: many short dead ends).

| Parameter | Role |
|-----------|------|
| `maze_cols` / `maze_rows` | Grid size in cells |
| `maze_cell_size` | Cell size (drawing units) |
| `maze_seed` | Random seed — the "New Seed" button draws a new one; same seed + params = same maze |
| `maze_elitism` | E, 0..1 — 1 = short direct solution, 0 = long wandering solution (0.5 = unbiased walk) |
| `maze_river` | R, 0..1 — 1 = few but long dead ends, 0 = many short dead ends |
| `maze_straightness` | Extra (not in mazegenerator.net): chance to keep carving in the same direction outside the solution path — higher = long straight corridors |
| `maze_start` / `maze_end` | Entrance / exit position, picked on a 3x3 grid: a corner, the middle of a side, or the center (0 = top left … 4 = center … 8 = bottom right). Corners open through their top/bottom wall, sides through the wall facing out, the center has no opening (classic "reach the center" maze) |
| `maze_openings` | Opens the entrance / exit in the outer wall |
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
