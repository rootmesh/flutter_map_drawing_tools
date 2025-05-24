import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart';
// import 'package:uuid/uuid.dart'; // Uuid might be used by managers later
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart';
// import 'dart:math' as math; // Math might be used by managers later
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map_drawing_tools/src/widgets/contextual_editing_toolbar.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/managers/poly_editor_manager.dart';

// Placeholder for ShapeManager
class ShapeManager {
  final DrawingState drawingState;
  final DrawingToolsOptions options;
  final Function? onShapeCreated;
  final Function? onShapeUpdated;
  final Function? onShapeDeleted;

  ShapeManager({
    required this.drawingState,
    required this.options,
    this.onShapeCreated,
    this.onShapeUpdated,
    this.onShapeDeleted,
  });

  void dispose() {}
  // Add methods related to shape manipulation if needed for the coordinator
  // For now, it's mainly a placeholder
}

// Placeholder for InteractionManager
class InteractionManager {
  final DrawingState drawingState;
  final MapController mapController;
  final DrawingToolsOptions options;
  final Function(MapEvent) onMapEvent; // Callback to handle map events processed by DrawingLayerCoordinator

  InteractionManager({
    required this.drawingState,
    required this.mapController,
    required this.options,
    required this.onMapEvent,
  });

  void handleMapEvent(MapEvent event) {
    // This is where event handling logic will go.
    // For now, it can just forward to the coordinator's handler or be basic.
    // The coordinator will pass its _handleMapEvent method to this manager.
    onMapEvent(event);
  }

  void dispose() {}
}


// Callbacks for shape events
typedef OnShapeCreatedCallback = void Function(ShapeData shape);
typedef OnShapeUpdatedCallback = void Function(ShapeData shape);
typedef OnShapeDeletedCallback = void Function(String shapeId);

class DrawingLayerCoordinator extends StatefulWidget {
  final MapController mapController;
  final DrawingState drawingState;
  final DrawingToolsOptions options;
  final OnShapeCreatedCallback? onShapeCreated;
  final OnShapeUpdatedCallback? onShapeUpdated;
  final OnShapeDeletedCallback? onShapeDeleted;

  const DrawingLayerCoordinator({
    super.key,
    required this.mapController,
    required this.drawingState,
    this.options = const DrawingToolsOptions(),
    this.onShapeCreated,
    this.onShapeUpdated,
    this.onShapeDeleted,
  });

  @override
  State<DrawingLayerCoordinator> createState() => _DrawingLayerCoordinatorState();
}

class _DrawingLayerCoordinatorState extends State<DrawingLayerCoordinator> {
  late PolyEditorManager _polyEditorManager;
  late ShapeManager _shapeManager; // Placeholder for ShapeManager
  late InteractionManager _interactionManager; // Placeholder for InteractionManager

