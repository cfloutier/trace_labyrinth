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

  // Growing-tree texture controls (see MazeGenerator.generate()):
  // river: 1 = always extend from the newest cell (depth-first: long winding corridors,
  // few dead ends), 0 = from a random cell (Prim-like: many short dead ends).
  float   maze_river        = 1;
  // straightness: chance of carving on in the same direction as the previous step -
  // high values give long straight runs, 0 = no directional preference.
  float   maze_straightness = 0;

  // Solution path (entrance -> exit), drawn in its own color.
  boolean maze_show_solution  = false;
  color   maze_solution_color = color(255, 60, 60);
}


class MazeGUI extends GUIPanel
{
  DataMaze maze;

  Slider maze_cols;
  Slider maze_rows;
  Slider maze_cell_size;
  Toggle maze_openings;
  Slider maze_river;
  Slider maze_straightness;
  Toggle maze_show_solution;
  Button maze_solution_color;

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
    maze_river = addSlider("maze_river", "River", 0, 1);
    maze_straightness = addSlider("maze_straightness", "Straightness", 0, 1);
    nextLine();
    maze_openings = addToggle("maze_openings", "Entrance / Exit");
    nextLine();
    addButton("New Seed").plugTo(this, "newSeed");
    nextLine();

    maze_show_solution = addToggle("maze_show_solution", "Show Solution");
    nextLine();
    // Color is read every frame when drawing - no need to flag a rebuild.
    maze_solution_color = addColorChooser("Solution Color", new ColorSetter()
    {
      public color getColor() {
        return maze.maze_solution_color;
      }
      public void setColor(color c) {
        maze.maze_solution_color = c;
      }
    }
    );
  }

  void setGUIValues()
  {
    maze_cols.setValue(maze.maze_cols);
    maze_rows.setValue(maze.maze_rows);
    maze_cell_size.setValue(maze.maze_cell_size);
    maze_openings.setValue(maze.maze_openings);
    maze_river.setValue(maze.maze_river);
    maze_straightness.setValue(maze.maze_straightness);
    maze_show_solution.setValue(maze.maze_show_solution);
    maze_solution_color.setColorBackground(maze.maze_solution_color);
  }
}
