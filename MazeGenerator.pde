// Rectangular-grid maze in two phases, so the solution length (elitism, E) and the
// dead-end texture (river, R) can be set independently - same two knobs as
// mazegenerator.net:
// 1. Solution path: a depth-first walk from the entrance cell to the exit cell whose
//    steps are biased toward the exit (maze_elitism = 1: short, direct path) or away
//    from it (0: long path wandering through much of the grid). The walk's stack when
//    it reaches the exit is a simple path, carved as the maze's solution.
// 2. The rest: "growing tree" seeded with every solution cell - which active cell gets
//    extended next (newest vs random - maze_river) plus whether a passage keeps its
//    direction (maze_straightness) set the dead-end texture. Everything grows off the
//    path as a tree, so the path stays the one and only solution.
// Uses its own java.util.Random seeded from DataMaze.maze_seed, so a given seed + params
// always give the same maze regardless of any other random() calls in the sketch.
class MazeGenerator
{
  static final int NO_DIR = -1;
  // up, down, left, right as {dRow, dCol}
  final int[][] DIRS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } };

  int cols = 0;
  int rows = 0;

  // hWalls[r][c]: horizontal wall on grid line r (0..rows), above cell (r, c).
  // vWalls[r][c]: vertical wall on grid line c (0..cols), left of cell (r, c).
  boolean[][] hWalls = new boolean[0][0];
  boolean[][] vWalls = new boolean[0][0];

  // Entrance / exit as {row, col, side}: the cell, and which of its walls (DIRS index)
  // faces outside, or NO_DIR for the center (no opening) - see endpoint().
  int[] startCell = { 0, 0, 0 };
  int[] endCell = { 0, 0, 1 };

  // 3x3 position (row-major, as laid out by MazeGUI's radios: 0 = top left ... 4 =
  // center ... 8 = bottom right) -> {row, col, side}. Corners open through their
  // top/bottom wall, side midpoints through the wall facing out, the center not at all.
  int[] endpoint(int code)
  {
    int midR = rows / 2;
    int midC = cols / 2;
    switch (code)
    {
    case 1:  return new int[] { 0, midC, 0 };            // Top
    case 2:  return new int[] { 0, cols - 1, 0 };        // Top Right
    case 3:  return new int[] { midR, 0, 2 };            // Left
    case 4:  return new int[] { midR, midC, NO_DIR };    // Center
    case 5:  return new int[] { midR, cols - 1, 3 };     // Right
    case 6:  return new int[] { rows - 1, 0, 1 };        // Bottom Left
    case 7:  return new int[] { rows - 1, midC, 1 };     // Bottom
    case 8:  return new int[] { rows - 1, cols - 1, 1 }; // Bottom Right
    default: return new int[] { 0, 0, 0 };               // Top Left
    }
  }

  void generate(DataMaze d)
  {
    cols = max(1, d.maze_cols);
    rows = max(1, d.maze_rows);
    startCell = endpoint(d.maze_start);
    endCell = endpoint(d.maze_end);

    hWalls = new boolean[rows + 1][cols];
    vWalls = new boolean[rows][cols + 1];
    for (boolean[] line : hWalls) java.util.Arrays.fill(line, true);
    for (boolean[] line : vWalls) java.util.Arrays.fill(line, true);

    Random rnd = new Random(d.maze_seed);
    boolean[][] visited = new boolean[rows][cols];
    // Direction each cell was carved into from (NO_DIR for the start cell) - lets the
    // straightness bias keep going the same way.
    int[][] cameFrom = new int[rows][cols];

    int[] candidates = new int[4];

    // Phase 1 - solution path (see class comment).
    ArrayList<int[]> path = carveSolutionPath(d.maze_elitism, rnd);
    for (int i = 0; i < path.size(); i++)
    {
      int[] cell = path.get(i);
      visited[cell[0]][cell[1]] = true;
      cameFrom[cell[0]][cell[1]] = NO_DIR;
      if (i > 0)
      {
        int[] prevCell = path.get(i - 1);
        removeWallBetween(prevCell[0], prevCell[1], cell[0], cell[1]);
        cameFrom[cell[0]][cell[1]] = dirBetween(prevCell, cell);
      }
    }

    // Phase 2 - growing tree off the path. Active cells as {row, col}; newest at the end.
    ArrayList<int[]> active = new ArrayList<int[]>(path);

    while (!active.isEmpty())
    {
      int index = (d.maze_river >= 1 || rnd.nextFloat() < d.maze_river)
        ? active.size() - 1
        : rnd.nextInt(active.size());

      int[] cell = active.get(index);
      int r = cell[0];
      int c = cell[1];

      int n = 0;
      for (int i = 0; i < 4; i++)
      {
        int nr = r + DIRS[i][0];
        int nc = c + DIRS[i][1];
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !visited[nr][nc])
          candidates[n++] = i;
      }

      if (n == 0)
      {
        active.remove(index);
        continue;
      }

      int dir = candidates[rnd.nextInt(n)];
      int prev = cameFrom[r][c];
      if (prev != NO_DIR && d.maze_straightness > 0 && rnd.nextFloat() < d.maze_straightness)
      {
        for (int i = 0; i < n; i++)
          if (candidates[i] == prev)
            dir = prev;
      }

      int nr = r + DIRS[dir][0];
      int nc = c + DIRS[dir][1];
      removeWallBetween(r, c, nr, nc);
      visited[nr][nc] = true;
      cameFrom[nr][nc] = dir;
      active.add(new int[] { nr, nc });
    }

    if (d.maze_openings)
    {
      openOutside(startCell);
      openOutside(endCell);
    }
  }

  void openOutside(int[] e)
  {
    int r = e[0], c = e[1];
    if (e[2] == NO_DIR) return;
    if (e[2] == 0)      hWalls[r][c] = false;
    else if (e[2] == 1) hWalls[r + 1][c] = false;
    else if (e[2] == 2) vWalls[r][c] = false;
    else                vWalls[r][c + 1] = false;
  }

  // Depth-first walk from startCell to endCell. At each step, with probability
  // `elitism` it moves to a neighbor that gets closer to the exit (Manhattan distance),
  // otherwise to one that doesn't - falling back to whatever is available. Dead ends
  // are backtracked out of (and stay marked, so the walk always terminates), so the
  // stack left when the exit is reached is a simple path.
  ArrayList<int[]> carveSolutionPath(float elitism, Random rnd)
  {
    int gr = endCell[0];
    int gc = endCell[1];

    boolean[][] seen = new boolean[rows][cols];
    ArrayList<int[]> stack = new ArrayList<int[]>();
    stack.add(new int[] { startCell[0], startCell[1] });
    seen[startCell[0]][startCell[1]] = true;

    int[] toward = new int[4];
    int[] away = new int[4];

    while (true)
    {
      int[] cell = stack.get(stack.size() - 1);
      int r = cell[0];
      int c = cell[1];
      if (r == gr && c == gc)
        return stack;

      int nt = 0, na = 0;
      int dist = abs(gr - r) + abs(gc - c);
      for (int i = 0; i < 4; i++)
      {
        int nr = r + DIRS[i][0];
        int nc = c + DIRS[i][1];
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols || seen[nr][nc])
          continue;
        if (abs(gr - nr) + abs(gc - nc) < dist)
          toward[nt++] = i;
        else
          away[na++] = i;
      }

      if (nt + na == 0)
      {
        stack.remove(stack.size() - 1);
        continue;
      }

      boolean goToward = (na == 0) || (nt > 0 && rnd.nextFloat() < elitism);
      int dir = goToward ? toward[rnd.nextInt(nt)] : away[rnd.nextInt(na)];
      int nr = r + DIRS[dir][0];
      int nc = c + DIRS[dir][1];
      seen[nr][nc] = true;
      stack.add(new int[] { nr, nc });
    }
  }

  int dirBetween(int[] a, int[] b)
  {
    for (int i = 0; i < 4; i++)
      if (a[0] + DIRS[i][0] == b[0] && a[1] + DIRS[i][1] == b[1])
        return i;
    return NO_DIR;
  }

  void removeWallBetween(int r, int c, int nr, int nc)
  {
    if (nr < r)      hWalls[r][c] = false;
    else if (nr > r) hWalls[nr][c] = false;
    else if (nc < c) vWalls[r][c] = false;
    else             vWalls[r][nc] = false;
  }

  boolean isOpen(int r, int c, int dir)
  {
    int nr = r + DIRS[dir][0];
    int nc = c + DIRS[dir][1];
    if (nr < 0 || nr >= rows || nc < 0 || nc >= cols)
      return false;
    if (dir == 0) return !hWalls[r][c];
    if (dir == 1) return !hWalls[r + 1][c];
    if (dir == 2) return !vWalls[r][c];
    return !vWalls[r][c + 1];
  }

  // Emits the walls as polylines, centered on (0,0). Consecutive wall segments on the
  // same grid line are merged into a single polyline - one pen-down stroke per run
  // instead of one per cell edge, which matters a lot on a plotter.
  void buildWalls(DataMaze d, PolylineGroup out)
  {
    float cs = d.maze_cell_size;
    float x0 = -cols * cs * 0.5;
    float y0 = -rows * cs * 0.5;

    for (int r = 0; r <= rows; r++)
    {
      int c = 0;
      while (c < cols)
      {
        if (!hWalls[r][c]) { c++; continue; }
        int start = c;
        while (c < cols && hWalls[r][c]) c++;
        out.add(segment(x0 + start * cs, y0 + r * cs, x0 + c * cs, y0 + r * cs));
      }
    }

    for (int c = 0; c <= cols; c++)
    {
      int r = 0;
      while (r < rows)
      {
        if (!vWalls[r][c]) { r++; continue; }
        int start = r;
        while (r < rows && vWalls[r][c]) r++;
        out.add(segment(x0 + c * cs, y0 + start * cs, x0 + c * cs, y0 + r * cs));
      }
    }
  }

  // Shortest (in a perfect maze: the only) path from the entrance cell to the exit
  // cell, by breadth-first search, as one polyline through the cell centers - only its
  // turning points are kept, so straight runs are single segments. With openings, it
  // also runs half a cell out through the entrance and exit.
  void buildSolution(DataMaze d, PolylineGroup out)
  {
    int[][] parent = new int[rows][cols];
    for (int[] line : parent) java.util.Arrays.fill(line, -1);

    int start = startCell[0] * cols + startCell[1];
    int goal = endCell[0] * cols + endCell[1];
    int[] queue = new int[rows * cols];
    int head = 0, tail = 0;
    queue[tail++] = start;
    parent[startCell[0]][startCell[1]] = start;

    while (head < tail)
    {
      int id = queue[head++];
      if (id == goal)
        break;
      int r = id / cols;
      int c = id % cols;
      for (int dir = 0; dir < 4; dir++)
      {
        if (!isOpen(r, c, dir))
          continue;
        int nr = r + DIRS[dir][0];
        int nc = c + DIRS[dir][1];
        if (parent[nr][nc] != -1)
          continue;
        parent[nr][nc] = id;
        queue[tail++] = nr * cols + nc;
      }
    }

    if (parent[endCell[0]][endCell[1]] == -1)
      return;

    // Walk back from the goal, collecting cell ids from goal to start.
    ArrayList<Integer> path = new ArrayList<Integer>();
    for (int id = goal; ; id = parent[id / cols][id % cols])
    {
      path.add(id);
      if (id == start)
        break;
    }

    float cs = d.maze_cell_size;
    float x0 = -cols * cs * 0.5;
    float y0 = -rows * cs * 0.5;

    ArrayList<PVector> pts = new ArrayList<PVector>();
    if (d.maze_openings && startCell[2] != NO_DIR)
      pts.add(outsidePoint(startCell, x0, y0, cs));
    for (int i = path.size() - 1; i >= 0; i--)
    {
      int id = path.get(i);
      pts.add(new PVector(x0 + (id % cols + 0.5) * cs, y0 + (id / cols + 0.5) * cs));
    }
    if (d.maze_openings && endCell[2] != NO_DIR)
      pts.add(outsidePoint(endCell, x0, y0, cs));

    Polyline line = new Polyline();
    for (int i = 0; i < pts.size(); i++)
    {
      boolean endpoint = (i == 0 || i == pts.size() - 1);
      if (endpoint || !isCollinear(pts.get(i - 1), pts.get(i), pts.get(i + 1)))
        line.addPoint(pts.get(i));
    }
    out.add(line);
  }

  // Half a cell outside the maze, through the endpoint's opening.
  PVector outsidePoint(int[] e, float x0, float y0, float cs)
  {
    return new PVector(
      x0 + (e[1] + 0.5 + DIRS[e[2]][1]) * cs,
      y0 + (e[0] + 0.5 + DIRS[e[2]][0]) * cs);
  }

  boolean isCollinear(PVector a, PVector b, PVector c)
  {
    return abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) < 1e-4;
  }

  Polyline segment(float xa, float ya, float xb, float yb)
  {
    Polyline p = new Polyline();
    p.addPoint(new PVector(xa, ya));
    p.addPoint(new PVector(xb, yb));
    return p;
  }
}
