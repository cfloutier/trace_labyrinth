// Rectangular-grid maze, carved with an iterative depth-first search ("recursive
// backtracker", explicit stack so large grids can't overflow the call stack). Uses its
// own java.util.Random seeded from DataMaze.maze_seed, so a given seed always gives the
// same maze regardless of any other random() calls in the sketch.
class MazeGenerator
{
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
    ArrayList<int[]> stack = new ArrayList<int[]>();

    visited[0][0] = true;
    stack.add(new int[] { 0, 0 });

    int[][] dirs = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }; // up, down, left, right
    int[] candidates = new int[4];

    while (!stack.isEmpty())
    {
      int[] cell = stack.get(stack.size() - 1);
      int r = cell[0];
      int c = cell[1];

      int n = 0;
      for (int i = 0; i < 4; i++)
      {
        int nr = r + dirs[i][0];
        int nc = c + dirs[i][1];
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !visited[nr][nc])
          candidates[n++] = i;
      }

      if (n == 0)
      {
        stack.remove(stack.size() - 1);
        continue;
      }

      int dir = candidates[rnd.nextInt(n)];
      int nr = r + dirs[dir][0];
      int nc = c + dirs[dir][1];
      removeWallBetween(r, c, nr, nc);
      visited[nr][nc] = true;
      stack.add(new int[] { nr, nc });
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

  Polyline segment(float xa, float ya, float xb, float yb)
  {
    Polyline p = new Polyline();
    p.addPoint(new PVector(xa, ya));
    p.addPoint(new PVector(xb, yb));
    return p;
  }
}
