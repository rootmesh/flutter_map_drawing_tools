import 'package:flutter/foundation.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart'; 

/// {@template shape_data}
/// Base abstract class for all shape data models.
///
/// Each specific shape type (e.g., polygon, circle) will extend this class
/// to store its geometric data and provide common functionalities.
/// {@endtemplate}
abstract class ShapeData {
  /// {@macro shape_data}
  ShapeData({String? id}) : id = id ?? const Uuid().v4();

  /// A unique identifier for the shape.
  /// Automatically generated if not provided.
  final String id;

  /// Calculates and returns the centroid (geometric center) of the shape.
  /// Must be implemented by subclasses.
  LatLng get centroid;

  /// Creates and returns a deep copy of this shape data object.
  /// Must be implemented by subclasses.
  ShapeData copy();

  /// The rotation angle of the shape in radians, around its centroid.
  /// Defaults to 0.0.
  double get rotationAngle => 0.0; // Base implementation, subclasses should override if they store it

  /// Returns a new instance of the shape with the given rotation angle.
  /// Subclasses should override this to handle actual rotation.
  ShapeData copyWithRotation(double newRotationAngle) {
    // Base implementation might just return a copy if rotation is not applicable.
    // Or throw UnimplementedError if subclasses are expected to always implement.
    return copy(); 
  }
}

/// {@template edit_mode}
/// Defines the specific editing operation being performed on a selected shape.
/// {@endtemplate}
enum EditMode { 
  /// No specific edit operation is active.
  none, 
  /// The selected shape is being moved.
  moving, 
  /// The selected shape is being rotated.
  rotating, 
  /// The selected shape is being rescaled.
  scaling, 
  /// The vertices of the selected shape (polygon or polyline) are being edited.
  vertexEditing 
}

/// {@template drawing_state}
/// Manages the overall state of the drawing tools plugin.
///
/// This includes the currently selected tool, active drawing operations,
/// the list of all drawn shapes, selection status, and editing modes.
/// It extends [ChangeNotifier] to allow widgets to listen for state updates.
/// {@endtemplate}
class DrawingState extends ChangeNotifier {
  /// {@macro drawing_state}

  DrawingTool _currentTool = DrawingTool.none;
  /// The currently selected drawing tool or action.
  /// See [DrawingTool] for available options.
  DrawingTool get currentTool => _currentTool;

  bool _isDrawing = false; 
  /// Indicates if a single-gesture drawing operation (e.g., for circles, rectangles, points) is active.
  /// For multi-part shapes like polygons/polylines, see [isMultiPartDrawingInProgress].
  bool get isDrawing => _isDrawing;

  // Temporary state for single-gesture shape creation
  LatLng? _firstPoint; 
  /// The first point defined by the user for a two-point shape (e.g., rectangle, or center of a regular polygon/circle).
  LatLng? get firstPoint => _firstPoint;
  LatLng? _currentDragPoint; 
  /// The current pointer position during a drag operation for creating two-point shapes.
  LatLng? get currentDragPoint => _currentDragPoint;
  List<LatLng> _temporaryPolygonPoints = []; 
  /// Holds the vertices of a temporary polygon shape being actively drawn (e.g., rectangle preview).
  List<LatLng> get temporaryPolygonPoints => _temporaryPolygonPoints;
  /// Sets the points for the temporary polygon preview. Internal use, typically by [DrawingLayer].
  set temporaryPolygonPoints(List<LatLng> points) { _temporaryPolygonPoints = points; }

  LatLng? _circleCenter;
  /// The center point of a circle being drawn.
  LatLng? get circleCenter => _circleCenter;
  double? _circleRadius; 
  /// The radius (in meters) of a circle being drawn.
  double? get circleRadius => _circleRadius;

  // State for selected shape and its editing
  String? _selectedShapeId;
  /// The ID of the currently selected shape. `null` if no shape is selected.
  String? get selectedShapeId => _selectedShapeId;
  DrawingTool? _selectedShapeType; 
  /// The [DrawingTool] type corresponding to the selected shape (e.g., [DrawingTool.polygon], [DrawingTool.circle]).
  /// This helps determine available editing operations.
  DrawingTool? get selectedShapeType => _selectedShapeType;
  LatLng? _contextualToolbarPosition;
  /// The geographic position where the contextual editing toolbar should be displayed for the selected shape.
  LatLng? get contextualToolbarPosition => _contextualToolbarPosition;

  EditMode _activeEditMode = EditMode.none;
  /// The currently active editing mode (e.g., moving, rotating) for the selected shape.
  /// See [EditMode].
  EditMode get activeEditMode => _activeEditMode;

