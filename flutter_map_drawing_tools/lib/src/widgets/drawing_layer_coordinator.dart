import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart';
// import 'package:uuid/uuid.dart'; // Uuid might be used by managers later
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart';
import 'dart:math' as math; // Math might be used by managers later
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map_drawing_tools/src/widgets/contextual_editing_toolbar.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/managers/poly_editor_manager.dart';
import 'package:flutter_map_drawing_tools/src/managers/shape_edit_manager.dart'; // Assuming this path
import 'package:flutter_map_drawing_tools/src/models/dimension_display_model.dart';
import 'package:flutter_map_drawing_tools/src/widgets/numerical_rescale_input_sheet.dart';
import 'package:flutter_map_drawing_tools/src/core/undo_redo_manager.dart';
import 'package:flutter_map_drawing_tools/src/core/commands.dart';
import 'package:flutter_map_drawing_tools/src/managers/new_shape_gesture_manager.dart';
import 'package:flutter_map_drawing_tools/src/widgets/drawing_toolbar.dart'; // Added for toolbar


// Placeholder for ShapeManager - kept as is for brevity
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
  // late ShapeManager _shapeManager; 
  late InteractionManager _interactionManager;
  late ShapeEditManager _shapeEditManager; 
  late DimensionDisplayModel _dimensionDisplayModel;
  late UndoRedoManager _undoRedoManager; 
  late NewShapeGestureManager _newShapeGestureManager; // Added NewShapeGestureManager

  bool _isNumericalInputSheetVisible = false;

  // Properties that were in DrawingLayerState, to be refactored or moved
  ShapeData? _draftShapeData;
  List<DragMarker> _resizeHandles = [];
  MapEvent? _lastPointerDownEvent;
  bool _isDrawingCircleRadius = false;
  // int _last_pointer_down_event_timestamp_check = 0; 
  String? _vertexEditingShapeId;
  bool _currentPlacementIsValid = true;

  @override
  void initState() {
    super.initState();
    _dimensionDisplayModel = DimensionDisplayModel();
    _undoRedoManager = UndoRedoManager();
    _undoRedoManager.addListener(_onUndoRedoStateChanged);

    _newShapeGestureManager = NewShapeGestureManager(
      drawingState: widget.drawingState,
      options: widget.options,
      mapController: widget.mapController,
      onShapeFinalized: _onNewShapeFinalizedByGestureManager,
    );

    _polyEditorManager = PolyEditorManager(
      drawingState: widget.drawingState,
      options: widget.options,
    );
    _polyEditorManager.initPolyEditor(onRefresh: () {
      if (mounted) {
        if (widget.drawingState.isMultiPartDrawingInProgress &&
            _polyEditorManager.instance != null &&
            _polyEditorManager.instance!.isActive) {
          final editorPoints = _polyEditorManager.instance!.points;
          if (widget.drawingState.currentDrawingParts.isNotEmpty &&
              !_listLatLngEquals(widget.drawingState.currentDrawingParts.last, editorPoints)) {
            widget.drawingState.updateLastPart(editorPoints);
          }
        }
        // If scaling and numerical sheet is up, update dimensions from drag
        if (widget.drawingState.activeEditMode == EditMode.scaling && _isNumericalInputSheetVisible) {
            final currentShape = widget.drawingState.draftShapeDataWhileDragging;
            if(currentShape != null) {
                 // This call will notify listeners of DimensionDisplayModel, updating the sheet
                _shapeEditManager._updateDimensionModelFromShape(currentShape);
            }
        }
        setState(() {});
      }
    });

    // _shapeManager = ShapeManager(...); // Assuming used elsewhere

    _shapeEditManager = ShapeEditManager(
      drawingState: widget.drawingState,
      options: widget.options,
      mapController: widget.mapController,
      dimensionDisplayModel: _dimensionDisplayModel, // Pass the model
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
    _dimensionDisplayModel.dispose();
    _undoRedoManager.removeListener(_onUndoRedoStateChanged);
    _undoRedoManager.dispose(); // Assuming it's a ChangeNotifier
    _polyEditorManager.dispose();
    // _shapeManager.dispose();
    _interactionManager.dispose();
    _shapeEditManager.dispose(); 
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
    if (drawingState.currentTool != DrawingTool.circle && _isDrawingCircleRadius) { // _isDrawingCircleRadius seems like local state here
      drawingState.clearTemporaryCircle(); _isDrawingCircleRadius = false; _setMapInteractive(true);
    }
    
    // Handle Numerical Rescale UI visibility
    if (drawingState.activeEditMode == EditMode.scaling && drawingState.selectedShapeId != null) {
      if (!_isNumericalInputSheetVisible) {
        _showNumericalRescaleInput();
      }
    } else {
      if (_isNumericalInputSheetVisible) {
        Navigator.of(context).pop(); // Dismiss sheet if open
        _isNumericalInputSheetVisible = false;
      }
    }
    if (drawingState.activeEditMode != EditMode.scaling && _resizeHandles.isNotEmpty) { // _resizeHandles seems like local state
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
      // This is now handled by _confirmMultiPartShapeCreation, triggered by UI.
      // The setCurrentTool in DrawingState handles the direct tool change.
      // If DrawingTool.finalizeMultiPart is set, it means the user clicked the "confirm" button.
      _confirmMultiPartShapeCreation(); 
      // _confirmMultiPartShapeCreation will call setCurrentTool(DrawingTool.none) at the end.
    }

    // Handle initiation of multi-part drawing if specific tools are selected
    if ((drawingState.currentTool == DrawingTool.multiPolyline || drawingState.currentTool == DrawingTool.multiPolygon) &&
        !drawingState.isMultiPartDrawingInProgress) {
      drawingState.startNewDrawingPart(drawingState.currentTool);
    }


    if(mounted) setState(() {});
  }

  // Helper method (can be moved to a utility class if used elsewhere)
  bool _listLatLngEquals(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }
  
  void _confirmMultiPartShapeCreation() {
    if (!widget.drawingState.isMultiPartDrawingInProgress) {
      // If not in progress, but finalize was called, ensure state is clean.
      widget.drawingState.setCurrentTool(DrawingTool.none);
      return;
    }

    DrawingTool? toolBeingFinalized = widget.drawingState.activeMultiPartTool;
    if (toolBeingFinalized == null) { 
        widget.drawingState.setCurrentTool(DrawingTool.none);
        return;
    }

    ShapeData? newMultiShape = _polyEditorManager.finalizeMultiPartShape(toolBeingFinalized);

    if (newMultiShape != null) {
      final command = CreateShapeCommand(widget.drawingState, newMultiShape);
      _undoRedoManager.executeCommand(command);
      // widget.drawingState.addShape(newMultiShape); // Done by command
      widget.onShapeCreated?.call(newMultiShape);
    }
    
    widget.drawingState.setCurrentTool(DrawingTool.none);
  }

  void _onUndoRedoStateChanged() {
    if (mounted) {
      setState(() {}); // To rebuild UI that depends on canUndo/canRedo (e.g., toolbar buttons)
    }
  }

  void _undo() {
    _undoRedoManager.undo();
  }

  void _redo() {
    _undoRedoManager.redo();
  }

  void _handleToolSelection(DrawingTool tool) {
    if (tool == DrawingTool.undo) {
      _undo();
    } else if (tool == DrawingTool.redo) {
      _redo();
    } else if (tool == DrawingTool.completePart) {
      _handleCompletePart();
    }
     else {
      // This will also trigger _handleDrawingStateChange if the tool actually changes
      widget.drawingState.setCurrentTool(tool);
    }
  }

  void _handleCompletePart() {
    if (widget.drawingState.isMultiPartDrawingInProgress) {
      // Basic validation: can we even complete a part?
      // e.g. current active part must not be empty or must meet min points for its type.
      bool canComplete = false;
      if (widget.drawingState.currentDrawingParts.isNotEmpty) {
          final currentActivePart = widget.drawingState.currentDrawingParts.last;
          final activeTool = widget.drawingState.activeMultiPartTool;
          if (activeTool == DrawingTool.polygon || activeTool == DrawingTool.multiPolygon) {
              canComplete = currentActivePart.length >= 1; // Or more specific (e.g. >=3 for a closed segment)
          } else if (activeTool == DrawingTool.polyline || activeTool == DrawingTool.multiPolyline) {
              canComplete = currentActivePart.length >= 1; // Or more specific (e.g. >=2 for a line segment)
          }
      }

      if (canComplete) {
        final command = CompletePartCommand(widget.drawingState);
        _undoRedoManager.executeCommand(command);
        // After command execution, the tool should ideally revert to the activeMultiPartTool
        // The DrawingState.completeCurrentPart() itself doesn't change currentTool.
        // If DrawingTool.completePart was set on DrawingState, reset it.
        // This is usually handled by DrawingState.setCurrentTool's internal logic.
        // For clarity, ensure the tool is set back to the ongoing multi-part tool.
        if (widget.drawingState.currentTool == DrawingTool.completePart) {
            final ongoingTool = widget.drawingState.activeMultiPartTool;
            if(ongoingTool != null){
                 widget.drawingState.setCurrentTool(ongoingTool);
            } else {
                 widget.drawingState.setCurrentTool(DrawingTool.none); // Fallback
            }
        }
      } else {
        // Optional: Show a message if part cannot be completed
        debugPrint("Cannot complete part: current part is empty or invalid.");
      }
    }
  }
  
  // This method would be the callback provided to NewShapeGestureManager's onShapeFinalized
  void _onNewShapeFinalizedByGestureManager(ShapeData shape) {
    final command = CreateShapeCommand(widget.drawingState, shape);
    _undoRedoManager.executeCommand(command);
    widget.onShapeCreated?.call(shape); // Notify external listeners
  }


  // Methods like _setMapInteractive, _copyShapeData, etc. are kept for now
  // They will be moved to appropriate managers in later steps.

  Map<String, double?> _calculateDimensionsFromShapeData(ShapeData? shape) {
    if (shape == null) return {};
    if (shape is CircleShapeData) {
      return {'radius': shape.circleMarker.radius};
    } else if (shape is PolygonShapeData) {
      if (shape.polygon.points.isEmpty) return {};
      double minX = double.infinity, maxX = double.negativeInfinity;
      double minY = double.infinity, maxY = double.negativeInfinity;
      for (var p in shape.polygon.points) {
        minX = math.min(minX, p.longitude);
        maxX = math.max(maxX, p.longitude);
        minY = math.min(minY, p.latitude);
        maxY = math.max(maxY, p.latitude);
      }
      if (minX != double.infinity) {
        // These are geographical extents (degrees), not meters.
        // For display, this might be okay, but for input, units should be clear.
        return {'width': maxX - minX, 'height': maxY - minY};
      }
    }
    return {};
  }

  void _showNumericalRescaleInput() {
    final currentShape = widget.drawingState.draftShapeDataWhileDragging ?? widget.drawingState.originalShapeDataBeforeDrag;
    if (currentShape == null) return;

    // Check if shape is compatible (Circle or "Rectangle" Polygon)
    bool isCompatible = currentShape is CircleShapeData || 
                        (currentShape is PolygonShapeData && (currentShape as PolygonShapeData).polygon.points.length == 5); // Basic check

    if (!isCompatible) {
        // Optionally, show a snackbar: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Numerical input not supported for this shape.")));
        return;
    }

    final initialDimensions = _calculateDimensionsFromShapeData(currentShape);
    _dimensionDisplayModel.updateDimensions(
      width: initialDimensions['width'],
      height: initialDimensions['height'],
      radius: initialDimensions['radius'],
      notify: false // Don't notify yet, sheet will pick up initial values
    );

    setState(() {
      _isNumericalInputSheetVisible = true;
    });

    showModalBottomSheet(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: _dimensionDisplayModel,
        child: NumericalRescaleInputSheet(
          dimensionModel: _dimensionDisplayModel,
          shapeData: currentShape,
          onApply: _onApplyNumericalRescale,
          onClose: () {
            Navigator.of(context).pop();
            // Optionally, reset edit mode if sheet is closed without applying
            // if (widget.drawingState.activeEditMode == EditMode.scaling) {
            //   widget.drawingState.setActiveEditMode(EditMode.none);
            // }
          },
        ),
      ),
      isScrollControlled: true,
    ).whenComplete(() {
      setState(() {
        _isNumericalInputSheetVisible = false;
      });
      // If user dismisses sheet without applying, and scaling mode is still active,
      // consider resetting edit mode or let user confirm/cancel via main toolbar.
      // For now, just update visibility flag.
    });
  }

  void _onApplyNumericalRescale(Map<String, double> newDimensions) {
    final currentDraft = widget.drawingState.draftShapeDataWhileDragging;
    if (currentDraft == null) return;

    final rescaledShape = _shapeEditManager.rescaleShapeNumerically(currentDraft, newDimensions);

    if (rescaledShape != null) {
      widget.drawingState.setDraftShapeDataWhileDragging(rescaledShape);
      // DimensionDisplayModel is updated within rescaleShapeNumerically
    }
    // The UI sheet is typically closed by its own Apply button's onClose callback.
    // The main shape on map updates due to drawingState change.
    // User still needs to "Confirm" on the ContextualToolbar.
  }

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
    final mapTransformer = MapTransformer(widget.mapController); // Get transformer for current map state

    // Delegate to NewShapeGestureManager if a simple shape tool is active
    if (drawingState.currentTool == DrawingTool.circle ||
        drawingState.currentTool == DrawingTool.rectangle ||
        drawingState.currentTool == DrawingTool.square || // Add other simple shapes here
        drawingState.currentTool == DrawingTool.point) {
      _newShapeGestureManager.handleMapEvent(event, mapTransformer);
      if (mounted) setState(() {}); // NewShapeGestureManager might change _draftShapeData
      return;
    }

    // Delegate to ShapeEditManager if in an editing mode (dragging, scaling, rotating - not vertex editing)
    if (drawingState.selectedShapeId != null &&
        (drawingState.activeEditMode == EditMode.dragging ||
         drawingState.activeEditMode == EditMode.scaling ||
         drawingState.activeEditMode == EditMode.rotating)) {
      _shapeEditManager.updateMapTransformer(mapTransformer); // Ensure manager has latest transformer
      _shapeEditManager.handleMapEvent(event);
      // ShapeEditManager updates drawingState.draftShapeDataWhileDragging, which notifies and rebuilds.
      return;
    }
    
    // Multi-part drawing point addition (tap events)
    if (event is MapEventTap &&
        (drawingState.currentTool == DrawingTool.polygon || // Legacy single polygon
         drawingState.currentTool == DrawingTool.polyline || // Legacy single polyline
         drawingState.currentTool == DrawingTool.multiPolyline ||
         drawingState.currentTool == DrawingTool.multiPolygon) &&
        drawingState.activeEditMode == EditMode.none) {

      if (!drawingState.isMultiPartDrawingInProgress) {
        // Determine if it's a multi-tool or a legacy single poly tool
        DrawingTool toolToStart = drawingState.currentTool;
        if (toolToStart == DrawingTool.polygon && widget.options.polyCreationMode == PolyCreationMode.multi) { // Assuming an option
            toolToStart = DrawingTool.multiPolygon;
        } else if (toolToStart == DrawingTool.polyline && widget.options.polyCreationMode == PolyCreationMode.multi) {
            toolToStart = DrawingTool.multiPolyline;
        }
        // If it's still a single polygon/polyline tool, and we want them to be undoable,
        // they might need their own gesture manager or different command structure.
        // For now, focus on multi-part tools for StartNewPartCommand.
        if(toolToStart == DrawingTool.multiPolygon || toolToStart == DrawingTool.multiPolyline || 
           toolToStart == DrawingTool.polygon || toolToStart == DrawingTool.polyline) { // Allow for legacy single poly tools too
            final startCmd = StartNewPartCommand(widget.drawingState, toolToStart);
            _undoRedoManager.executeCommand(startCmd);
        }
      }
      
      // AddPointToPartCommand assumes a part is ready.
      if (drawingState.isMultiPartDrawingInProgress) { // Check again after potential StartNewPartCommand
          final addPointCmd = AddPointToPartCommand(widget.drawingState, event.tapPosition);
          _undoRedoManager.executeCommand(addPointCmd);
      }
      
      return; 
    }

    if (mounted) setState(() {});
  }

  // ShapeData _getDisplayShape(ShapeData dataFromList) { /* ... */ return dataFromList;} // Placeholder

  @override
  Widget build(BuildContext context) {
    final mapTransformer = MapTransformer(widget.mapController); 

    // Delegate to NewShapeGestureManager if a simple shape tool is active
    if (drawingState.currentTool == DrawingTool.circle ||
        drawingState.currentTool == DrawingTool.rectangle ||
        drawingState.currentTool == DrawingTool.square || 
        drawingState.currentTool == DrawingTool.point) {
      _newShapeGestureManager.handleMapEvent(event, mapTransformer);
      // NewShapeGestureManager calls onShapeFinalized, which should use CreateShapeCommand.
      // It also updates drawingState.temporaryShape, triggering rebuilds.
      return; // Event handled by NewShapeGestureManager
    }

    // Delegate to ShapeEditManager if in an editing mode (dragging, scaling, rotating - not vertex editing)
    if (drawingState.selectedShapeId != null &&
        (drawingState.activeEditMode == EditMode.dragging ||
         drawingState.activeEditMode == EditMode.scaling ||
         drawingState.activeEditMode == EditMode.rotating)) {
      _shapeEditManager.updateMapTransformer(mapTransformer); 
      _shapeEditManager.handleMapEvent(event);
      return; // Event handled by ShapeEditManager
    }
    
    // Multi-part drawing point addition (tap events for specific tools)
    if (event is MapEventTap &&
        (drawingState.currentTool == DrawingTool.multiPolyline ||
         drawingState.currentTool == DrawingTool.multiPolygon ||
         // Also handle legacy single poly tools if they are to become part of multi-part logic
         drawingState.currentTool == DrawingTool.polygon || 
         drawingState.currentTool == DrawingTool.polyline 
         ) &&
        drawingState.activeEditMode == EditMode.none) {

      DrawingTool toolForNewPart = drawingState.currentTool;
      
      // Conceptual: if options specify that legacy polygon/polyline tools should start multi-part drawings
      // if (toolForNewPart == DrawingTool.polygon && widget.options.polyCreationMode == PolyCreationMode.multi) {
      //   toolForNewPart = DrawingTool.multiPolygon;
      // } else if (toolForNewPart == DrawingTool.polyline && widget.options.polyCreationMode == PolyCreationMode.multi) {
      //   toolToStart = DrawingTool.multiPolyline;
      // }


      if (!drawingState.isMultiPartDrawingInProgress) {
        // Only execute StartNewPartCommand if we are certain this tool initiates a multi-part sequence
         if(toolForNewPart == DrawingTool.multiPolygon || toolForNewPart == DrawingTool.multiPolyline ||
            toolForNewPart == DrawingTool.polygon || toolForNewPart == DrawingTool.polyline) { // Simplified: assume these start parts
            final startCmd = StartNewPartCommand(widget.drawingState, toolForNewPart);
            _undoRedoManager.executeCommand(startCmd);
        }
      }
      
      if (drawingState.isMultiPartDrawingInProgress) { 
          final addPointCmd = AddPointToPartCommand(widget.drawingState, event.tapPosition);
          _undoRedoManager.executeCommand(addPointCmd);
      }
      
      return; 
    }

    // Fallback for other map events or if no specific manager handled the event
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // The build method should ideally delegate all rendering to DrawingRenderer.
    // For now, it's simplified to show the conceptual structure with DrawingToolbar.
    // The actual visual layers (shapes, handles, etc.) would be built by DrawingRenderer.
    
    // Conceptual: DrawingRenderer would build these layers based on state.
    // List<Widget> visualLayers = DrawingRenderer(
    //   drawingState: widget.drawingState,
    //   options: widget.options,
    //   polyEditorManager: _polyEditorManager,
    //   // Pass other necessary callbacks for ContextualToolbar interactions if it's part of DrawingRenderer
    //   onToggleEditMode: (mode) { /* ... */ },
    //   onConfirmEdit: () { /* ... */ },
    //   onCancelEdit: () { /* ... */ },
    //   onDeleteShape: () { /* ... */ },
    // ).buildLayers(context);

    return Stack(
      children: [
        // Placeholder for where actual map layers and drawing layers would be rendered.
        // For example, if DrawingRenderer returns a list of FlutterMap layers:
        // ...visualLayers,
        // Or if it's a single widget:
        // DrawingRendererWidget(...), 
        
        // Example: Display a simple Text widget if no other layers are present for clarity
        if (widget.drawingState.currentShapes.isEmpty)
            Center(child: Text("Drawing Layer Coordinator Active", style: Theme.of(context).textTheme.bodySmall)),


        // Position the DrawingToolbar (example placement)
        Positioned(
          bottom: 20,
          right: 20,
          child: DrawingToolbar(
            onToolSelected: _handleToolSelection,
            activeTool: widget.drawingState.currentTool,
            canUndo: _undoRedoManager.canUndo,
            canRedo: _undoRedoManager.canRedo,
            availableTools: widget.options.availableDrawingTools, // Conceptual: options provide this
          ),
        ),

        // ContextualToolbar - its positioning and visibility are complex
        // and would typically be handled by DrawingRenderer or a similar UI manager.
        // For simplicity, not explicitly placing it here, but its callbacks are handled.
        // The logic for showing it is tied to selectedShapeId and edit modes.
      ],
    );
  }
}

