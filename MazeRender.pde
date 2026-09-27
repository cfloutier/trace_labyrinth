// Turns a generated maze's walls into polylines, optionally with rounded corners.
//
// The walls form a graph on the grid's lattice points (vertex (i, j) = corner between
// cells, i in 0..rows, j in 0..cols). They're traced into long continuous strokes (few
// pen lifts on the plotter): a stroke follows its wall through plain corners and
// straight through T junctions (the T's bar), and stops at wall tips, at a T's stem and
// - unless junctions are sharp - at + crossings.
//
// With rounded corners (radius r = fraction of a cell), each L turn inside a stroke is
// replaced by a quarter circle; with rounded junctions, a stroke ending at a T or +
// stops r short of it and quarter-circle fillets join each pair of perpendicular arms,
// tangent to both - so walls keep touching and the maze's structure is unchanged.
// r <= half a cell and every wall run is at least one cell long, so arcs never overlap.
class MazeRenderer
{
  static final int ARC_SEGMENTS = 8;
  // up, down, left, right as {dRow, dCol} - same order as MazeGenerator.DIRS
  final int[][] DIRS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } };

  MazeGenerator g;
  boolean[][] hUsed;
  boolean[][] vUsed;
  float r;           // corner radius, drawing units (0 = sharp)
  boolean roundJunctions;
  float cs, x0, y0;

  void buildWalls(MazeGenerator gen, DataMaze maze, DataRender render, PolylineGroup out)
  {
    g = gen;
    cs = maze.maze_cell_size;
    x0 = -g.cols * cs * 0.5;
    y0 = -g.rows * cs * 0.5;
    r = render.render_round_corners ? constrain(render.render_corner_radius, 0, 0.5) * cs : 0;
    roundJunctions = r > 0 && render.render_junction == DataRender.JUNCTION_ROUNDED;

    hUsed = new boolean[g.rows + 1][g.cols];
    vUsed = new boolean[g.rows][g.cols + 1];

    for (int i = 0; i <= g.rows; i++)
      for (int j = 0; j <= g.cols; j++)
        for (int dir = 0; dir < 4; dir++)
          if (hasEdge(i, j, dir) && !isUsed(i, j, dir))
            traceStroke(i, j, dir, out);

    if (roundJunctions)
      for (int i = 0; i <= g.rows; i++)
        for (int j = 0; j <= g.cols; j++)
          addJunctionFillets(i, j, out);
  }

  // Rounds the solution path's corners with the same radius (it runs through cell
  // centers, so its runs are at least one cell long too).
  void roundSolution(PolylineGroup solution, DataMaze maze, DataRender render)
  {
    float rs = render.render_round_corners ? constrain(render.render_corner_radius, 0, 0.5) * maze.maze_cell_size : 0;
    if (rs <= 0)
      return;
    for (int k = 0; k < solution.polylines.size(); k++)
    {
      Polyline p = solution.polylines.get(k);
      solution.polylines.set(k, roundPolyline(p.points, rs, false));
    }
  }

  // --- wall graph ---------------------------------------------------------------

  boolean hasEdge(int i, int j, int dir)
  {
    if (dir == 0) return i > 0 && g.vWalls[i - 1][j];
    if (dir == 1) return i < g.rows && g.vWalls[i][j];
    if (dir == 2) return j > 0 && g.hWalls[i][j - 1];
    return j < g.cols && g.hWalls[i][j];
  }

  boolean isUsed(int i, int j, int dir)
  {
    if (dir == 0) return vUsed[i - 1][j];
    if (dir == 1) return vUsed[i][j];
    if (dir == 2) return hUsed[i][j - 1];
    return hUsed[i][j];
  }

  void markUsed(int i, int j, int dir)
  {
    if (dir == 0) vUsed[i - 1][j] = true;
    else if (dir == 1) vUsed[i][j] = true;
    else if (dir == 2) hUsed[i][j - 1] = true;
    else hUsed[i][j] = true;
  }

  int degree(int i, int j)
  {
    int n = 0;
    for (int dir = 0; dir < 4; dir++)
      if (hasEdge(i, j, dir))
        n++;
    return n;
  }

  // Direction a stroke arriving at (i, j) while traveling `dir` continues in, or -1 to
  // stop there (see class comment).
  int continueDir(int i, int j, int dir)
  {
    int deg = degree(i, j);
    int next = -1;
    if (deg == 2)
    {
      for (int d = 0; d < 4; d++)
        if (d != (dir ^ 1) && hasEdge(i, j, d))
          next = d;
    }
    else if (deg == 3 || (deg == 4 && !roundJunctions))
    {
      if (hasEdge(i, j, dir))
        next = dir;
    }
    if (next >= 0 && isUsed(i, j, next))
      return -1;
    return next;
  }

  // Traces the whole stroke containing edge (i, j, dir): forward from its far end, then
  // backward from (i, j) - unless the forward walk came back around (closed loop).
  void traceStroke(int i, int j, int dir, PolylineGroup out)
  {
    ArrayList<int[]> fwd = new ArrayList<int[]>();
    fwd.add(new int[] { i, j });
    markUsed(i, j, dir);
    int ci = i + DIRS[dir][0], cj = j + DIRS[dir][1];
    fwd.add(new int[] { ci, cj });
    int d = dir;
    while (true)
    {
      int next = continueDir(ci, cj, d);
      if (next < 0)
        break;
      markUsed(ci, cj, next);
      ci += DIRS[next][0];
      cj += DIRS[next][1];
      d = next;
      fwd.add(new int[] { ci, cj });
    }

    // Only a genuine loop if it came back to a plain (degree-2) corner - returning to a
    // junction is just a stroke whose two ends meet there.
    boolean closed = (ci == i && cj == j && degree(i, j) == 2);

    ArrayList<int[]> pts = new ArrayList<int[]>();
    if (!closed)
    {
      ArrayList<int[]> back = new ArrayList<int[]>();
      ci = i;
      cj = j;
      d = dir ^ 1;
      while (true)
      {
        int next = continueDir(ci, cj, d);
        if (next < 0)
          break;
        markUsed(ci, cj, next);
        ci += DIRS[next][0];
        cj += DIRS[next][1];
        d = next;
        back.add(new int[] { ci, cj });
      }
      for (int k = back.size() - 1; k >= 0; k--)
        pts.add(back.get(k));
    }
    pts.addAll(fwd);

    ArrayList<PVector> world = new ArrayList<PVector>();
    for (int[] p : pts)
      world.add(vertexPos(p[0], p[1]));

    if (!closed && roundJunctions)
    {
      int[] a = pts.get(0);
      int[] b = pts.get(pts.size() - 1);
      if (degree(a[0], a[1]) >= 3) shortenEnd(world, true);
      if (degree(b[0], b[1]) >= 3) shortenEnd(world, false);
    }

    out.add(roundPolyline(world, r, closed));
  }

  PVector vertexPos(int i, int j)
  {
    return new PVector(x0 + j * cs, y0 + i * cs);
  }

  // Pulls a stroke's first (or last) point back by r along its first (last) segment.
  void shortenEnd(ArrayList<PVector> pts, boolean first)
  {
    PVector end = first ? pts.get(0) : pts.get(pts.size() - 1);
    PVector nb = first ? pts.get(1) : pts.get(pts.size() - 2);
    PVector dirv = PVector.sub(nb, end);
    dirv.normalize();
    end.add(PVector.mult(dirv, r));
  }

  // Fillets at a T / + junction (rounded junction mode): a quarter circle between each
  // pair of perpendicular arms, from r along one arm to r along the other. A T's two bar
  // arms are opposite, so they get none - the bar stays a straight line through.
  void addJunctionFillets(int i, int j, PolylineGroup out)
  {
    if (degree(i, j) < 3)
      return;
    PVector v = vertexPos(i, j);
    int[][] pairs = { { 0, 3 }, { 3, 1 }, { 1, 2 }, { 2, 0 } }; // up-right, right-down, down-left, left-up
    for (int[] pr : pairs)
    {
      if (!hasEdge(i, j, pr[0]) || !hasEdge(i, j, pr[1]))
        continue;
      PVector a = new PVector(DIRS[pr[0]][1], DIRS[pr[0]][0]);
      PVector b = new PVector(DIRS[pr[1]][1], DIRS[pr[1]][0]);
      Polyline arc = new Polyline();
      appendArc(arc, PVector.add(v, PVector.mult(a, r)), PVector.add(v, PVector.mult(b, r)),
        PVector.add(v, PVector.add(PVector.mult(a, r), PVector.mult(b, r))));
      out.add(arc);
    }
  }

  // --- geometry -------------------------------------------------------------------

  // Polyline through `pts` with collinear points dropped and every remaining interior
  // corner replaced by a quarter-ish arc of radius `rad` (rad = 0: sharp corners).
  // A closed loop is re-opened at the middle of its first segment so every real corner
  // is interior.
  Polyline roundPolyline(ArrayList<PVector> in, float rad, boolean closed)
  {
    ArrayList<PVector> pts = new ArrayList<PVector>();
    if (closed)
    {
      // in = [p0, p1, ..., p_{n-1}, p0] -> mid(p0,p1), p1, ..., p_{n-1}, p0, mid(p0,p1)
      PVector mid = PVector.lerp(in.get(0), in.get(1), 0.5);
      pts.add(mid);
      for (int k = 1; k < in.size(); k++)
        pts.add(in.get(k));
      pts.add(mid.copy());
    }
    else
      pts.addAll(in);

    ArrayList<PVector> corners = new ArrayList<PVector>();
    for (int k = 0; k < pts.size(); k++)
    {
      boolean endpoint = (k == 0 || k == pts.size() - 1);
      if (endpoint || !collinear(pts.get(k - 1), pts.get(k), pts.get(k + 1)))
        corners.add(pts.get(k));
    }

    Polyline line = new Polyline();
    line.addPoint(corners.get(0));
    for (int k = 1; k < corners.size() - 1; k++)
    {
      PVector p = corners.get(k);
      if (rad <= 0)
      {
        line.addPoint(p);
        continue;
      }
      PVector u = PVector.sub(p, corners.get(k - 1));
      u.normalize();
      PVector w = PVector.sub(corners.get(k + 1), p);
      w.normalize();
      PVector a = PVector.sub(p, PVector.mult(u, rad));
      PVector b = PVector.add(p, PVector.mult(w, rad));
      PVector center = PVector.add(a, PVector.mult(w, rad));
      appendArc(line, a, b, center);
    }
    line.addPoint(corners.get(corners.size() - 1));
    return line;
  }

  // Appends the arc from a to b around `center` (shortest way round), a and b included.
  void appendArc(Polyline line, PVector a, PVector b, PVector center)
  {
    float a0 = atan2(a.y - center.y, a.x - center.x);
    float a1 = atan2(b.y - center.y, b.x - center.x);
    float delta = a1 - a0;
    while (delta > PI) delta -= TWO_PI;
    while (delta < -PI) delta += TWO_PI;
    float rad = PVector.dist(a, center);
    for (int s = 0; s <= ARC_SEGMENTS; s++)
    {
      float t = a0 + delta * s / ARC_SEGMENTS;
      line.addPoint(new PVector(center.x + cos(t) * rad, center.y + sin(t) * rad));
    }
  }

  boolean collinear(PVector a, PVector b, PVector c)
  {
    return abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) < 1e-4;
  }
}