  LatLng? _dragStartLatLng; 
  /// The starting [LatLng] of a drag operation during shape editing (move, rotate, scale).
  LatLng? get dragStartLatLng => _dragStartLatLng; 
  ShapeData? _originalShapeDataBeforeDrag; 
  /// A copy of the selected shape's data before an edit operation (drag) started.
  /// Used to revert changes if the operation is canceled or to calculate transformations.
  ShapeData? get originalShapeDataBeforeDrag => _originalShapeDataBeforeDrag; 

  // Master list of all shapes
  final List<ShapeData> _currentShapes = [];
  /// An unmodifiable list of all shapes currently managed by the drawing tools.
  List<ShapeData> get currentShapes => List.unmodifiable(_currentShapes);

  // --- Multi-part drawing state ---
  List<List<LatLng>> _currentDrawingParts = [];
  /// A list of point lists, where each inner list represents a part of a multi-part shape
  /// (e.g., the exterior ring and hole rings of a polygon, or segments of a multi-segment polyline).
  /// The last list is the currently active part being drawn.
  List<List<LatLng>> get currentDrawingParts => List.unmodifiable(_currentDrawingParts);

  DrawingTool? _activeMultiPartTool;
  /// The [DrawingTool] (e.g., [DrawingTool.polygon], [DrawingTool.polyline])
  /// currently being used for a multi-part drawing operation.
  DrawingTool? get activeMultiPartTool => _activeMultiPartTool;

  /// Indicates if a multi-part drawing (polygon or polyline) is currently in progress.
  bool get isMultiPartDrawingInProgress => _currentDrawingParts.isNotEmpty && _activeMultiPartTool != null;
  // --- End of Multi-part drawing state ---

  /// Adds a single [ShapeData] object to the list of current shapes.
  /// Notifies listeners.
  void addShape(ShapeData shape) { _currentShapes.add(shape); notifyListeners(); }
  
  /// Adds a list of [ShapeData] objects to the list of current shapes.
  /// Useful for bulk additions, like after a GeoJSON import.
  /// Notifies listeners.
  void addShapes(List<ShapeData> shapes) { _currentShapes.addAll(shapes); notifyListeners(); }
  
  /// Removes a shape from the list by its [id].
  /// If the removed shape was selected, it also deselects it.
  /// Notifies listeners.
  void removeShapeById(String id) { _currentShapes.removeWhere((shape) => shape.id == id); if (selectedShapeId == id) { deselectShape(); } else { notifyListeners(); } }
  
  /// Updates an existing shape in the list. The shape is identified by its `id`.
  /// If a shape with the given ID is found, it's replaced with [updatedShape].
  /// Notifies listeners.
  void updateShape(ShapeData updatedShape) { int index = _currentShapes.indexWhere((shape) => shape.id == updatedShape.id); if (index != -1) { _currentShapes[index] = updatedShape; notifyListeners(); } }
  
  /// Finds and returns a shape by its [id] from the list of current shapes.
  /// Returns `null` if no shape with the given ID is found.
  ShapeData? findShapeById(String id) { try { return _currentShapes.firstWhere((shape) => shape.id == id); } catch (e) { return null; } }

  /// Sets the active editing mode (e.g., moving, rotating).
  /// Notifies listeners.
  void setActiveEditMode(EditMode mode) { _activeEditMode = mode; notifyListeners(); }
  
  /// Stores the starting latitude/longitude and a copy of the current shape's data
  /// at the beginning of a drag-based editing operation (move, rotate, scale).
  ///
  /// - `latlng`: The geographical coordinate where the drag started.
  /// - `currentShape`: A copy of the [ShapeData] of the shape *before* this specific drag sequence begins.
  ///   This is often a `_draftShapeData` from `DrawingLayer`.
  void setDragStart(LatLng latlng, ShapeData currentShape) { _dragStartLatLng = latlng; _originalShapeDataBeforeDrag = currentShape; notifyListeners(); }
  
  /// Clears the stored drag start information. Called after an edit is confirmed or canceled.
  /// Notifies listeners.
  void clearDrag() { _dragStartLatLng = null; _originalShapeDataBeforeDrag = null; notifyListeners(); }
  
