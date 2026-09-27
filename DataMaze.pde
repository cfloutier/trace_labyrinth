// Maze parameters. Field names are prefixed (maze_) on purpose: ControlP5 controller
// names must stay unique across the whole sketch, even on different data objects.
class DataMaze extends GenericData
{
  DataMaze()
  {
    super("Maze");
  }

  int     maze_cols      = 20;
  int     maze_rows      = 15;
  float   maze_cell_size = 20;
  int     maze_seed      = 1;
  // Opens an entrance in the top-left cell's top wall and an exit in the bottom-right
  // cell's bottom wall.
  boolean maze_openings  = true;
}


class MazeGUI extends GUIPanel
{
  DataMaze maze;

  Slider maze_cols;
  Slider maze_rows;
  Slider maze_cell_size;
  Toggle maze_openings;

  MazeGUI(DataMaze maze)
  {
    super("Maze", maze);
    this.maze = maze;
  }

  void newSeed()
  {
    maze.maze_seed = new Random(System.currentTimeMillis()).nextInt();
    maze.changed = true;
  }

  void setupControls()
  {
    super.Init();

    maze_cols = addIntSlider("maze_cols", "Columns", 2, 200);
    maze_rows = addIntSlider("maze_rows", "Rows", 2, 200);
    nextLine();
    maze_cell_size = addSlider("maze_cell_size", "Cell Size", 2, 100);
    nextLine();
    maze_openings = addToggle("maze_openings", "Entrance / Exit");
    nextLine();
    addButton("New Seed").plugTo(this, "newSeed");
  }

  void setGUIValues()
  {
    maze_cols.setValue(maze.maze_cols);
    maze_rows.setValue(maze.maze_rows);
    maze_cell_size.setValue(maze.maze_cell_size);
    maze_openings.setValue(maze.maze_openings);
  }
}
