import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// PolyEditor is now managed by PolyEditorManager
// import 'package:flutter_map_line_editor/flutter_map_line_editor.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart'; 
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart'; 
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart';
import 'dart:math' as math;
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map_drawing_tools/src/widgets/contextual_editing_toolbar.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart'; 
import 'package:flutter_map_drawing_tools/src/managers/poly_editor_manager.dart'; // New Import

// Callbacks for shape events
typedef OnShapeCreatedCallback = void Function(ShapeData shape); 
typedef OnShapeUpdatedCallback = void Function(ShapeData shape); 
typedef OnShapeDeletedCallback = void Function(String shapeId); 

// _listLatLngEquals is now part of PolyEditorManager or a shared utility. For now, assume PolyEditorManager handles its needs.

class DrawingLayer extends StatefulWidget {
  final MapController mapController;
  final DrawingState drawingState; 
  final DrawingToolsOptions options; 
  final OnShapeCreatedCallback? onShapeCreated;
  final OnShapeUpdatedCallback? onShapeUpdated;
  final OnShapeDeletedCallback? onShapeDeleted;

  const DrawingLayer({
    super.key,
    required this.mapController,
    required this.drawingState,
    this.options = const DrawingToolsOptions(), 
    this.onShapeCreated,
    this.onShapeUpdated,
    this.onShapeDeleted,
  });

  @override
  State<DrawingLayer> createState() => _DrawingLayerState();
}

class _DrawingLayerState extends State<DrawingLayer> {
  // PolyEditor is now managed by _polyEditorManager
  // PolyEditor? _polyEditor; 
  late PolyEditorManager _polyEditorManager; // Instantiated in initState

  ShapeData? _draftShapeData; 
  List<DragMarker> _resizeHandles = []; 

  MapEvent? _lastPointerDownEvent; 
  bool _isDrawingCircleRadius = false; 
  int _last_pointer_down_event_timestamp_check = 0;
  String? _vertexEditingShapeId; // Still needed to track which shape's vertices are being edited
  bool _currentPlacementIsValid = true; 

  @override
  void initState() {
    super.initState();
    _polyEditorManager = PolyEditorManager(
      drawingState: widget.drawingState,
      options: widget.options,
    );
    _polyEditorManager.initPolyEditor(onRefresh: () {
      if (mounted) {
        // When PolyEditorManager's PolyEditor signals a refresh (e.g. internal point drag),
        // it might have updated points in DrawingState.currentDrawingParts.last.
        // We need to ensure DrawingLayer rebuilds to reflect these changes.
        setState(() {});
      }
    });

    widget.drawingState.addListener(_handleDrawingStateChange); 
    // Initial call to _handleDrawingStateChange will trigger PolyEditorManager's listener
    // which in turn calls its reinitializePolyEditorState.
    _handleDrawingStateChange(); // Call manually once to ensure initial setup based on state
  }

  @override
  void dispose() {
    widget.drawingState.removeListener(_handleDrawingStateChange);
    _polyEditorManager.dispose(); // Dispose the manager
    if (_isDrawingCircleRadius || (widget.drawingState.activeEditMode != EditMode.none)) {
      _setMapInteractive(true); 
    }
    super.dispose();
  }

  // _reinitializePolyEditorBasedOnState is now inside PolyEditorManager