  /// Selects a shape for editing.
  ///
  /// - `id`: The unique ID of the shape to select.
  /// - `type`: The [DrawingTool] type of the selected shape.
  /// - `position`: The geographic position related to the selection (e.g., centroid), used for placing the contextual toolbar.
  ///
  /// This method also sets [currentTool] to [DrawingTool.edit] and clears any ongoing multi-part drawing.
  /// Notifies listeners.
  void selectShape(String id, DrawingTool type, LatLng position) { _selectedShapeId = id; _selectedShapeType = type; _contextualToolbarPosition = position; setActiveEditMode(EditMode.none); _currentTool = DrawingTool.edit; _isDrawing = false; clearDrawingParts(); notifyListeners(); }
  
  /// Deselects any currently selected shape and resets editing states.
  /// Also clears any ongoing multi-part drawing.
  /// Notifies listeners.
  void deselectShape() { _selectedShapeId = null; _selectedShapeType = null; _contextualToolbarPosition = null; setActiveEditMode(EditMode.none); if (_currentTool == DrawingTool.edit) { _currentTool = DrawingTool.none; } clearDrag(); clearDrawingParts(); notifyListeners(); }

  /// Sets the center point for a circle being drawn. Resets the radius.
  void setCircleCenter(LatLng? center) { _circleCenter = center; _circleRadius = null; notifyListeners(); }
  /// Sets the radius (in meters) for a circle being drawn.
  void setCircleRadius(double? radius) { _circleRadius = radius; notifyListeners(); }
  /// Clears temporary data related to drawing a circle.
  void clearTemporaryCircle() { _circleCenter = null; _circleRadius = null; notifyListeners(); }
  
  /// Sets the first point for drawing two-point shapes like rectangles or regular polygons.
  void setFirstPoint(LatLng? point) { _firstPoint = point; _currentDragPoint = null; _temporaryPolygonPoints.clear(); notifyListeners(); }
  /// Sets the current drag point for drawing two-point shapes, triggering recalculation of temporary polygon points.
  void setCurrentDragPoint(LatLng? point) { _currentDragPoint = point; if (_firstPoint != null && _currentDragPoint != null) { _calculateTemporaryPolygonPoints(); } notifyListeners(); }
  /// Clears temporary data related to drawing two-point shapes.
  void clearTemporaryPoints() {  _firstPoint = null; _currentDragPoint = null; _temporaryPolygonPoints.clear(); notifyListeners(); }
  // Internal helper, not typically part of public API documentation.
  void _calculateTemporaryPolygonPoints() { if (_firstPoint == null || _currentDragPoint == null) { if (_temporaryPolygonPoints.isNotEmpty) { _temporaryPolygonPoints.clear(); } return; } _temporaryPolygonPoints = [_firstPoint!, _currentDragPoint!]; }

  // --- Multi-part drawing methods ---
  /// Starts a new multi-part drawing session (for polygons or polylines).
  ///
  /// - `tool`: The type of multi-part shape to draw ([DrawingTool.polygon] or [DrawingTool.polyline]).
  ///
  /// Clears any previous multi-part data and initializes for a new shape.
  /// Sets [isDrawing] to `false` as multi-part progress is tracked by [isMultiPartDrawingInProgress].
  /// Notifies listeners.
  void startNewDrawingPart(DrawingTool tool) {
    clearDrawingParts(); 
    _activeMultiPartTool = tool;
    _currentDrawingParts.add([]); 
    _isDrawing = false; 
    notifyListeners();
  }

  /// Adds a point to the currently active part of a multi-part drawing.
  /// Notifies listeners.
  void addPointToCurrentPart(LatLng point) {
    if (_currentDrawingParts.isNotEmpty && _activeMultiPartTool != null) {
      _currentDrawingParts.last.add(point);
      notifyListeners();
    }
  }
  
  /// Completes the currently active part of a multi-part drawing and starts a new empty part.
  /// This is used, for example, to finish the exterior ring of a polygon and start drawing a hole,
  /// or to finish one segment of a multi-segment polyline.
  /// Notifies listeners.
  void completeCurrentPart() {
    if (_currentDrawingParts.isNotEmpty && _currentDrawingParts.last.isNotEmpty) {
      bool canComplete = true; // Basic validation can be added here if needed
      if (canComplete) {
        _currentDrawingParts.add([]); 
        notifyListeners();
      }
    }
  }

  /// Updates the last (active) part of the current multi-part drawing with a new list of points.
  /// This is crucial for reflecting changes from PolyEditor back into the DrawingState.
  /// Notifies listeners.
  void updateLastPart(List<LatLng> points) {
    if (_currentDrawingParts.isNotEmpty) {
      _currentDrawingParts.last = List.from(points); // Ensure it's a new list instance
      notifyListeners();
    }
  }

