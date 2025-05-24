import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart'; // LatLng is from latlong2
import 'package:flutter_map_line_editor/flutter_map_line_editor.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart'; // For DrawingTool.polygon
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart'; // For PolygonShapeData, PolylineShapeData


bool _listLatLngEquals(List<LatLng>? a, List<LatLng>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  if (identical(a, b)) return true;
  for (int i = 0; i < a.length; i++) {
    if (a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
      return false;
    }
  }
  return true;
}

class PolyEditorManager extends ChangeNotifier {
  final DrawingState drawingState;
  final DrawingToolsOptions options;
  PolyEditor? _polyEditor; // Keep it private, expose via getter if needed for rendering markers

  PolyEditor? get instance => _polyEditor;
  List<LatLng> get points => _polyEditor?.points ?? [];
  bool get addClosePathMarker => _polyEditor?.addClosePathMarker ?? false;

  VoidCallback? _onRefresh; // To trigger setState in the coordinator

  PolyEditorManager({required this.drawingState, required this.options}) {
    // Listener is added in initPolyEditor, after _polyEditor is created.
  }

  void initPolyEditor({required VoidCallback onRefresh}) {
    _onRefresh = onRefresh;
    _polyEditor = PolyEditor(
      points: [], // Initial empty points
      pointIcon: options.getVertexIcon(),
      intermediateIcon: options.getIntermediateIcon(),
      callbackRefresh: _onRefresh!, // Use the passed callback
      addClosePathMarker: false,
    );
    // Add listener here, after _polyEditor is created.
    drawingState.addListener(_handleDrawingStateChange);
    reinitializePolyEditorState(); // Initial sync
  }

  void _handleDrawingStateChange() {
    reinitializePolyEditorState();
  }

  void reinitializePolyEditorState() {
    if (_polyEditor == null) return;

    List<LatLng> newPoints = [];
    bool newAddClosePathMarker = false;

    if (drawingState.isMultiPartDrawingInProgress && drawingState.currentDrawingParts.isNotEmpty) {
      newPoints = List.from(drawingState.currentDrawingParts.last);
      newAddClosePathMarker = (drawingState.activeMultiPartTool == DrawingTool.polygon);
    } else if (drawingState.activeEditMode == EditMode.vertexEditing && drawingState.selectedShapeId != null) {
      final shapeToEdit = drawingState.findShapeById(drawingState.selectedShapeId!);
      if (shapeToEdit is PolygonShapeData) {
        newPoints = List.from(shapeToEdit.polygon.points);
        // If PolyEditor expects open paths for editing polygons:
        if (newPoints.length > 1 && 
            newPoints.first.latitude == newPoints.last.latitude && 
            newPoints.first.longitude == newPoints.last.longitude &&
            shapeToEdit.polygon.isFilled // Only for filled polygons, lines might coincidentally close
           ) {
           newPoints.removeLast(); // PolyEditor usually handles closing internally for its UI
        }
        newAddClosePathMarker = true;
      } else if (shapeToEdit is PolylineShapeData) {
        newPoints = List.from(shapeToEdit.polyline.points);
        newAddClosePathMarker = false;
      }
    }

    bool changed = false; 
    if (!_listLatLngEquals(_polyEditor!.points, newPoints)) {
      _polyEditor!.points.clear();
      _polyEditor!.points.addAll(newPoints);
      changed = true;
    }

    if (_polyEditor!.addClosePathMarker != newAddClosePathMarker) {
      _polyEditor!.addClosePathMarker = newAddClosePathMarker;
      changed = true; 
    }

    if (changed) {
      _polyEditor!.test(); // This should trigger the callbackRefresh (onRefresh)
    } else if (newPoints.isEmpty && _polyEditor!.points.isNotEmpty) {
      // If new state is empty but editor has points, clear and refresh
      _polyEditor!.points.clear();
      _polyEditor!.test();
    }
    // Notify listeners of PolyEditorManager if its own state (like the instance of polyEditor) changes
    // For now, changes are internal to _polyEditor, which refreshes via callback.
    // No need to call notifyListeners() here unless a getter for polyEditor itself needs to trigger rebuilds.
  }

  @override
  void dispose() {
    drawingState.removeListener(_handleDrawingStateChange);
    // _polyEditor?.dispose(); // PolyEditor class from flutter_map_line_editor does not have a dispose method.
    super.dispose();
  }
}
