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
| `maze_start` / `maze_end` | Entrance / exit position, picked on a 3x3 grid: a corner, the middle of a side, or the center (0 = top left … 4 = center … 8 = bottom right). Corners open through their top/bottom wall, sides through the wall facing out, the center has no opening but becomes a 3x3 open "room" with a single door (classic "reach the center" maze; needs a grid of at least 5x5, otherwise the center is a single cell) |
| `maze_openings` | Opens the entrance / exit in the outer wall |
| `maze_show_solution` | Draws the solution path (entrance → exit, through cell centers) |
| Solution Color | Color of the solution path (display only) |

Note: the direct SVG export ("SVG direct") only contains the walls, not the solution.

## Render

How the walls are drawn (the maze itself is unchanged — changing these only redraws,
without regenerating).

| Parameter | Role |
|-----------|------|
| `render_round_corners` | Rounds every wall corner (L turns) with a quarter circle — the solution path too |
| `render_corner_radius` | Corner radius as a fraction of the cell size (0..0.5, so two rounded corners on one wall never overlap) |
| `render_junction` | T and + junctions when rounded: **Sharp** = the branch meets the wall straight on (a + stays a plain crossing); **Rounded** = the branch splits into two fillets tangent to the wall on each side (a + becomes 4 fillets between its arms). Walls always keep touching |

Walls are traced as long continuous strokes to minimize pen lifts on the plotter: a
stroke follows its wall through corners and straight through T junctions, and stops at
wall tips and T stems (see `MazeRender.pde`).

## Files

- `trace_labyrinth.pde`: setup / draw loop — regenerates the maze when Maze changes, redraws when Render or Page changes.
- `DataGlobal.pde`, `DataGUI.pde`: data chapters and tabs.
- `DataMaze.pde`: maze parameters + Maze tab.
- `MazeGenerator.pde`: maze carving (solution path, growing tree, center room) and solution search.
- `DataRender.pde`: render parameters + Render tab.
- `MazeRender.pde`: walls -> polylines (stroke tracing, rounded corners and junction fillets).
- `xLib_*.pde`: shared library, synchronized from `processing_xlib` (don't edit here
  without pulling the change back there — see `processing_xlib/sync-tools/README.md`).

Note: ControlP5 controller names must be unique across the whole sketch, even on
different data objects — hence the `maze_` / `render_` prefix on every field.
