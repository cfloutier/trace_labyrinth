// Rendering options (how the maze's walls are drawn - not its structure). Field names
// are prefixed (render_) to keep ControlP5 controller names unique sketch-wide.
class DataRender extends GenericData
{
  static final int JUNCTION_SHARP = 0;
  static final int JUNCTION_ROUNDED = 1;

  DataRender()
  {
    super("Render");
  }

  // Rounds every wall corner (L-shaped turns) with a quarter circle.
  boolean render_round_corners = false;
  // Corner radius as a fraction of the cell size (0..0.5 - at most half a cell, so two
  // rounded corners on the same wall segment can never overlap).
  float   render_corner_radius = 0.3;
  // How T and + wall junctions are drawn when corners are rounded:
  // sharp = the branch meets the wall straight on; rounded = the branch splits into two
  // fillets tangent to the wall on each side (a + becomes 4 fillets between its arms).
  int     render_junction = JUNCTION_ROUNDED;
}


class RenderGUI extends GUIPanel
{
  DataRender render;

  Toggle render_round_corners;
  Slider render_corner_radius;
  myRadioButton render_junction;

  RenderGUI(DataRender render)
  {
    super("Render", render);
    this.render = render;
  }

  void setupControls()
  {
    super.Init();

    render_round_corners = addToggle("render_round_corners", "Round Corners");
    nextLine();
    render_corner_radius = addSlider("render_corner_radius", "Corner Radius", 0, 0.5);
    nextLine();

    inlineLabel("Junctions", 70);
    ArrayList<String> junctions = new ArrayList<String>();
    junctions.add("Sharp");
    junctions.add("Rounded");
    render_junction = addRadio("render_junction", junctions);
  }

  void setGUIValues()
  {
    render_round_corners.setValue(render.render_round_corners);
    render_corner_radius.setValue(render.render_corner_radius);
    render_junction.activate(render.render_junction);
  }
}
