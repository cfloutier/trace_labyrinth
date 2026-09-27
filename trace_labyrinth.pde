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

  lineGroup.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);

  if (data.maze.maze_show_solution)
  {
    current_graphics.pushStyle();
    current_graphics.stroke(data.maze.maze_solution_color);
    solutionGroup.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);
    current_graphics.popStyle();
  }

  end_draw();

  dataGui.draw();
}

void buildLines()
{
  lineGroup.clear();
  mazeRenderer.buildWalls(maze, data.maze, data.render, lineGroup);

  solutionGroup.clear();
  maze.buildSolution(data.maze, solutionGroup);
  mazeRenderer.roundSolution(solutionGroup, data.maze, data.render);

  file_ui.updateExportScale(lineGroup.getBoundingBox(data.page.clipping, data.page.clip_width, data.page.clip_height));
}