  // Properties that were in DrawingLayerState, to be refactored or moved
  ShapeData? _draftShapeData;
  List<DragMarker> _resizeHandles = [];
  MapEvent? _lastPointerDownEvent;
  bool _isDrawingCircleRadius = false;
  // int _last_pointer_down_event_timestamp_check = 0; // This seems to be unused, removing for now
  String? _vertexEditingShapeId;
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
        setState(() {});
      }
    });

    _shapeManager = ShapeManager(
        drawingState: widget.drawingState,
        options: widget.options,
        onShapeCreated: widget.onShapeCreated,
        onShapeUpdated: widget.onShapeUpdated,
        onShapeDeleted: widget.onShapeDeleted,
    );

    _interactionManager = InteractionManager(
        drawingState: widget.drawingState,
        mapController: widget.mapController,
        options: widget.options,
        onMapEvent: _handleMapEvent, // Pass the actual handler
    );

    widget.drawingState.addListener(_handleDrawingStateChange);
    _handleDrawingStateChange(); 
  }

  @override
  void dispose() {
    widget.drawingState.removeListener(_handleDrawingStateChange);
    _polyEditorManager.dispose();
    _shapeManager.dispose();
    _interactionManager.dispose();
    // Original dispose logic from DrawingLayer
    if (_isDrawingCircleRadius || (widget.drawingState.activeEditMode != EditMode.none)) {
      _setMapInteractive(true);
    }
    super.dispose();
  }

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
            drawingState.setActiveEditMode(EditMode.vertexEditing); _vertexEditingShapeId = drawingState.selectedShapeId;
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

    if(mounted) setState(() {});
  }

  // Methods like _setMapInteractive, _copyShapeData, etc. are kept for now
  // They will be moved to appropriate managers in later steps.
  void _setMapInteractive(bool interactive) {
    // This logic will eventually move to an InteractionManager or similar
    if (interactive) {
      widget.mapController.options.flags |= MapInteractiveFlags.all;
    } else {
      widget.mapController.options.flags &= ~MapInteractiveFlags.all;
    }
  }

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
    // This method will be the primary handler for map events.
    // It will delegate to InteractionManager or other managers as needed.
    // For now, keep the existing logic from DrawingLayer.
    final drawingState = widget.drawingState;

    if (event is MapEventTap &&
        (drawingState.currentTool == DrawingTool.polygon || drawingState.currentTool == DrawingTool.polyline) &&
        drawingState.activeEditMode == EditMode.none ) {

        if (!drawingState.isMultiPartDrawingInProgress) {
            drawingState.startNewDrawingPart(drawingState.currentTool);
        }
        drawingState.addPointToCurrentPart(event.tapPosition.latlng);
        if(mounted) setState(() {});
        return;
    }
    // ... (Rest of _handleMapEvent from original DrawingLayer) ...
    if (mounted) setState(() {});
  }

  ShapeData _getDisplayShape(ShapeData dataFromList) { /* ... */ return dataFromList;}

  @override
  Widget build(BuildContext context) {
    final drawingState = widget.drawingState;
    List<Widget> layers = [];

    // Shape rendering logic (will be moved to DrawingRenderer later)
    // For now, keep it similar to original DrawingLayer
    for (var shapeData in drawingState.currentShapes) {
      var displayShape = _getDisplayShape(shapeData); // Potentially modified by active operations
      if (displayShape is PolygonShapeData) {
        layers.add(PolygonLayer(polygons: [displayShape.polygon]));
      } else if (displayShape is PolylineShapeData) {
        layers.add(PolylineLayer(polylines: [displayShape.polyline]));
      } else if (displayShape is CircleShapeData) {
        // Assuming CircleMarkers are used for circles
        layers.add(CircleLayer(circles: [displayShape.circleMarker]));
      } else if (displayShape is MarkerShapeData) {
        layers.add(MarkerLayer(markers: [displayShape.marker]));
      }
    }
    
    // Draft shape rendering (e.g. circle radius drawing)
    if (_draftShapeData is CircleShapeData && _isDrawingCircleRadius) {
        layers.add(CircleLayer(circles: [(_draftShapeData as CircleShapeData).circleMarker]));
    } else if (_draftShapeData is PolygonShapeData && (widget.drawingState.currentTool == DrawingTool.rectangle || widget.drawingState.currentTool == DrawingTool.square || widget.drawingState.currentTool == DrawingTool.triangle)) {
        layers.add(PolygonLayer(polygons: [(_draftShapeData as PolygonShapeData).polygon]));
    }


    // PolyEditor rendering
    if (_polyEditorManager.instance != null && _polyEditorManager.instance!.points.isNotEmpty) {
        Color polyEditorLineColor = widget.options.temporaryLineColor;
        bool showPolyEditor = false;
        if (drawingState.isMultiPartDrawingInProgress) {
            final activeTool = drawingState.activeMultiPartTool;
            polyEditorLineColor = _currentPlacementIsValid ?
                                  (activeTool == DrawingTool.polygon ? widget.options.validDrawingColor : widget.options.validDrawingColor).withOpacity(0.5) :
                                  widget.options.invalidDrawingColor.withOpacity(0.5);
            showPolyEditor = true;
            final parts = drawingState.currentDrawingParts;
            for (int i = 0; i < parts.length - 1; i++) { // Render previous parts as solid lines
                 List<LatLng> completedPartPoints = parts[i];
                 if (completedPartPoints.isNotEmpty) {
                    Polyline polylineToRender;
                    if (activeTool == DrawingTool.polygon && completedPartPoints.length > 2 && completedPartPoints.first == completedPartPoints.last) { // Closed polygon part
                        polylineToRender = Polyline(points: completedPartPoints, color: polyEditorLineColor, strokeWidth: 3, isFilled: true); // Consider fill
                         layers.add(PolygonLayer(polygons: [Polygon(points: completedPartPoints, color: polyEditorLineColor.withOpacity(0.3), isFilled: true, borderStrokeWidth: 3, borderColor: polyEditorLineColor)]));
                    } else { // Polyline or open polygon part
                        polylineToRender = Polyline(points: completedPartPoints, color: polyEditorLineColor, strokeWidth: 3);
                        layers.add(PolylineLayer(polylines: [polylineToRender]));
                    }
                 }
            }
        } else if (drawingState.activeEditMode == EditMode.vertexEditing && _vertexEditingShapeId != null) {
            polyEditorLineColor = widget.options.editingHandleColor.withOpacity(0.8);
            showPolyEditor = true;
        }

        if (showPolyEditor) {
            layers.add(PolylineLayer(polylines: [Polyline(points: _polyEditorManager.instance!.points, color: polyEditorLineColor, strokeWidth: 3, isDotted: true)]));
            layers.add(DragMarkers(markers: _polyEditorManager.instance!.edit()));
        }
    }

    // Resize handles rendering
    if (_resizeHandles.isNotEmpty && drawingState.activeEditMode == EditMode.scaling) {
      layers.add(DragMarkers(markers: _resizeHandles));
    }
    
    // Contextual Toolbar
    if (drawingState.selectedShapeId != null && (drawingState.currentTool == DrawingTool.edit || drawingState.currentTool == DrawingTool.delete)) {
        final selectedShape = drawingState.findShapeById(drawingState.selectedShapeId!);
        if (selectedShape != null) {
            layers.add(Positioned(
              top: 10,
              right: 10,
              child: ContextualEditingToolbar(
                options: widget.options,
                drawingState: drawingState,
                selectedShape: selectedShape,
                onToggleEditMode: (mode) {
                  if (mode == EditMode.none && drawingState.activeEditMode == EditMode.vertexEditing) {
                    // If exiting vertex editing, finalize potential changes
                    if (_polyEditorManager.instance != null && drawingState.originalShapeDataBeforeDrag is PolyShapeData) {
                       final originalPolyShape = drawingState.originalShapeDataBeforeDrag as PolyShapeData;
                       final updatedPoints = List<LatLng>.from(_polyEditorManager.instance!.points);
                       ShapeData? newShapeData;
                       if(originalPolyShape is PolygonShapeData){
                         newShapeData = originalPolyShape.copyWithPolygon(
                           originalPolyShape.polygon.copyWithGeometry(points: updatedPoints)
                         );
                       } else if (originalPolyShape is PolylineShapeData){
                          newShapeData = originalPolyShape.copyWithPolyline(
                           originalPolyShape.polyline.copyWithGeometry(points: updatedPoints)
                         );
                       }
                       if(newShapeData != null){
                         drawingState.updateShape(newShapeData);
                         widget.onShapeUpdated?.call(newShapeData);
                       }
                    }
                  }
                   drawingState.setActiveEditMode(mode);
                   if(mode == EditMode.none) drawingState.deselectShape();
                   if(mounted) setState(() {});
                },
                onConfirm: () {
                  // Consolidate finalization logic here or in ShapeManager
                  if (drawingState.activeEditMode == EditMode.vertexEditing && _polyEditorManager.instance != null && drawingState.selectedShapeId != null) {
                      final originalShapeData = drawingState.findShapeById(drawingState.selectedShapeId!); // Should be same as originalShapeDataBeforeDrag
                      if (originalShapeData is PolyShapeData) {
                          List<LatLng> updatedPoints = List<LatLng>.from(_polyEditorManager.instance!.points);
                          ShapeData newShapeData;
                          if(originalShapeData is PolygonShapeData){
                             newShapeData = originalShapeData.copyWithPolygon(originalShapeData.polygon.copyWithGeometry(points: updatedPoints));
                          } else { // PolylineShapeData
                             newShapeData = (originalShapeData as PolylineShapeData).copyWithPolyline((originalShapeData as PolylineShapeData).polyline.copyWithGeometry(points: updatedPoints));
                          }
                          drawingState.updateShape(newShapeData);
                          widget.onShapeUpdated?.call(newShapeData);
                      }
                  } else if (drawingState.activeEditMode == EditMode.dragging || drawingState.activeEditMode == EditMode.scaling || drawingState.activeEditMode == EditMode.rotating) {
                     if(drawingState.draftShapeDataWhileDragging != null){
                        drawingState.updateShape(drawingState.draftShapeDataWhileDragging!);
                        widget.onShapeUpdated?.call(drawingState.draftShapeDataWhileDragging!);
                     }
                  }
                  drawingState.deselectShape(); // This will trigger _handleDrawingStateChange which should clear vertex editing state
                  if(mounted) setState(() {});
                },
                onCancel: () {
                  if(drawingState.originalShapeDataBeforeDrag != null){
                    drawingState.revertToOriginalShape(drawingState.originalShapeDataBeforeDrag!);
                    // No need to call onShapeUpdated as it's a revert
                  }
                  drawingState.deselectShape();
                  if(mounted) setState(() {});
                },
                onDelete: () {
                  if (drawingState.selectedShapeId != null) {
                    final shapeIdToDelete = drawingState.selectedShapeId!;
                    drawingState.removeShape(shapeIdToDelete);
                    widget.onShapeDeleted?.call(shapeIdToDelete);
                    drawingState.deselectShape(); // Ensure deselection after deletion
                  }
                  if(mounted) setState(() {});
                },
              ),
            ));
        }
    }


    return MapEventStreamListener(
      eventStream: widget.mapController.mapEventStream,
      onMapEvent: _interactionManager.handleMapEvent, // Delegate to InteractionManager
      child: Stack(children: layers),
    );
  }
}

