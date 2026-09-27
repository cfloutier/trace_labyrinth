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
MazeGenerator maze = new MazeGenerator();

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
  boolean page_changed = data.page.changed;
  data.reset_all_changes();

  if (maze_changed || page_changed)
    buildLines();

  lineGroup.draw(data.page.clipping, data.page.clip_width, data.page.clip_height);

  end_draw();

  dataGui.draw();
}

void buildLines()
{
  maze.generate(data.maze);

  lineGroup.clear();
  maze.buildWalls(data.maze, lineGroup);

  file_ui.updateExportScale(lineGroup.getBoundingBox(data.page.clipping, data.page.clip_width, data.page.clip_height));
}
