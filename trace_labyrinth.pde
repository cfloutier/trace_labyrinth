import controlP5.*;
import processing.pdf.*;
import processing.dxf.*;
import processing.svg.*;

LabyrinthData data;
DataGUI dataGui;

PGraphics current_graphics;
ControlP5 cp5;
ColorChooserPopup colorPopup;

PolylineGroup lineGroup = new PolylineGroup();
PolylineGroup solutionGroup = new PolylineGroup();
// Branch preview (screen only), one group per depth - see MazeGenerator.buildBranches().
ArrayList<PolylineGroup> branchLevels = new ArrayList<PolylineGroup>();
MazeGenerator maze = new MazeGenerator();
MazeRenderer mazeRenderer = new MazeRenderer();

void setup()
{
  size(1200, 800);
  pixelDensity(1);
  surface.setResizable(true);

  data = new LabyrinthData();
  dataGui = new DataGUI(data);

  setupControls();

  data.LoadSettings("./Settings/default.json");
  dataGui.setGUIValues();

  file_ui.export_group = lineGroup;  // enable direct SVG export
}

void setupControls()
{
  init_xlib();
  dataGui.Init();
}

void draw()
{
  start_draw();

  boolean maze_changed = data.maze.changed;
  boolean render_changed = data.render.changed;
  boolean page_changed = data.page.changed;
  data.reset_all_changes();

  // Render options only change how the walls are drawn - no need to regenerate.
  if (maze_changed)
    maze.generate(data.maze);
  if (maze_changed || render_changed || page_changed)
    buildLines();

  if (data.maze.maze_show_branches && !_record)
    drawBranches();

  lineGroup.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);

  if (data.maze.maze_show_solution)
  {
    current_graphics.pushStyle();
    current_graphics.stroke(data.maze.maze_solution_color);
    solutionGroup.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);
    current_graphics.popStyle();
  }

  end_draw();

  if (data.maze.maze_show_branches && !_record)
    drawBranchStats();

  dataGui.draw();
}

// Each depth in its own color, from a fixed rainbow of maze_branch_depth_scale
// distinct hues (depth 1 = first color) - so a color always means the same depth.
// Deeper than that: last color, or the rainbow restarting when cycling.
void drawBranches()
{
  current_graphics.pushStyle();
  for (int k = 0; k < branchLevels.size(); k++)
  {
    current_graphics.stroke(branchColor(k + 1));
    branchLevels.get(k).draw(data.page.clipping, data.page.clip_width, data.page.clip_height);
  }
  current_graphics.popStyle();
}

// Hues spread from yellow (60) through green, cyan and blue to magenta (300) - red is
// left out on purpose, it's the solution's default color.
color branchColor(int depth)
{
  int n = max(2, data.maze.maze_branch_depth_scale);
  int index = depth - 1;
  index = data.maze.maze_branch_cycle ? index % n : min(index, n - 1);
  float hue = 60 + 240.0 * index / (n - 1);
  pushStyle();
  colorMode(HSB, 360, 100, 100);
  color c = color(hue, 85, 100);
  popStyle();
  return c;
}

void drawBranchStats()
{
  String txt = "Dead ends: " + maze.deadEnds + "  |  max depth: " + maze.maxBranchDepth
    + "  |  " + max(2, data.maze.maze_branch_depth_scale) + " depth colors"
    + (data.maze.maze_branch_cycle ? " (cycling)" : " (last = deeper)");
  pushStyle();
  textAlign(LEFT, BOTTOM);
  textSize(13);
  float tw = textWidth(txt);
  noStroke();
  fill(0, 150);
  rect(4, height - 24, tw + 12, 20, 4);
  fill(255);
  text(txt, 10, height - 9);

  // Legend: one numbered swatch per depth color.
  int n = max(2, data.maze.maze_branch_depth_scale);
  float x = tw + 24;
  float size = 18;
  textAlign(CENTER, CENTER);
  textSize(10);
  for (int i = 0; i < n; i++)
  {
    fill(branchColor(i + 1));
    rect(x, height - 23, size, size, 3);
    fill(0);
    text(i + 1, x + size * 0.5, height - 23 + size * 0.5 - 1);
    x += size + 2;
  }
  popStyle();
}

void buildLines()
{
  lineGroup.clear();
  mazeRenderer.buildWalls(maze, data.maze, data.render, lineGroup);

  solutionGroup.clear();
  maze.buildSolution(data.maze, solutionGroup);
  mazeRenderer.roundSolution(solutionGroup, data.maze, data.render);

  maze.buildBranches(data.maze, branchLevels);

  file_ui.updateExportScale(lineGroup.getBoundingBox(data.page.clipping, data.page.clip_width, data.page.clip_height));
}
