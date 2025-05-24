import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart'; // For EditMode
import 'package:flutter_map_drawing_tools/src/managers/poly_editor_manager.dart';
import 'package:flutter_map_drawing_tools/src/widgets/contextual_editing_toolbar.dart'; // Assuming this is the path

// Callbacks for toolbar - these will be passed from DrawingLayerCoordinator
typedef OnToggleEditModeCallback = void Function(EditMode mode);
typedef OnConfirmEditCallback = void Function();
typedef OnCancelEditCallback = void Function();
typedef OnDeleteShapeCallback = void Function();


class DrawingRenderer {
  final DrawingState drawingState;
  final DrawingToolsOptions options;
  final PolyEditorManager polyEditorManager;
  // Callbacks needed for the ContextualToolbar
  final OnToggleEditModeCallback onToggleEditMode;
  final OnConfirmEditCallback onConfirmEdit;
  final OnCancelEditCallback onCancelEdit;
  final OnDeleteShapeCallback onDeleteShape;
  final VoidCallback? onDuplicateShape; // Optional: if duplicate functionality is added

  DrawingRenderer({
    required this.drawingState,
    required this.options,
    required this.polyEditorManager,
    required this.onToggleEditMode,
    required this.onConfirmEdit,
    required this.onCancelEdit,
    required this.onDeleteShape,
    this.onDuplicateShape,
  });

  List<Widget> buildLayers(BuildContext context) {
    List<Widget> layers = [];

    layers.addAll(_buildFinalizedShapesLayers());
    layers.addAll(_buildTemporaryAndDraftShapesLayers());
    layers.addAll(_buildPolyEditorLayers());
    layers.addAll(_buildResizeHandlesLayers()); // Placeholder for future generic resize handles
    layers.addAll(_buildContextualToolbarLayer(context));

    // Filter out null layers if any helper method could return null
    return layers.where((layer) => layer != null).cast<Widget>().toList();
  }

  List<Widget> _buildFinalizedShapesLayers() {
    List<Polygon> polygons = [];
    List<Polyline> polylines = [];
    List<CircleMarker> circles = [];
    List<Marker> markers = [];

    for (var shapeData in drawingState.currentShapes) {
      // Do not render the shape if it's currently being vertex-edited by PolyEditor,
      // as PolyEditor will render its own version.
      if (drawingState.selectedShapeId == shapeData.id && drawingState.activeEditMode == EditMode.vertexEditing) {
        continue;
      }
      // Similarly, if a shape is being dragged/scaled/rotated, its 'draft' version will be rendered instead.
      if (drawingState.selectedShapeId == shapeData.id && 
          drawingState.draftShapeDataWhileDragging?.id == shapeData.id &&
          (drawingState.activeEditMode == EditMode.dragging || 
           drawingState.activeEditMode == EditMode.scaling || 
           drawingState.activeEditMode == EditMode.rotating)
          ) {
        continue;
      }


      if (shapeData is PolygonShapeData) {
        polygons.add(_applySelectionHighlight(shapeData.polygon, shapeData.id));
      } else if (shapeData is PolylineShapeData) {
        polylines.add(_applySelectionHighlight(shapeData.polyline, shapeData.id));
      } else if (shapeData is CircleShapeData) {
        circles.add(_applySelectionHighlight(shapeData.circleMarker, shapeData.id));
      } else if (shapeData is MarkerShapeData) {
        // Marker highlighting might involve changing the child widget, which is more complex.
        // For now, markers are not visually highlighted on selection.
        markers.add(shapeData.marker);
      }
    }

    List<Widget> layers = [];
    if (polygons.isNotEmpty) layers.add(PolygonLayer(polygons: polygons, polygonCulling: options.polygonCulling));
    if (polylines.isNotEmpty) layers.add(PolylineLayer(polylines: polylines, polylineCulling: options.polylineCulling));
    if (circles.isNotEmpty) layers.add(CircleLayer(circles: circles, circleCulling: options.circleCulling));
    if (markers.isNotEmpty) layers.add(MarkerLayer(markers: markers));
    
    return layers;
  }

