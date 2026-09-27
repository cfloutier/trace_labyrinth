class LabyrinthData extends DataGlobal
{
  Style style = new Style();
  DataMaze maze = new DataMaze();
  DataRender render = new DataRender();

  LabyrinthData()
  {
    addChapter(style);
    addChapter(maze);
    addChapter(render);
  }

  void reset()
  {
    style.CopyFrom(new Style());
    maze.CopyFrom(new DataMaze());
    render.CopyFrom(new DataRender());
  }
}