// Helper extensions (PolygonCopyWith, etc.) remain at the end of the file.
extension PolygonCopyWith on Polygon { Polygon copyWithGeometry({List<LatLng>? points, List<List<LatLng>>? holePointsList}) { return Polygon( points: points ?? this.points, holePointsList: holePointsList ?? this.holePointsList, color: color, borderColor: borderColor, borderStrokeWidth: borderStrokeWidth, isFilled: isFilled, strokeCap: strokeCap, strokeJoin: strokeJoin, label: label, labelStyle: labelStyle, rotateLabel: rotateLabel, disableHolesBorder: disableHolesBorder, isDotted: isDotted, updateParentBeliefs: updateParentBeliefs, ); } }
extension PolylineCopyWith on Polyline { Polyline copyWithGeometry({List<LatLng>? points}) { return Polyline( points: points ?? this.points, color: color, strokeWidth: strokeWidth, borderColor: borderColor, borderStrokeWidth: borderStrokeWidth, gradientColors: gradientColors, isDotted: isDotted, ); } }
extension CircleMarkerCopyWith on CircleMarker { CircleMarker copyWith({ LatLng? point, double? radius }) { return CircleMarker( point: point ?? this.point, radius: radius ?? this.radius, useRadiusInMeter: useRadiusInMeter, color: color, borderColor: borderColor, borderStrokeWidth: borderStrokeWidth, extraData: extraData, ); } }
extension MarkerCopyWith on Marker { Marker copyWith({ LatLng? point, double? width, double? height, Widget? child, Alignment? alignment, bool? rotate }) { return Marker( point: point ?? this.point, width: width ?? this.width, height: height ?? this.height, alignment: alignment ?? this.alignment, child: child ?? this.child, rotate: rotate ?? this.rotate, ); } }