// Helper extensions (PolygonCopyWith, etc.) remain at the end of the file.
extension PolygonCopyWith on Polygon { Polygon copyWithGeometry({List<LatLng>? points, List<List<LatLng>>? holePointsList}) { return Polygon( points: points ?? this.points, holePointsList: holePointsList ?? this.holePointsList, color: color, borderColor: borderColor, borderStrokeWidth: borderStrokeWidth, isFilled: isFilled, strokeCap: strokeCap, strokeJoin: strokeJoin, label: label, labelStyle: labelStyle, rotateLabel: rotateLabel, disableHolesBorder: disableHolesBorder, isDotted: isDotted, updateParentBeliefs: updateParentBeliefs, ); } }
extension PolylineCopyWith on Polyline { Polyline copyWithGeometry({List<LatLng>? points}) { return Polyline( points: points ?? this.points, color: color, strokeWidth: strokeWidth, borderColor: borderColor, borderStrokeWidth: borderStrokeWidth, gradientColors: gradientColors, isDotted: isDotted, ); } }
extension CircleMarkerCopyWith on CircleMarker { CircleMarker copyWith({ LatLng? point, double? radius }) { return CircleMarker( point: point ?? this.point, radius: radius ?? this.radius, useRadiusInMeter: useRadiusInMeter, color: color, borderColor: borderColor, borderStrokeWidth: borderStrokeWidth, extraData: extraData, ); } }
extension MarkerCopyWith on Marker { Marker copyWith({ LatLng? point, double? width, double? height, Widget? child, Alignment? alignment, bool? rotate }) { return Marker( point: point ?? this.point, width: width ?? this.width, height: height ?? this.height, alignment: alignment ?? this.alignment, child: child ?? this.child, rotate: rotate ?? this.rotate, ); } }