  List<Widget> _buildTemporaryAndDraftShapesLayers() {
    List<Widget> layers = [];
    ShapeData? shapeToRender;
    bool isTemporary = false;

    if (drawingState.draftShapeDataWhileDragging != null && 
        (drawingState.activeEditMode == EditMode.dragging || 
         drawingState.activeEditMode == EditMode.scaling || 
         drawingState.activeEditMode == EditMode.rotating)) {
      shapeToRender = drawingState.draftShapeDataWhileDragging;
    } else if (drawingState.temporaryShape != null && 
               (drawingState.currentTool == DrawingTool.circle || 
                drawingState.currentTool == DrawingTool.rectangle ||
                drawingState.currentTool == DrawingTool.square 
                /* add other tools that use temporaryShape */
               )) {
      shapeToRender = drawingState.temporaryShape;
      isTemporary = true;
    }
    
    if (shapeToRender == null) return layers;

    // The NewShapeGestureManager now sets the correct valid/invalid color directly on the _draftShapeData.
    // So, the renderer should just use the colors from the shapeToRender.
    // No need to determine tempBorderColor/tempFillColor here based on 'isTemporary' flag.

    if (shapeToRender is PolygonShapeData) {
      // Ensure the provided polygon from shapeToRender is used directly,
      // as its colors are already set by the gesture manager.
      layers.add(PolygonLayer(polygons: [shapeToRender.polygon], polygonCulling: options.polygonCulling));
    } else if (shapeToRender is PolylineShapeData) { 
      // Polylines used for temporary/draft purposes are typically handled by PolyEditorManager,
      // but if NewShapeGestureManager were to produce one, it would also have its color pre-set.
      layers.add(PolylineLayer(polylines: [shapeToRender.polyline], polylineCulling: options.polylineCulling));
    } else if (shapeToRender is CircleShapeData) {
      // Ensure the provided circleMarker from shapeToRender is used directly.
      layers.add(CircleLayer(circles: [shapeToRender.circleMarker], circleCulling: options.circleCulling));
    }
    // Markers are usually not temporary in this way for complex drag-drawing; they are placed directly.

    return layers;
  }

  List<Widget> _buildPolyEditorLayers() {
    if (!polyEditorManager._isActive) return []; // Use the internal flag from PolyEditorManager

    List<Widget> layers = [];
    final polyline = polyEditorManager.getPolylineForRendering();
    if (polyline != null && polyline.points.isNotEmpty) {
      layers.add(PolylineLayer(polylines: [polyline], polylineCulling: options.polylineCulling));
    }

    final markers = polyEditorManager.getEditMarkers();
    if (markers.isNotEmpty) {
      layers.add(DragMarkers(markers: markers));
    }
    return layers;
  }
  
  List<Widget> _buildResizeHandlesLayers() {
    // This is a placeholder for future generic resize/rotate handles.
    // Currently, PolyEditorManager provides handles for polygons/polylines.
    // Circles might need their own (e.g., a single handle on the circumference).
    // Rectangles (if not using PolyEditor) would also need corner/edge handles.
    // These would likely be DragMarkers.
    List<DragMarker> handles = [];

    if (drawingState.selectedShapeId != null && drawingState.activeEditMode == EditMode.scaling) {
      final shape = drawingState.findShapeById(drawingState.selectedShapeId!);
      if (shape is CircleShapeData) {
        // Example: Add a resize handle for a circle
        final center = shape.circleMarker.point;
        final radius = shape.circleMarker.radius;
        // Place handle on the right edge of the circle
        LatLng handlePos = const Distance().offset(center, radius, 90); // 90 degrees = East
        handles.add(DragMarker(
          point: handlePos,
          width: options.vertexHandleRadius * 2.5, // Make it slightly larger or use a specific icon
          height: options.vertexHandleRadius * 2.5,
          offset: Offset(0, -options.vertexHandleRadius), // Adjust anchor
          child: options.resizeHandleIcon ?? Icon(Icons.drag_handle, color: options.editingHandleColor),
          onDragUpdate: (details, newPos) {
            // In DrawingLayerCoordinator: shapeEditManager.handleResize("circle_radius_handle", newPos);
          },
          onDragEnd: (details) {
            // Potentially call confirmEdit or let user do it via toolbar
          },
        ));
      }
      // TODO: Add handles for rectangles if they are not PolyShapeData edited by PolyEditor
    }
    
    if (handles.isNotEmpty) {
      return [DragMarkers(markers: handles)];
    }
    return [];
  }