  void _handleDrawingStateChange() { 
    final drawingState = widget.drawingState;
    
    if (drawingState.selectedShapeId == null && drawingState.activeEditMode != EditMode.none) { 
        drawingState.setActiveEditMode(EditMode.none); _draftShapeData = null; _clearResizeHandles(); _setMapInteractive(true); 
    }
    if (drawingState.currentTool != DrawingTool.circle && _isDrawingCircleRadius) { 
        drawingState.clearTemporaryCircle(); _isDrawingCircleRadius = false; _setMapInteractive(true); 
    }
    if (drawingState.activeEditMode != EditMode.scaling && _resizeHandles.isNotEmpty) { 
        _clearResizeHandles(); 
    }
    
    bool wasVertexEditing = _vertexEditingShapeId != null; 
    bool shouldBeVertexEditing = false;
    if (drawingState.selectedShapeId != null && drawingState.currentTool == DrawingTool.edit) { 
        final selectedShape = drawingState.findShapeById(drawingState.selectedShapeId!); 
        if (selectedShape is PolygonShapeData || selectedShape is PolylineShapeData) { 
            if (drawingState.activeEditMode == EditMode.none || drawingState.activeEditMode == EditMode.vertexEditing) { 
                shouldBeVertexEditing = true; 
                if (_vertexEditingShapeId != drawingState.selectedShapeId || drawingState.activeEditMode != EditMode.vertexEditing) { 
                    drawingState.setActiveEditMode(EditMode.vertexEditing);  _vertexEditingShapeId = drawingState.selectedShapeId; 
                    if (drawingState.originalShapeDataBeforeDrag?.id != selectedShape.id) {  
                        drawingState.setDragStart(selectedShape.centroid, selectedShape.copy()); 
                    } 
                } 
            } 
        } 
    }

    if (!shouldBeVertexEditing && wasVertexEditing) { 
        _vertexEditingShapeId = null; 
        if (drawingState.activeEditMode == EditMode.vertexEditing) {  
            drawingState.setActiveEditMode(EditMode.none); 
        } 
    }

    if (drawingState.currentTool == DrawingTool.finalizeMultiPart) { 
        final toolWas = drawingState.activeMultiPartTool;  
        final List<List<LatLng>> parts = drawingState.consumeDrawingParts(); 
        if (parts.isNotEmpty) { 
            if (toolWas == DrawingTool.polygon) { 
                List<LatLng> eR = List.from(parts.first); 
                if (eR.length >= 3) { if (eR.first.latitude != eR.last.latitude || eR.first.longitude != eR.last.longitude) { eR.add(eR.first); } } 
                List<List<LatLng>>? hRs; 
                if (parts.length > 1) { 
                    hRs = parts.sublist(1).map((hP) { List<LatLng> h = List.from(hP); if (h.length >= 3) { if (h.first.latitude != h.last.latitude || h.first.longitude != h.last.longitude) { h.add(h.first); } } return h; }).where((h) => h.length >= 4).toList(); 
                    if (hRs.isEmpty) hRs = null; 
                } 
                if (eR.length >= 4) { 
                    final nP = Polygon(points: eR, holePointsList: hRs, color: widget.options.validDrawingColor.withOpacity(0.3), borderColor: widget.options.validDrawingColor, borderStrokeWidth: 2, isFilled: true); 
                    final nPSD = PolygonShapeData(polygon: nP); 
                    drawingState.addShape(nPSD); widget.onShapeCreated?.call(nPSD); 
                } 
            } else if (toolWas == DrawingTool.polyline) { 
                List<ShapeData> nLs = []; 
                for (var p in parts) { if (p.length >= 2) { final nPl = Polyline(points: p, color: widget.options.validDrawingColor, strokeWidth: 3); nLs.add(PolylineShapeData(polyline: nPl)); } } 
                if (nLs.isNotEmpty) { drawingState.addShapes(nLs); nLs.forEach((l) => widget.onShapeCreated?.call(l)); } 
            } 
        } 
        drawingState.setCurrentTool(DrawingTool.none);  
    }
    
    // PolyEditorManager's internal listener to drawingState will call its reinitializePolyEditorState.
    // So, no direct call to _polyEditorManager.reinitializePolyEditorState() needed here.
    // However, we still need to call setState for DrawingLayer if other parts of its UI depend on these changes.
    if(mounted) setState(() {});
  }

  void _setMapInteractive(bool interactive) { /* ... */ }
  ShapeData _copyShapeData(ShapeData original) { return original.copy(); }
  ShapeData _moveShapeData(ShapeData sd, double latD, double lngD) { /* ... */ return sd.copy(); }
  double _calcBearing(LatLng p1, LatLng p2) { /* ... */ return 0.0; }
  LatLng? _getShapeCenter(ShapeData? sD) { if(sD==null)return null; return sD.centroid; }
  LatLng _rotatePoint(LatLng pt, LatLng cen, double angR) { /* ... */ return pt; }
  ShapeData _rotateShapeData(ShapeData sD, double angR, LatLng cen) { /* ... */ return sD.copy(); }
  bool _isRectangle(Polygon poly) { /* ... */ return false; }
  ShapeData _rescaleShapeData(ShapeData oS, LatLng dSHP, LatLng cHP, String hId, LatLng? sCen) { /* ... */ return oS.copy(); }
  void _updateResizeHandles() { /* ... */ } DragMarker _createResizeHandle(LatLng pt, String hId) { /* ... */ return DragMarker(point:pt,child:Container());} void _clearResizeHandles() {if(_resizeHandles.isNotEmpty){_resizeHandles.clear();if(mounted)setState((){});}}
  void _finalizeCircle() { /* ... */ } void _finalizePoint(LatLng pt) { /* ... */ } void _finalizePredefinedPolygon(DrawingTool tool) { /* ... */ } 
  int? sidesForTool(DrawingTool tool) { /* ... */ return null; } 
  bool _isTapOnMarker(LatLng tap, MarkerShapeData mD, MapTransformer trans) { /* ... */ return false; } bool _isTapOnCircle(LatLng tap, CircleShapeData cD) { /* ... */ return false; } bool _isTapOnPolygon(LatLng tap, PolygonShapeData pD) { /* ... */ return false; }

  void _handleMapEvent(MapEvent event) {
    final drawingState = widget.drawingState;

    if (event is MapEventTap && 
        (drawingState.currentTool == DrawingTool.polygon || drawingState.currentTool == DrawingTool.polyline) &&
        drawingState.activeEditMode == EditMode.none ) { 
        
        if (!drawingState.isMultiPartDrawingInProgress) {
            drawingState.startNewDrawingPart(drawingState.currentTool); 
        }
        drawingState.addPointToCurrentPart(event.tapPosition.latlng);
        // PolyEditorManager's listener to drawingState will handle reinitialization.
        // Forcing a setState here ensures DrawingLayer rebuilds if the manager's update isn't immediate enough for UI.
        if(mounted) setState(() {}); 
        return; 
    }
    // ... (Rest of _handleMapEvent) ...
    if (mounted) setState(() {});
  }

