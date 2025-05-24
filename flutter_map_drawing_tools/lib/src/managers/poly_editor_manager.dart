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
  bool _isCurrentPolyEditorContentInvalid = false;

  /// Getter to expose the invalid status, e.g., for UI elements to disable a "finalize" button.
  bool get isCurrentContentInvalid => _isCurrentPolyEditorContentInvalid;

  PolyEditorManager({
    required DrawingState drawingState,
    required DrawingToolsOptions options,
    required VoidCallback onRefresh,
  })  : _drawingState = drawingState,
        _options = options,
        _onRefresh = onRefresh;

  /// Initializes the PolyEditor instance.
  void initPolyEditor() {
    _polyEditor = PolyEditor(
      points: [],
      pointIcon: _options.getVertexIcon(), // Initial default from options
      intermediateIcon: _options.getIntermediateIcon(), // Initial default from options
      addClosePathMarker: false,
      callbackRefresh: _onRefresh,
      polygonEditorOptions: PolygonEditorOptions(
        lineColor: _options.temporaryLineColor, // Default line color
        lineStrokeWidth: 3.0, // Default stroke width
      ),
    );
    _drawingState.addListener(reinitializePolyEditorState);
    reinitializePolyEditorState();
  }

  /// Reconfigures the PolyEditor based on the current DrawingState.
  void reinitializePolyEditorState() {
    if (_polyEditor == null) {
      debugPrint("PolyEditorManager: PolyEditor not initialized. Calling initPolyEditor().");
      initPolyEditor();
      if (_polyEditor == null) {
         debugPrint("PolyEditorManager: PolyEditor initialization failed critically.");
         return;
      }
    }

    List<LatLng> newPoints = [];
    bool newAddClosePathMarker = false;
    bool shouldBeActive = false;
    Color currentPolyEditorLineColor = _options.temporaryLineColor; // Default
    Widget currentPointIcon = _options.getVertexIcon(); // Default, will be overridden
    Widget currentIntermediateIcon = _options.getIntermediateIcon(); // Default, will be overridden

    if (_drawingState.isMultiPartDrawingInProgress && _drawingState.currentDrawingParts.isNotEmpty) {
      newPoints = List.from(_drawingState.currentDrawingParts.last); 
      if (_drawingState.activeMultiPartTool == DrawingTool.polygon) {
        newAddClosePathMarker = newPoints.length > 1;
      }
      shouldBeActive = true;
    
      // Validation for active segment
      if (newPoints.isNotEmpty) {
        ShapeData tempShapeForValidation;
        if (_drawingState.activeMultiPartTool == DrawingTool.polygon) {
          tempShapeForValidation = PolygonShapeData(
              polygon: Polygon(points: newPoints, isFilled: false, color: Colors.transparent, borderColor: Colors.transparent),
              id: "temp_validation_poly");
        } else { // Polyline
          tempShapeForValidation = PolylineShapeData(
              polyline: Polyline(points: newPoints, color: Colors.transparent),
              id: "temp_validation_line");
        }
        
        bool isValid = _options.validateShapePlacement?.call(tempShapeForValidation.points) ?? true;
        if (!isValid) {
          if (!_isCurrentPolyEditorContentInvalid) { 
               _options.onPlacementInvalid?.call("Current drawing segment is not allowed here.");
          }
          _isCurrentPolyEditorContentInvalid = true;
        } else {
          _isCurrentPolyEditorContentInvalid = false;
        }
        currentPolyEditorLineColor = _isCurrentPolyEditorContentInvalid ? _options.invalidDrawingColor : (_options.activeSegmentColor ?? _options.temporaryLineColor);
      } else {
        _isCurrentPolyEditorContentInvalid = false; 
        currentPolyEditorLineColor = _options.activeSegmentColor ?? _options.temporaryLineColor;
      }
      currentPointIcon = _options.getActiveSegmentVertexIcon();
      currentIntermediateIcon = _options.getActiveSegmentIntermediateIcon();

    } else if (_drawingState.activeEditMode == EditMode.vertexEditing && _drawingState.selectedShapeId != null) {
      _isCurrentPolyEditorContentInvalid = false; 
      final selectedShape = _drawingState.findShapeById(_drawingState.selectedShapeId!);
      if (selectedShape is PolyShapeData) {
        newPoints = List.from(selectedShape.points);
        if (selectedShape is PolygonShapeData) {
          if (newPoints.length > 1 &&
              newPoints.first.latitude == newPoints.last.latitude &&
              newPoints.first.longitude == newPoints.last.longitude) {
            newPoints.removeLast();
          }
          newAddClosePathMarker = true;
        } else { // Polyline
          newAddClosePathMarker = false;
        }
        currentPolyEditorLineColor = _options.editingHandleColor.withOpacity(0.8); // Style for editing existing shape
        currentPointIcon = _options.getVertexIcon(); // Standard editing icons
        currentIntermediateIcon = _options.getIntermediateIcon(); // Standard editing icons
        shouldBeActive = true;
      }
    }

    bool pointsChanged = !_listLatLngEquals(_polyEditor!.points, newPoints);
    if (pointsChanged) {
      _polyEditor!.points.clear();
      _polyEditor!.points.addAll(newPoints);
    }

    _polyEditor!.addClosePathMarker = newAddClosePathMarker;
    _polyEditor!.pointIcon = currentPointIcon; // Apply determined icon
    _polyEditor!.intermediateIcon = currentIntermediateIcon; // Apply determined icon
    
    if (_polyEditor!.polygonEditorOptions.lineColor != currentPolyEditorLineColor) {
        _polyEditor!.polygonEditorOptions = PolygonEditorOptions(
            lineColor: currentPolyEditorLineColor,
            lineStrokeWidth: _polyEditor!.polygonEditorOptions.lineStrokeWidth,
        );
    }

    _isActive = shouldBeActive;

    if (!_isActive && _polyEditor!.points.isNotEmpty) {
      _polyEditor!.points.clear();
      // pointsChanged = true; // Already handled by test() if points were cleared
    }

    // PolyEditor's test() method should be called to reflect changes in points or styling.
    // This typically triggers its internal refresh and the callbackRefresh.
    _polyEditor!.test(); 
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
    // Note: The responsibility of updating DrawingState.currentDrawingParts.last
    // with _polyEditor.points upon user interaction within PolyEditor
    // should be handled by the widget that owns PolyEditorManager (e.g., DrawingLayerCoordinator)
    // after _onRefresh is triggered by PolyEditor.
    return _polyEditor!.edit(); 
  }

  /// Provides the Polyline to be rendered by PolyEditor (the lines connecting vertices).
  Polyline? getPolylineForRendering() {
    if (_polyEditor == null || !_isActive || _polyEditor!.points.isEmpty) {
      return null;
    }

    // The color is already set by reinitializePolyEditorState via polygonEditorOptions
    Color lineColor = _polyEditor!.polygonEditorOptions.lineColor; 

    return Polyline(
      points: List.from(_polyEditor!.points), 
      color: lineColor,
      strokeWidth: _polyEditor!.polygonEditorOptions.lineStrokeWidth,
      // Example: Dotted line for active multi-part segment, solid for vertex editing
      isDotted: _drawingState.isMultiPartDrawingInProgress, 
    );
  }
  
  /// Finalizes the current multi-part drawing session and returns the consolidated shape.
  ///
  /// - `activeTool`: The [DrawingTool] (polygon or polyline) that was active for this multi-part session.
  /// This is needed because `DrawingState.activeMultiPartTool` will be cleared by `consumeDrawingParts`.
  ///
  /// Returns a [ShapeData] (either [MultiPolylineShapeData] or [MultiPolygonShapeData])
  /// if valid parts were drawn, otherwise `null`.
  ShapeData? finalizeMultiPartShape(DrawingTool activeTool) {
    // Get all parts including the one currently in PolyEditor, then consume from DrawingState
    List<List<LatLng>> allRawParts = List.from(_drawingState.currentDrawingParts);

    // If PolyEditor has points and it's different from the last part in drawingState, add it.
    // This handles the case where the last segment is actively being edited in PolyEditor.
    if (_polyEditor != null && _polyEditor!.points.isNotEmpty) {
      if (allRawParts.isNotEmpty && _listLatLngEquals(allRawParts.last, _polyEditor!.points)) {
        // Points are already the last element, ensure it's a copy
        allRawParts.last = List.from(_polyEditor!.points);
      } else if (allRawParts.isEmpty || !_listLatLngEquals(allRawParts.last, _polyEditor!.points)) {
        // Add PolyEditor points if they are different or if allRawParts is empty
        allRawParts.add(List.from(_polyEditor!.points));
      }
    }
    
    // Now, clear the drawing state parts.
    _drawingState.consumeDrawingParts(); // This clears _currentDrawingParts and _activeMultiPartTool in DrawingState

    final List<List<LatLng>> validParts = allRawParts.where((part) {
      bool isValidPolyline = (activeTool == DrawingTool.polyline || activeTool == DrawingTool.multiPolyline) && part.length >= 2;
      bool isValidPolygon = (activeTool == DrawingTool.polygon || activeTool == DrawingTool.multiPolygon) && part.length >= 3;
      return isValidPolyline || isValidPolygon;
    }).toList();

    if (validParts.isEmpty) {
      _polyEditor?.points.clear();
      _polyEditor?.test();
      return null;
    }

    ShapeData? newShape;
    if (activeTool == DrawingTool.polyline || activeTool == DrawingTool.multiPolyline) {
      List<Polyline> polylines = validParts.map((points) => Polyline(
        points: points,
        color: _options.validDrawingColor, // TODO: Use a specific multi-polyline style from options
        strokeWidth: 3.0, // TODO: Take from options
        // Use polyline specific options from DrawingToolsOptions if available
      )).toList();
      if (polylines.isNotEmpty) {
        newShape = MultiPolylineShapeData(id: const Uuid().v4(), polylines: polylines);
      }
    } else if (activeTool == DrawingTool.polygon || activeTool == DrawingTool.multiPolygon) {
      List<Polygon> polygons = validParts.map((points) {
        List<LatLng> closedPoints = List.from(points);
        if (closedPoints.isNotEmpty && (closedPoints.first.latitude != closedPoints.last.latitude || closedPoints.first.longitude != closedPoints.last.longitude)) {
          closedPoints.add(closedPoints.first);
        }
        return Polygon(
          points: closedPoints,
          color: _options.completedPartFillColor ?? _options.drawingFillColor.withOpacity(0.5), // TODO: Specific style
          borderColor: _options.completedPartColor ?? _options.validDrawingColor,
          borderStrokeWidth: 3.0, // TODO: Take from options
          isFilled: true,
          // Use polygon specific options from DrawingToolsOptions if available
        );
      }).toList();
      if (polygons.isNotEmpty) {
        newShape = MultiPolygonShapeData(id: const Uuid().v4(), polygons: polygons);
      }
    }

    _polyEditor?.points.clear(); 
    _polyEditor?.test(); 

    return newShape;
  }

  // Removed _defaultVertexIcon and _defaultIntermediateVertexIcon as
  // _options.getVertexIcon() and _options.getIntermediateIcon() should be used directly.

  void dispose() {
    _drawingState.removeListener(reinitializePolyEditorState);
  }
}
