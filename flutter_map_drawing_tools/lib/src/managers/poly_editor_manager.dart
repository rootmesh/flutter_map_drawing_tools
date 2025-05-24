import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // For Polyline
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_line_editor/flutter_map_line_editor.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart'; // For DragMarker
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';

class PolyEditorManager {
  final DrawingState _drawingState;
  final DrawingToolsOptions _options;
  final VoidCallback _onRefresh; // Callback to signal UI refresh needed (e.g., setState in DrawingLayerCoordinator)

  PolyEditor? _polyEditor;
  PolyEditor? get instance => _polyEditor;

  // Internal state to track if PolyEditor should be active
  bool _isActive = false;
  bool _isCurrentPolyEditorContentInvalid = false; // NEW: Tracks if the current PolyEditor content is invalid
  
  /// Getter to expose the invalid status, e.g., for UI elements to disable a "finalize" button.
  bool get isCurrentContentInvalid => _isCurrentPolyEditorContentInvalid;

  PolyEditorManager({
    required DrawingState drawingState,
    required DrawingToolsOptions options,
    required VoidCallback onRefresh,
  })  : _drawingState = drawingState,
        _options = options,
        _onRefresh = onRefresh {
    // Listener is added in initPolyEditor to ensure _polyEditor exists
  }

  /// Initializes the PolyEditor instance.
  /// This should be called once, typically in initState of the consuming widget (DrawingLayerCoordinator).
  void initPolyEditor() {
    _polyEditor = PolyEditor(
      points: [], // Start with empty points
      pointIcon: _options.vertexHandleIcon ?? _defaultVertexIcon(),
      intermediateIcon: _options.intermediateVertexHandleIcon ?? _defaultIntermediateVertexIcon(),
      addClosePathMarker: false, // Initial value, will be updated by reinitialize
      callbackRefresh: _onRefresh, // Crucial for PolyEditor to signal updates
      polygonEditorOptions: PolygonEditorOptions(
        lineColor: _options.temporaryLineColor, // Default line color
        lineStrokeWidth: 3.0, // Default stroke width
        // Other PolygonEditorOptions can be exposed via DrawingToolsOptions if needed
      ),
    );
    // Add listener to DrawingState AFTER _polyEditor is initialized
    _drawingState.addListener(reinitializePolyEditorState);
    // Perform initial setup based on the current drawing state
    reinitializePolyEditorState();
  }

