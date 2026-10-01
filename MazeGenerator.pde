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
// When the entrance or exit is the center, it's a 3x3 open room (see carveRoom()) with
// a single door: the solution walk starts from the room, and phase 2 never grows into it.
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

  // Center endpoint (DataMaze position code) and its 3x3 "start room": an open square
  // with no inner walls, reached through a single door so the maze keeps exactly one
  // solution. Only used when the grid leaves at least one cell of corridor around it.
  static final int CENTER = 4;
  static final int ROOM_SIZE = 3;
  boolean roomActive = false;
  boolean[][] isRoom = new boolean[0][0];

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

    isRoom = new boolean[rows][cols];
    roomActive = (d.maze_start == CENTER || d.maze_end == CENTER)
      && rows >= ROOM_SIZE + 2 && cols >= ROOM_SIZE + 2;
    if (roomActive)
      carveRoom(visited);

    // Phase 1 - solution path (see class comment). With a room, the walk always starts
    // from it (swapping entrance/exit when the room is the exit - the path is the same
    // either way), so the room's single door is simply the walk's first step.
    int[] src = startCell;
    int[] dst = endCell;
    if (roomActive && d.maze_end == CENTER)
    {
      src = endCell;
      dst = startCell;
    }
    ArrayList<int[]> path = carveSolutionPath(d.maze_elitism, rnd, src, dst);

    // Phase 2 - growing tree off the path (room cells excluded, so nothing else opens a
    // second door into it). Active cells as {row, col}; newest at the end.
    ArrayList<int[]> active = new ArrayList<int[]>();
    for (int[] e : path)
    {
      visited[e[0]][e[1]] = true;
      cameFrom[e[0]][e[1]] = NO_DIR;
      if (e[2] >= 0)
      {
        removeWallBetween(e[2], e[3], e[0], e[1]);
        cameFrom[e[0]][e[1]] = dirBetween(new int[] { e[2], e[3] }, e);
      }
      if (!isRoom[e[0]][e[1]])
        active.add(new int[] { e[0], e[1] });
    }

    // Entrance = exit = center: the walk never left the room - open its door at random.
    if (roomActive && active.isEmpty())
    {
      ArrayList<int[]> doors = roomExits(visited);
      int[] m = doors.get(rnd.nextInt(doors.size()));
      removeWallBetween(m[0], m[1], m[2], m[3]);
      visited[m[2]][m[3]] = true;
      cameFrom[m[2]][m[3]] = dirBetween(m, new int[] { m[2], m[3] });
      active.add(new int[] { m[2], m[3] });
    }

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

  // Opens the ROOM_SIZE x ROOM_SIZE square around the center cell (no inner walls) and
  // marks it visited.
  void carveRoom(boolean[][] visited)
  {
    int r0 = rows / 2 - ROOM_SIZE / 2;
    int c0 = cols / 2 - ROOM_SIZE / 2;
    for (int r = r0; r < r0 + ROOM_SIZE; r++)
    {
      for (int c = c0; c < c0 + ROOM_SIZE; c++)
      {
        isRoom[r][c] = true;
        visited[r][c] = true;
        if (r + 1 < r0 + ROOM_SIZE) hWalls[r + 1][c] = false;
        if (c + 1 < c0 + ROOM_SIZE) vWalls[r][c + 1] = false;
      }
    }
  }

  // Every possible door out of the room: {roomRow, roomCol, outRow, outCol} for each
  // room cell / outside neighbor pair not yet in `seen`.
  ArrayList<int[]> roomExits(boolean[][] seen)
  {
    ArrayList<int[]> out = new ArrayList<int[]>();
    for (int r = 0; r < rows; r++)
      for (int c = 0; c < cols; c++)
      {
        if (!isRoom[r][c])
          continue;
        for (int i = 0; i < 4; i++)
        {
          int nr = r + DIRS[i][0];
          int nc = c + DIRS[i][1];
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !isRoom[nr][nc] && !seen[nr][nc])
            out.add(new int[] { r, c, nr, nc });
        }
      }
    return out;
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

  // Depth-first walk from `src` to `dst`. At each step, with probability `elitism` it
  // moves to a neighbor that gets closer to the exit (Manhattan distance), otherwise to
  // one that doesn't - falling back to whatever is available. Dead ends are backtracked
  // out of (and stay marked, so the walk always terminates), so the stack left when the
  // exit is reached is a simple path. From the room, a step can leave through any of
  // its border cells. Entries are {row, col, fromRow, fromCol} (from = -1 for the
  // first), so the walls to carve are known even for the room's door.
  ArrayList<int[]> carveSolutionPath(float elitism, Random rnd, int[] src, int[] dst)
  {
    int gr = dst[0];
    int gc = dst[1];

    boolean[][] seen = new boolean[rows][cols];
    for (int r = 0; r < rows; r++)
      for (int c = 0; c < cols; c++)
        seen[r][c] = isRoom[r][c];

    ArrayList<int[]> stack = new ArrayList<int[]>();
    stack.add(new int[] { src[0], src[1], -1, -1 });
    seen[src[0]][src[1]] = true;

    ArrayList<int[]> toward = new ArrayList<int[]>();
    ArrayList<int[]> away = new ArrayList<int[]>();

    while (true)
    {
      int[] cell = stack.get(stack.size() - 1);
      int r = cell[0];
      int c = cell[1];
      if (r == gr && c == gc)
        return stack;

      // Candidate moves as {fromRow, fromCol, toRow, toCol}.
      ArrayList<int[]> moves;
      if (isRoom[r][c])
        moves = roomExits(seen);
      else
      {
        moves = new ArrayList<int[]>();
        for (int i = 0; i < 4; i++)
        {
          int nr = r + DIRS[i][0];
          int nc = c + DIRS[i][1];
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !seen[nr][nc])
            moves.add(new int[] { r, c, nr, nc });
        }
      }

      if (moves.isEmpty())
      {
        stack.remove(stack.size() - 1);
        continue;
      }

      toward.clear();
      away.clear();
      int dist = abs(gr - r) + abs(gc - c);
      for (int[] m : moves)
      {
        if (abs(gr - m[2]) + abs(gc - m[3]) < dist)
          toward.add(m);
        else
          away.add(m);
      }

      boolean goToward = away.isEmpty() || (!toward.isEmpty() && rnd.nextFloat() < elitism);
      int[] m = goToward ? toward.get(rnd.nextInt(toward.size())) : away.get(rnd.nextInt(away.size()));
      seen[m[2]][m[3]] = true;
      stack.add(new int[] { m[2], m[3], m[0], m[1] });
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

  // Shortest (in a perfect maze: the only) path from the entrance cell to the exit
  // cell, by breadth-first search, as one polyline through the cell centers - only its
  // turning points are kept, so straight runs are single segments. With openings, it
  // also runs half a cell out through the entrance and exit.
  void buildSolution(DataMaze d, PolylineGroup out)
  {
    ArrayList<Integer> path = findSolutionPath();
    if (path == null)
      return;

    float cs = d.maze_cell_size;
    float x0 = -cols * cs * 0.5;
    float y0 = -rows * cs * 0.5;

    ArrayList<PVector> pts = new ArrayList<PVector>();
    if (d.maze_openings && startCell[2] != NO_DIR)
      pts.add(outsidePoint(startCell, x0, y0, cs));
    for (int i = path.size() - 1; i >= 0; i--)
    {
      int id = path.get(i);
      pts.add(cellCenter(id, x0, y0, cs));
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

  PVector cellCenter(int id, float x0, float y0, float cs)
  {
    return new PVector(x0 + (id % cols + 0.5) * cs, y0 + (id / cols + 0.5) * cs);
  }

  // Branch preview stats, filled by buildBranches().
  int deadEnds = 0;
  int maxBranchDepth = 0;

  // Every passage off the solution, as polylines through cell centers grouped by depth:
  // levels.get(k) holds depth k+1, where depth = how many forks you go through from the
  // solution to get there (a branch leaving the solution directly is depth 1, a branch
  // forking off it is depth 2, ...). The center room counts as part of the solution.
  // A polyline runs from the cell it branches off (fork or solution cell) through
  // single-path cells, and stops at a fork or a dead end - so each one has one depth.
  void buildBranches(DataMaze d, ArrayList<PolylineGroup> levels)
  {
    levels.clear();
    deadEnds = 0;
    maxBranchDepth = 0;

    ArrayList<Integer> path = findSolutionPath();
    if (path == null)
      return;

    float cs = d.maze_cell_size;
    float x0 = -cols * cs * 0.5;
    float y0 = -rows * cs * 0.5;

    boolean[][] done = new boolean[rows][cols];
    for (int id : path)
      done[id / cols][id % cols] = true;
    for (int r = 0; r < rows; r++)
      for (int c = 0; c < cols; c++)
        if (isRoom[r][c])
          done[r][c] = true;

    // Pending branch starts as {fromId, firstCellId, depth}.
    ArrayList<int[]> pending = new ArrayList<int[]>();
    for (int r = 0; r < rows; r++)
      for (int c = 0; c < cols; c++)
        if (done[r][c])
          addChildren(r * cols + c, 1, done, pending);

    while (!pending.isEmpty())
    {
      int[] b = pending.remove(pending.size() - 1);
      int depth = b[2];
      while (levels.size() < depth)
        levels.add(new PolylineGroup());
      maxBranchDepth = max(maxBranchDepth, depth);

      ArrayList<PVector> pts = new ArrayList<PVector>();
      pts.add(cellCenter(b[0], x0, y0, cs));
      int cur = b[1];
      while (true)
      {
        pts.add(cellCenter(cur, x0, y0, cs));
        int children = addChildren(cur, depth + 1, done, pending);
        if (children == 1)
        {
          // Single way on: keep the same polyline, same depth.
          int[] only = pending.remove(pending.size() - 1);
          cur = only[1];
          continue;
        }
        if (children == 0)
          deadEnds++;
        // children >= 2: a fork - the new entries (depth + 1) start their own polylines.
        break;
      }

      Polyline line = new Polyline();
      for (int i = 0; i < pts.size(); i++)
      {
        boolean endpoint = (i == 0 || i == pts.size() - 1);
        if (endpoint || !isCollinear(pts.get(i - 1), pts.get(i), pts.get(i + 1)))
          line.addPoint(pts.get(i));
      }
      levels.get(depth - 1).add(line);
    }
  }

  // Queues every not-yet-done open neighbor of cell `id` as a branch start at `depth`,
  // marking it done. Returns how many were queued.
  int addChildren(int id, int depth, boolean[][] done, ArrayList<int[]> pending)
  {
    int r = id / cols;
    int c = id % cols;
    int n = 0;
    for (int dir = 0; dir < 4; dir++)
    {
      if (!isOpen(r, c, dir))
        continue;
      int nr = r + DIRS[dir][0];
      int nc = c + DIRS[dir][1];
      if (done[nr][nc])
        continue;
      done[nr][nc] = true;
      pending.add(new int[] { id, nr * cols + nc, depth });
      n++;
    }
    return n;
  }

  // Cell ids of the solution, from exit back to entrance (breadth-first search; in a
  // perfect maze the one and only path), or null if there's none.
  ArrayList<Integer> findSolutionPath()
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
      return null;

    // Walk back from the goal, collecting cell ids from goal to start.
    ArrayList<Integer> path = new ArrayList<Integer>();
    for (int id = goal; ; id = parent[id / cols][id % cols])
    {
      path.add(id);
      if (id == start)
        break;
    }
    return path;
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
}
