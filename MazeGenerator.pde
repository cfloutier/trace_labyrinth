// Rectangular-grid maze carved with the "growing tree" algorithm, which generalizes the
// depth-first backtracker: a list of active cells is grown one carved passage at a
// time, and which active cell gets extended next (newest vs random - maze_river) plus
// whether a passage keeps its direction (maze_straightness) set the maze's texture.
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

  void generate(DataMaze d)
  {
    cols = max(1, d.maze_cols);
    rows = max(1, d.maze_rows);

    hWalls = new boolean[rows + 1][cols];
    vWalls = new boolean[rows][cols + 1];
    for (boolean[] line : hWalls) java.util.Arrays.fill(line, true);
    for (boolean[] line : vWalls) java.util.Arrays.fill(line, true);

    Random rnd = new Random(d.maze_seed);
    boolean[][] visited = new boolean[rows][cols];
    // Direction each cell was carved into from (NO_DIR for the start cell) - lets the
    // straightness bias keep going the same way.
    int[][] cameFrom = new int[rows][cols];

    // Active cells as {row, col}; newest at the end.
    ArrayList<int[]> active = new ArrayList<int[]>();
    visited[0][0] = true;
    cameFrom[0][0] = NO_DIR;
    active.add(new int[] { 0, 0 });

    int[] candidates = new int[4];

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
      hWalls[0][0] = false;
      hWalls[rows][cols - 1] = false;
    }
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

  // Shortest (in a perfect maze: the only) path from the top-left cell to the
  // bottom-right one, by breadth-first search, as one polyline through the cell
  // centers - only its turning points are kept, so straight runs are single segments.
  // With openings, it also runs half a cell out through the entrance and exit.
  void buildSolution(DataMaze d, PolylineGroup out)
  {
    int[][] parent = new int[rows][cols];
    for (int[] line : parent) java.util.Arrays.fill(line, -1);

    int start = 0;
    int goal = rows * cols - 1;
    int[] queue = new int[rows * cols];
    int head = 0, tail = 0;
    queue[tail++] = start;
    parent[0][0] = start;

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

    if (parent[rows - 1][cols - 1] == -1)
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
    if (d.maze_openings)
      pts.add(new PVector(x0 + cs * 0.5, y0 - cs * 0.5));
    for (int i = path.size() - 1; i >= 0; i--)
    {
      int id = path.get(i);
      pts.add(new PVector(x0 + (id % cols + 0.5) * cs, y0 + (id / cols + 0.5) * cs));
    }
    if (d.maze_openings)
      pts.add(new PVector(x0 + (cols - 0.5) * cs, y0 + (rows + 0.5) * cs));

    Polyline line = new Polyline();
    for (int i = 0; i < pts.size(); i++)
    {
      boolean endpoint = (i == 0 || i == pts.size() - 1);
      if (endpoint || !isCollinear(pts.get(i - 1), pts.get(i), pts.get(i + 1)))
        line.addPoint(pts.get(i));
    }
    out.add(line);
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