  /// Reconfigures the PolyEditor based on the current DrawingState.
  /// This is the core method that adapts PolyEditor to different drawing/editing contexts.
  void reinitializePolyEditorState() {
    if (_polyEditor == null) {
      // This case should ideally not be hit if initPolyEditor is called correctly.
      // However, as a safeguard:
      debugPrint("PolyEditorManager: PolyEditor not initialized. Calling initPolyEditor().");
      initPolyEditor();
      if (_polyEditor == null) { // If initPolyEditor somehow failed (should not happen)
         debugPrint("PolyEditorManager: PolyEditor initialization failed critically.");
         return;
      }
    }

    List<LatLng> newPoints = [];
    bool newAddClosePathMarker = false;
    bool shouldBeActive = false;
    Color currentPolyEditorLineColor = _options.temporaryLineColor; // Default

    if (_drawingState.isMultiPartDrawingInProgress && _drawingState.currentDrawingParts.isNotEmpty) {
      // Context: Drawing a new segment of a multi-part polygon/polyline
      newPoints = List.from(_drawingState.currentDrawingParts.last); // Current active part
      if (_drawingState.activeMultiPartTool == DrawingTool.polygon) {
        newAddClosePathMarker = newPoints.length > 1; // Show close marker if at least 2 points
      }
      // TODO: Set currentPolyEditorLineColor based on validity if possible (e.g., _currentPlacementIsValid from original DrawingLayer)
      // This requires more state or access to it. For now, uses temporaryLineColor.
      shouldBeActive = true;
    
    // Validate the current segment if drawing a new multi-part shape
    if (newPoints.isNotEmpty) { // Only validate if there are points
      // Create a temporary shape for validation
      ShapeData tempShapeForValidation;
      if (_drawingState.activeMultiPartTool == DrawingTool.polygon) {
        // For polygons, validation might be against the current set of points forming an open ring
        tempShapeForValidation = PolygonShapeData(
            polygon: Polygon(points: newPoints, isFilled: false, color: Colors.transparent, borderColor: Colors.transparent), // Style doesn't matter for validation
            id: "temp_validation_poly"
        );
      } else { // Polyline
        tempShapeForValidation = PolylineShapeData(
            polyline: Polyline(points: newPoints, color: Colors.transparent), // Style doesn't matter
            id: "temp_validation_line"
        );
      }
      
      bool isValid = _options.validateShapePlacement?.call(tempShapeForValidation.points) ?? true;
      if (!isValid) {
        if (!_isCurrentPolyEditorContentInvalid) { // Call callback only when state changes to invalid
             _options.onPlacementInvalid?.call("Current drawing segment is not allowed here.");
        }
        _isCurrentPolyEditorContentInvalid = true;
      } else {
        _isCurrentPolyEditorContentInvalid = false;
      }
      currentPolyEditorLineColor = _isCurrentPolyEditorContentInvalid ? _options.invalidDrawingColor : _options.temporaryLineColor;
    } else {
      // No points yet, so it's not invalid by placement, reset flag
      _isCurrentPolyEditorContentInvalid = false; 
    }

    } else if (_drawingState.activeEditMode == EditMode.vertexEditing && _drawingState.selectedShapeId != null) {
      // Context: Vertex-editing an existing, finalized shape
    // Validation for vertex editing typically happens on confirm, or could be live here too if desired
    _isCurrentPolyEditorContentInvalid = false; // Reset for vertex editing mode, assume valid until moved
      final selectedShape = _drawingState.findShapeById(_drawingState.selectedShapeId!);
      if (selectedShape is PolyShapeData) { // Covers PolygonShapeData and PolylineShapeData
        newPoints = List.from(selectedShape.points);
        if (selectedShape is PolygonShapeData) {
          // PolyEditor expects an open path to use its addClosePathMarker correctly.
          // If the polygon's points list is closed (first == last), remove the last point for PolyEditor.
          if (newPoints.length > 1 &&
              newPoints.first.latitude == newPoints.last.latitude &&
              newPoints.first.longitude == newPoints.last.longitude) {
            newPoints.removeLast();
          }
          newAddClosePathMarker = true; // Always true for polygons being edited
        } else { // Polyline
          newAddClosePathMarker = false;
        }
        currentPolyEditorLineColor = _options.editingHandleColor.withOpacity(0.8);
        shouldBeActive = true;
      }
    }

    // Check if points actually changed to avoid unnecessary updates if possible
    // This is a shallow check; PolyEditor might do more internally.
    bool pointsChanged = !_listLatLngEquals(_polyEditor!.points, newPoints);
    
    if (pointsChanged) {
        _polyEditor!.points.clear();
        _polyEditor!.points.addAll(newPoints);
    }

    if (_polyEditor!.addClosePathMarker != newAddClosePathMarker) {
        _polyEditor!.addClosePathMarker = newAddClosePathMarker;
        // Forcing a refresh might be needed if PolyEditor doesn't auto-refresh on this property change.
        // pointsChanged = true; // Consider this a change that needs refresh
    }
    
    // Update styles from options (in case they are dynamic, though less common for icons)
    _polyEditor!.pointIcon = _options.vertexHandleIcon ?? _defaultVertexIcon();
    _polyEditor!.intermediateIcon = _options.intermediateVertexHandleIcon ?? _defaultIntermediateVertexIcon();
    if (_polyEditor!.polygonEditorOptions.lineColor != currentPolyEditorLineColor) {
        _polyEditor!.polygonEditorOptions = PolygonEditorOptions(
            lineColor: currentPolyEditorLineColor,
            lineStrokeWidth: _polyEditor!.polygonEditorOptions.lineStrokeWidth, // Keep other options
        );
        // pointsChanged = true; // Consider this a change that needs refresh
    }

    _isActive = shouldBeActive;

    if (!_isActive && _polyEditor!.points.isNotEmpty) {
      // If not active but PolyEditor still has points, clear them.
      _polyEditor!.points.clear();
      pointsChanged = true; // This is a significant change
    }

    if (pointsChanged) {
      // PolyEditor's callbackRefresh should be triggered by its internal methods when points list is manipulated
      // or when test() is called. If direct manipulation (like .clear() or .addAll()) doesn't trigger it,
      // explicitly call test() or _onRefresh().
      // Calling _polyEditor.test() is the recommended way to make PolyEditor refresh itself.
      _polyEditor!.test(); 
    }
    
    // If only properties like addClosePathMarker or styling changed without points changing,
    // and PolyEditor doesn't auto-refresh, call _onRefresh or test()
    // For now, assume PolyEditor's test() handles most visual updates.
    // If visual glitches occur for non-point changes, add:
    // else if (/* any other property changed */) { _polyEditor.test(); }
  }

  /// Helper to compare lists of LatLng.
  bool _listLatLngEquals(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }

  /// Provides the list of DragMarkers from PolyEditor for rendering.
  List<DragMarker> getEditMarkers() {
    if (_polyEditor == null || !_isActive) {
      return [];
    }
    return _polyEditor!.edit(); // These are the draggable vertex and intermediate handles
  }

  /// Provides the Polyline to be rendered by PolyEditor (the lines connecting vertices).
  Polyline? getPolylineForRendering() {
    if (_polyEditor == null || !_isActive || _polyEditor!.points.isEmpty) {
      return null;
    }

    // Determine color based on context
    Color lineColor;
    if (_drawingState.activeEditMode == EditMode.vertexEditing) {
      // TODO: Implement validation for vertex editing if needed. For now, assume valid.
      // If a vertex drag makes the shape invalid, this color should change.
      // This would require PolyEditor to provide feedback on point changes during drag.
      lineColor = _options.editingHandleColor.withOpacity(0.8);
    } else if (_drawingState.isMultiPartDrawingInProgress) {
      lineColor = _isCurrentPolyEditorContentInvalid ? _options.invalidDrawingColor : _options.temporaryLineColor;
    } else {
      // Fallback or inactive state, though this method shouldn't be called if not active.
      lineColor = _options.temporaryLineColor;
    }
    
    return Polyline(
      points: List.from(_polyEditor!.points), 
      color: lineColor,
      strokeWidth: _polyEditor!.polygonEditorOptions.lineStrokeWidth,
      isDotted: true, 
    );
  }

  Widget _defaultVertexIcon() {
    return Icon(Icons.circle, color: _options.editingHandleColor, size: _options.vertexHandleRadius * 2);
  }

  Widget _defaultIntermediateVertexIcon() {
    return Icon(Icons.add_circle_outline, color: _options.editingHandleColor.withOpacity(0.7), size: _options.intermediateVertexHandleRadius * 2);
  }

  void dispose() {
    _drawingState.removeListener(reinitializePolyEditorState);
    // PolyEditor itself from flutter_map_line_editor does not have a specific dispose method.
    // If it did, or if other resources were managed here, they would be cleaned up.
  }
}