  /// Retrieves the completed drawing parts and clears them from the state.
  /// Used by [DrawingLayer] when finalizing a multi-part shape.
  /// Notifies listeners after clearing.
  /// Returns a list of point lists, representing the completed parts.
  List<List<LatLng>> consumeDrawingParts() {
    final parts = List<List<LatLng>>.from(_currentDrawingParts.where((part) => part.isNotEmpty));
    clearDrawingParts(); 
    return parts;
  }

  /// Clears all data related to an ongoing multi-part drawing.
  /// Notifies listeners if state was changed.
  void clearDrawingParts() {
    if (_currentDrawingParts.isNotEmpty || _activeMultiPartTool != null) {
      _currentDrawingParts.clear();
      _activeMultiPartTool = null;
      notifyListeners();
    }
  }

  // Use with caution, primarily for undo/redo commands to restore state.
  void dangerouslySetCurrentDrawingParts(List<List<LatLng>> parts, DrawingTool? tool) {
    _currentDrawingParts = List.from(parts.map((part) => List.from(part))); // Ensure deep copy
    _activeMultiPartTool = tool;
    notifyListeners();
  }

  /// Removes the last point from the currently active part of a multi-part drawing.
  /// Notifies listeners if a point was removed.
  void removeLastPointFromCurrentPart() {
    if (_currentDrawingParts.isNotEmpty && _currentDrawingParts.last.isNotEmpty) {
      _currentDrawingParts.last.removeLast();
      notifyListeners();
    }
  }
  // --- End of Multi-part drawing methods ---

  /// Sets the current drawing tool or action.
  ///
  /// This method manages transitions between different tools and states,
  /// including clearing ongoing multi-part drawings or temporary shape data
  /// if a new, unrelated tool is selected. It also handles special actions
  /// like [DrawingTool.completePart] and [DrawingTool.cancel].
  /// Notifies listeners.
  void setCurrentTool(DrawingTool tool) {
    if (_currentTool != tool) {
      bool isContinuingMultiPart = tool == _activeMultiPartTool || tool == DrawingTool.completePart || tool == DrawingTool.finalizeMultiPart;
      if (!isContinuingMultiPart && tool != DrawingTool.none && tool != DrawingTool.cancel && tool != DrawingTool.edit) { if (isMultiPartDrawingInProgress) { clearDrawingParts(); } }
      if (_activeMultiPartTool != null && !isContinuingMultiPart && tool != DrawingTool.edit) { clearDrawingParts(); }

      _currentTool = tool;
      _isDrawing = tool != DrawingTool.none && tool != DrawingTool.edit && tool != DrawingTool.delete && tool != DrawingTool.cancel && tool != DrawingTool.completePart && tool != DrawingTool.finalizeMultiPart && !isMultiPartDrawingInProgress; 

      if (tool == DrawingTool.edit) { _isDrawing = false; } 
      else if (tool == DrawingTool.polygon || tool == DrawingTool.polyline) { _isDrawing = false; }

      if (_isDrawing || tool == DrawingTool.edit) { if (selectedShapeId != null && tool != DrawingTool.edit) { _selectedShapeId = null; _selectedShapeType = null; _contextualToolbarPosition = null; setActiveEditMode(EditMode.none); clearDrag(); } }
      
      if (tool == DrawingTool.completePart) { completeCurrentPart(); _currentTool = _activeMultiPartTool ?? DrawingTool.none; } 
      else if (tool == DrawingTool.finalizeMultiPart) { /* Finalization handled by DrawingLayer */ } 
      else if (tool == DrawingTool.cancel) { clearDrawingParts(); clearTemporaryPoints(); clearTemporaryCircle(); if (selectedShapeId != null) deselectShape(); _currentTool = DrawingTool.none; }

      if (tool != DrawingTool.rectangle && tool != DrawingTool.pentagon && tool != DrawingTool.hexagon && tool != DrawingTool.octagon) { clearTemporaryPoints(); }
      if (tool != DrawingTool.circle) { clearTemporaryCircle(); }
      
      notifyListeners();
    }
  }

  /// Placeholder method, typically not called directly.
  /// Use [setCurrentTool] to manage drawing modes.
  void startDrawing() { notifyListeners(); }
  /// Placeholder method, typically not called directly.
  /// Use [setCurrentTool] or specific action tools like [DrawingTool.finalizeMultiPart].
  void finishDrawing() { notifyListeners(); }
  /// Cancels the current drawing operation. Equivalent to `setCurrentTool(DrawingTool.cancel)`.
  void cancelDrawing() { setCurrentTool(DrawingTool.cancel); }
}