  ShapeData _getDisplayShape(ShapeData dataFromList) { /* ... */ return dataFromList;}

  @override
  Widget build(BuildContext context) { 
    final drawingState = widget.drawingState; 
    List<Widget> layers = [];
    // ... (Shape rendering logic from previous steps, using allShapes from drawingState.currentShapes) ...

    // PolyEditor rendering for multi-part or vertex editing
    // Use _polyEditorManager.instance to get the PolyEditor for rendering
    if (_polyEditorManager.instance != null && _polyEditorManager.instance!.points.isNotEmpty) {
        Color polyEditorLineColor = widget.options.temporaryLineColor; 
        bool showPolyEditor = false;
        if (drawingState.isMultiPartDrawingInProgress) {
            final activeTool = drawingState.activeMultiPartTool;
            polyEditorLineColor = _currentPlacementIsValid ? 
                                  (activeTool == DrawingTool.polygon ? widget.options.validDrawingColor : widget.options.validDrawingColor).withOpacity(0.5) : 
                                  widget.options.invalidDrawingColor.withOpacity(0.5);
            showPolyEditor = true;
            // Render completed parts (as before)
            final parts = drawingState.currentDrawingParts;
            for (int i = 0; i < parts.length - 1; i++) { /* ... */ }
        } else if (drawingState.activeEditMode == EditMode.vertexEditing && _vertexEditingShapeId != null) {
            polyEditorLineColor = widget.options.editingHandleColor.withOpacity(0.8); 
            showPolyEditor = true;
        }
        
        if (showPolyEditor) { 
            layers.add(PolylineLayer(polylines: [Polyline(points: _polyEditorManager.instance!.points, color: polyEditorLineColor, strokeWidth: 3, isDotted: true)]));
            layers.add(DragMarkers(markers: _polyEditorManager.instance!.edit())); 
        }
    }
    // ... (Other layers: Contextual Toolbar, Resize Handles etc.) ...
    // Example for ContextualToolbar's onConfirm for vertex editing:
    // onConfirm: () {
    //   if (drawingState.activeEditMode == EditMode.vertexEditing && _polyEditorManager.instance != null && drawingState.selectedShapeId != null) {
    //       final originalShapeData = drawingState.findShapeById(drawingState.selectedShapeId!);
    //       if (originalShapeData != null) {
    //           List<LatLng> updatedPoints = List.from(_polyEditorManager.instance!.points);
    //           // ... (rest of logic to create newShapeData and update drawingState) ...
    //       }
    //       // _polyEditorManager's reinitialize will clear points as _vertexEditingShapeId becomes null after deselectShape
    //   } 
    //   // ... (rest of confirm logic) ...
    //   drawingState.deselectShape(); 
    // },

    return MapEventStreamListener(
      eventStream: widget.mapController.mapEventStream,
      onMapEvent: _handleMapEvent,
      child: Stack(children: layers)
    );
  }
}

// Helper extensions (PolygonCopyWith, etc.) remain at the end of the file.
// ... (extensions as before) ...
extension PolygonCopyWith on Polygon { Polygon copyWithGeometry({List<LatLng>? points, List<List<LatLng>>? holePointsList}) { return Polygon( points: points ?? this.points, holePointsList: holePointsList ?? this.holePointsList, color: color, borderColor: borderColor, borderStrokeWidth: borderStrokeWidth, isFilled: isFilled, strokeCap: strokeCap, strokeJoin: strokeJoin, label: label, labelStyle: labelStyle, rotateLabel: rotateLabel, disableHolesBorder: disableHolesBorder, isDotted: isDotted, updateParentBeliefs: updateParentBeliefs, ); } }
extension PolylineCopyWith on Polyline { Polyline copyWithGeometry({List<LatLng>? points}) { return Polyline( points: points ?? this.points, color: color, strokeWidth: strokeWidth, borderColor: borderColor, borderStrokeWidth: borderStrokeWidth, gradientColors: gradientColors, isDotted: isDotted, ); } }
extension CircleMarkerCopyWith on CircleMarker { CircleMarker copyWith({ LatLng? point, double? radius }) { return CircleMarker( point: point ?? this.point, radius: radius ?? this.radius, useRadiusInMeter: useRadiusInMeter, color: color, borderColor: borderColor, borderStrokeWidth: borderStrokeWidth, extraData: extraData, ); } }
extension MarkerCopyWith on Marker { Marker copyWith({ LatLng? point, double? width, double? height, Widget? child, Alignment? alignment, bool? rotate }) { return Marker( point: point ?? this.point, width: width ?? this.width, height: height ?? this.height, alignment: alignment ?? this.alignment, child: child ?? this.child, rotate: rotate ?? this.rotate, ); } }
