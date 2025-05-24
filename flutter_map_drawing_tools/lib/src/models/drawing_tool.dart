/// Defines the available drawing tools and actions within the plugin.
enum DrawingTool {
  /// Tool for drawing free-form polygons.
  polygon,
  /// Tool for drawing multi-segment polylines.
  multiPolyline,
  /// Tool for drawing multi-part polygons (e.g., polygons with holes, or multiple disjoint polygons).
  multiPolygon,
  /// Tool for drawing rectangles.
  rectangle,
  /// Tool for drawing pentagons (5-sided regular polygons).
  pentagon,
  /// Tool for drawing hexagons (6-sided regular polygons).
  hexagon,
  /// Tool for drawing octagons (8-sided regular polygons).
  octagon,
  /// Tool for drawing circles.
  circle,
  /// Tool for placing point markers.
  point,
  /// Mode for selecting and editing existing shapes.
  edit, 
  /// Action to delete a selected shape (typically used from a contextual menu).
  delete, 
  /// Action to cancel the current drawing operation or deselect a tool/shape.
  cancel, 
  /// State indicating no specific tool is selected; the drawing toolbar might be in its default (e.g., collapsed) state.
  none, 
  /// Action to complete the current part of a multi-part drawing (e.g., finish the exterior ring of a polygon and start a hole).
  completePart, 
  /// Action to finalize the entire multi-part drawing (e.g., save the polygon with all its holes).
  finalizeMultiPart,
  /// Action to undo the last operation.
  undo,
  /// Action to redo the last undone operation.
  redo,
}

/// Returns a user-friendly display name for a given [DrawingTool].
///
/// This can be used for UI elements like tooltips or labels.
String drawingToolDisplayName(DrawingTool tool) {
  switch (tool) {
    case DrawingTool.polygon: return 'Polygon';
    case DrawingTool.multiPolyline: return 'Multi-Polyline';
    case DrawingTool.multiPolygon: return 'Multi-Polygon';
    case DrawingTool.rectangle: return 'Rectangle';
    case DrawingTool.pentagon: return 'Pentagon';
    case DrawingTool.hexagon: return 'Hexagon';
    case DrawingTool.octagon: return 'Octagon';
    case DrawingTool.circle: return 'Circle';
    case DrawingTool.point: return 'Point';
    case DrawingTool.edit: return 'Select/Edit';
    case DrawingTool.delete: return 'Delete';
    case DrawingTool.cancel: return 'Cancel';
    case DrawingTool.completePart: return 'Complete Part';
    case DrawingTool.finalizeMultiPart: return 'Finalize Drawing';
    case DrawingTool.undo: return 'Undo';
    case DrawingTool.redo: return 'Redo';
    case DrawingTool.none: return 'None';
    default: return ''; // Should not happen
  }
}
