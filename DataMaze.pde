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
  // Entrance / exit positions on a 3x3 layout, row-major: 0 = top left, 1 = top,
  // 2 = top right, 3 = left, 4 = center, 5 = right, 6 = bottom left, 7 = bottom,
  // 8 = bottom right (see MazeGenerator.endpoint()).
  int     maze_start     = 0;
  int     maze_end       = 8;
  // Opens the entrance / exit in the outer wall (not for the center, which has none).
  boolean maze_openings  = true;

  // Same two knobs as mazegenerator.net (see MazeGenerator's class comment):
  // elitism (E): 1 = short, direct solution; 0 = long solution wandering through much
  // of the maze.
  float   maze_elitism      = 0.5;
  // river (R): 1 = few but long dead ends (the rest grows depth-first from the newest
  // cell), 0 = many short dead ends (grows from a random cell, Prim-like).
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
  myRadioButton maze_start;
  myRadioButton maze_end;
  Slider maze_elitism;
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

    addButton("New Seed").plugTo(this, "newSeed");

    nextLine();
    maze_cols = addIntSlider("maze_cols", "Columns", 2, 500);
    maze_rows = addIntSlider("maze_rows", "Rows", 2, 500);
    maze_cell_size = addSlider("maze_cell_size", "Cell Size", 2, 20);

    nextLine();
    maze_elitism = addSlider("maze_elitism", "Elitism (E)", 0, 1);
    maze_river = addSlider("maze_river", "River (R)", 0, 1);
    nextLine();
    maze_straightness = addSlider("maze_straightness", "Straightness", 0, 1);
    nextLine();
        nextLine();
    maze_openings = addToggle("maze_openings", "Entrance / Exit");
    nextLine();

    // Start and End as two compact 3x3 grids side by side, labeled inline.
    float gridTop = yPos;
    inlineLabel("Start", 40);
    maze_start = addPositionGrid("maze_start");
    yPos = gridTop;
    xPos = StartX + 40 + GRID_WIDTH + 30;
    inlineLabel("End", 30);
    maze_end = addPositionGrid("maze_end");
    xPos = StartX;
    yPos = gridTop + 3 * (heightCtrl + GRID_SPACING);

    nextLine();

    maze_show_solution = addToggle("maze_show_solution", "Show Solution");
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

  static final int GRID_BUTTON = 30;
  static final int GRID_SPACING = 2;
  static final int GRID_WIDTH = 3 * GRID_BUTTON + 2 * GRID_SPACING;

  // A radio of the 9 positions laid out as a compact 3x3 grid, labeled with compass
  // points (item order = DataMaze's maze_start/maze_end codes; C = center).
  myRadioButton addPositionGrid(String field)
  {
    ArrayList<String> labels = new ArrayList<String>();
    String[] names = { "NW", "N", "NE", "W", "C", "E", "SW", "S", "SE" };
    for (String n : names)
      labels.add(n);

    myRadioButton radio = addRadio(field, labels, maze, GRID_BUTTON);
    radio.setItemsPerRow(3);
    radio.setSpacingColumn(GRID_SPACING);
    radio.setSpacingRow(GRID_SPACING);
    return radio;
  }

  void setGUIValues()
  {
    maze_start.activate(maze.maze_start);
    maze_end.activate(maze.maze_end);
    maze_cols.setValue(maze.maze_cols);
    maze_rows.setValue(maze.maze_rows);
    maze_cell_size.setValue(maze.maze_cell_size);
    maze_openings.setValue(maze.maze_openings);
    maze_elitism.setValue(maze.maze_elitism);
    maze_river.setValue(maze.maze_river);
    maze_straightness.setValue(maze.maze_straightness);
    maze_show_solution.setValue(maze.maze_show_solution);
    maze_solution_color.setColorBackground(maze.maze_solution_color);
  }
}
