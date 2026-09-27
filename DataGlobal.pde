class LabyrinthData extends DataGlobal
{
  Style style = new Style();
  DataMaze maze = new DataMaze();

  LabyrinthData()
  {
    addChapter(style);
    addChapter(maze);
  }

  void reset()
  {
    style.CopyFrom(new Style());
    maze.CopyFrom(new DataMaze());
  }
}