  List<Widget> _buildContextualToolbarLayer(BuildContext context) {
    if (drawingState.selectedShapeId != null &&
        (drawingState.currentTool == DrawingTool.edit || drawingState.currentTool == DrawingTool.delete || drawingState.currentTool == DrawingTool.none) &&
        drawingState.activeEditMode != EditMode.vertexEditing // Toolbar might be different or hidden during vertex edit depending on UX
        ) {
      final selectedShape = drawingState.findShapeById(drawingState.selectedShapeId!);
      if (selectedShape != null) {
        // Determine available edit modes for the shape type
        List<EditMode> availableModes = [EditMode.none, EditMode.dragging];
        if (selectedShape is PolyShapeData) {
          availableModes.add(EditMode.vertexEditing);
          // Basic scaling/rotating for PolyShapes can be complex without dedicated handles
          // For now, only allow dragging and vertex editing.
        } else if (selectedShape is CircleShapeData) {
          availableModes.add(EditMode.scaling); // Circle radius scaling
          // availableModes.add(EditMode.rotating); // Circles don't typically rotate around center
        }
        // Markers are usually just dragged or deleted.

        return [
          Positioned(
            top: options.toolbarPosition?.top,
            right: options.toolbarPosition?.right,
            left: options.toolbarPosition?.left,
            bottom: options.toolbarPosition?.bottom,
            child: ContextualEditingToolbar(
              options: options,
              drawingState: drawingState,
              selectedShape: selectedShape,
              availableEditModes: availableModes,
              onToggleEditMode: onToggleEditMode,
              onConfirm: onConfirmEdit,
              onCancel: onCancelEdit,
              onDelete: onDeleteShape,
              onDuplicate: onDuplicateShape, // Pass it through
            ),
          )
        ];
      }
    }
    return [];
  }

  // Helper methods to apply selection highlighting
  T _applySelectionHighlight<T>(T shape, String shapeId) {
    if (drawingState.selectedShapeId != shapeId || drawingState.activeEditMode == EditMode.vertexEditing) {
      return shape; // No highlight or PolyEditor is handling it
    }

    // Apply highlight based on shape type
    if (shape is Polygon) {
      return shape.copyWith(
        borderColor: options.selectedShapeColor,
        borderStrokeWidth: (shape.borderStrokeWidth ?? 1.0) + options.selectedShapeBorderWidthIncrease,
        // color: shape.color?.withOpacity(0.8) ?? options.selectedShapeColor.withOpacity(0.3), // Optional: change fill
      ) as T;
    } else if (shape is Polyline) {
      return shape.copyWith(
        color: options.selectedShapeColor,
        strokeWidth: shape.strokeWidth + options.selectedShapeBorderWidthIncrease,
      ) as T;
    } else if (shape is CircleMarker) {
      return shape.copyWith(
        borderColor: options.selectedShapeColor,
        borderStrokeWidth: (shape.borderStrokeWidth ?? 1.0) + options.selectedShapeBorderWidthIncrease,
        // color: shape.color.withOpacity(0.8) ?? options.selectedShapeColor.withOpacity(0.3), // Optional: change fill
      ) as T;
    }
    return shape;
  }
}


// Helper extensions for FlutterMap objects if not already available
extension _PolygonCopyWith on Polygon {
  Polygon copyWith({
    List<LatLng>? points,
    List<List<LatLng>>? holePointsList,
    Color? color,
    double? borderStrokeWidth,
    Color? borderColor,
    bool? disableHolesBorder,
    bool? isFilled,
    bool? isDotted,
  }) {
    return Polygon(
      points: points ?? this.points,
      holePointsList: holePointsList ?? this.holePointsList,
      color: color ?? this.color,
      borderStrokeWidth: borderStrokeWidth ?? this.borderStrokeWidth,
      borderColor: borderColor ?? this.borderColor,
      disableHolesBorder: disableHolesBorder ?? this.disableHolesBorder,
      isFilled: isFilled ?? this.isFilled,
      isDotted: isDotted ?? this.isDotted,
      label: label,
      labelStyle: labelStyle,
      rotateLabel: rotateLabel,
      updateParentBeliefs: updateParentBeliefs,
    );
  }
}

extension _PolylineCopyWith on Polyline {
  Polyline copyWith({
    List<LatLng>? points,
    double? strokeWidth,
    Color? color,
    double? borderStrokeWidth,
    Color? borderColor,
    List<Color>? gradientColors,
    List<double>? colorsStop,
    bool? isDotted,
  }) {
    return Polyline(
      points: points ?? this.points,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      color: color ?? this.color,
      borderStrokeWidth: borderStrokeWidth ?? this.borderStrokeWidth,
      borderColor: borderColor ?? this.borderColor,
      gradientColors: gradientColors ?? this.gradientColors,
      colorsStop: colorsStop ?? this.colorsStop,
      isDotted: isDotted ?? this.isDotted,
    );
  }
}

extension _CircleMarkerCopyWith on CircleMarker {
  CircleMarker copyWith({
    LatLng? point,
    double? radius,
    bool? useRadiusInMeter,
    Color? color,
    double? borderStrokeWidth,
    Color? borderColor,
    dynamic? extraData,
  }) {
    return CircleMarker(
      point: point ?? this.point,
      radius: radius ?? this.radius,
      useRadiusInMeter: useRadiusInMeter ?? this.useRadiusInMeter,
      color: color ?? this.color,
      borderStrokeWidth: borderStrokeWidth ?? this.borderStrokeWidth,
      borderColor: borderColor ?? this.borderColor,
      extraData: extraData ?? this.extraData,
    );
  }
}
