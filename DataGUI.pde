import controlP5.*;

class DataGUI extends MainPanel
{
  LabyrinthData data;
  FileGUI  file_ui;
  StyleGUI style_ui;
  MazeGUI  maze_ui;

  public DataGUI(LabyrinthData data)
  {
    this.data = data;
    file_ui  = new FileGUI(data, true);
    style_ui = new StyleGUI(data.style);
    maze_ui  = new MazeGUI(data.maze);
  }

  void Init()
  {
    addTab(file_ui);
    addTab(style_ui);
    addTab(maze_ui);

    super.Init();

    cp5.getTab("Maze").bringToFront();
  }
}
