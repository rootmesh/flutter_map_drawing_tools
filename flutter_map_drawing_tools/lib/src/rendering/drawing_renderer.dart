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
    layers.addAll(_buildInProgressMultiPartLayers()); // Render completed parts of ongoing multi-part drawing
    layers.addAll(_buildTemporaryAndDraftShapesLayers());
    layers.addAll(_buildPolyEditorLayers());
    layers.addAll(_buildResizeHandlesLayers()); 
    layers.addAll(_buildContextualToolbarLayer(context));

    return layers.where((layer) => layer != null).cast<Widget>().toList();
  }

  List<Widget> _buildFinalizedShapesLayers() {
    List<Polygon> polygons = [];
    List<Polyline> polylines = [];
    List<CircleMarker> circles = [];
    List<Marker> markers = [];

    for (var shapeData in drawingState.currentShapes) {
      if (drawingState.selectedShapeId == shapeData.id && drawingState.activeEditMode == EditMode.vertexEditing) {
        continue;
      }
      if (drawingState.selectedShapeId == shapeData.id && 
          drawingState.draftShapeDataWhileDragging?.id == shapeData.id &&
          (drawingState.activeEditMode == EditMode.dragging || 
           drawingState.activeEditMode == EditMode.scaling || 
           drawingState.activeEditMode == EditMode.rotating)) {
        continue;
      }

      if (shapeData is PolygonShapeData) {
        polygons.add(_applySelectionHighlight(shapeData.polygon, shapeData.id));
      } else if (shapeData is PolylineShapeData) {
        polylines.add(_applySelectionHighlight(shapeData.polyline, shapeData.id));
      } else if (shapeData is CircleShapeData) {
        circles.add(_applySelectionHighlight(shapeData.circleMarker, shapeData.id));
      } else if (shapeData is MarkerShapeData) {
        markers.add(shapeData.marker);
      } else if (shapeData is MultiPolylineShapeData) {
        for (var polyline in shapeData.polylines) {
          // Apply selection highlight to each part if the parent multi-shape is selected
          Polyline displayPolyline = polyline;
          if (drawingState.selectedShapeId == shapeData.id) {
            displayPolyline = _applySelectionHighlight(polyline, shapeData.id);
          }
          polylines.add(displayPolyline);
        }
      } else if (shapeData is MultiPolygonShapeData) {
        for (var polygon in shapeData.polygons) {
          Polygon displayPolygon = polygon;
          if (drawingState.selectedShapeId == shapeData.id) {
            displayPolygon = _applySelectionHighlight(polygon, shapeData.id);
          }
          polygons.add(displayPolygon);
        }
      }
    }

    List<Widget> layers = [];
    if (polygons.isNotEmpty) layers.add(PolygonLayer(polygons: polygons, polygonCulling: options.polygonCulling));
    if (polylines.isNotEmpty) layers.add(PolylineLayer(polylines: polylines, polylineCulling: options.polylineCulling));
    if (circles.isNotEmpty) layers.add(CircleLayer(circles: circles, circleCulling: options.circleCulling));
    if (markers.isNotEmpty) layers.add(MarkerLayer(markers: markers));
    
    return layers;
  }
  
  List<Widget> _buildInProgressMultiPartLayers() {
    if (!drawingState.isMultiPartDrawingInProgress || drawingState.currentDrawingParts.length <= 1) {
      // Only render if there are completed parts (more than just the active segment)
      return [];
    }

    List<Polygon> completedPolygons = [];
    List<Polyline> completedPolylines = [];
    
    // Iterate over all parts except the last one (which is the active segment handled by PolyEditorManager)
    for (int i = 0; i < drawingState.currentDrawingParts.length - 1; i++) {
      List<LatLng> partPoints = drawingState.currentDrawingParts[i];
      if (partPoints.isEmpty) continue;

      if (drawingState.activeMultiPartTool == DrawingTool.polygon || drawingState.activeMultiPartTool == DrawingTool.multiPolygon) {
        if (partPoints.length < 3) continue; // Not enough points for a polygon
        List<LatLng> closedPartPoints = List.from(partPoints);
        if (closedPartPoints.first.latitude != closedPartPoints.last.latitude || closedPartPoints.first.longitude != closedPartPoints.last.longitude) {
          closedPartPoints.add(closedPartPoints.first);
        }
        completedPolygons.add(Polygon(
          points: closedPartPoints,
          color: options.completedPartFillColor ?? options.drawingFillColor.withOpacity(0.5),
          borderColor: options.completedPartColor ?? options.validDrawingColor.withOpacity(0.7),
          borderStrokeWidth: options.defaultBorderStrokeWidth, // Use option
          isFilled: true,
        ));
      } else if (drawingState.activeMultiPartTool == DrawingTool.polyline || drawingState.activeMultiPartTool == DrawingTool.multiPolyline) {
        if (partPoints.length < 2) continue; // Not enough points for a polyline
        completedPolylines.add(Polyline(
          points: partPoints,
          color: options.completedPartColor ?? options.validDrawingColor.withOpacity(0.7),
          strokeWidth: options.defaultStrokeWidth, // Use option
        ));
      }
    }

    List<Widget> layers = [];
    if (completedPolygons.isNotEmpty) {
      layers.add(PolygonLayer(polygons: completedPolygons, polygonCulling: options.polygonCulling));
    }
    if (completedPolylines.isNotEmpty) {
      layers.add(PolylineLayer(polylines: completedPolylines, polylineCulling: options.polylineCulling));
    }
    return layers;
  }

  List<Widget> _buildTemporaryAndDraftShapesLayers() {
    List<Widget> layers = [];
    ShapeData? shapeToRender;
    // bool isTemporary = false; // isTemporary flag seems unused with new logic

    if (drawingState.draftShapeDataWhileDragging != null && 
        (drawingState.activeEditMode == EditMode.dragging || 
         drawingState.activeEditMode == EditMode.scaling || 
         drawingState.activeEditMode == EditMode.rotating)) {
      shapeToRender = drawingState.draftShapeDataWhileDragging;
    } else if (drawingState.temporaryShape != null && 
               (drawingState.currentTool == DrawingTool.circle || 
                drawingState.currentTool == DrawingTool.rectangle ||
                drawingState.currentTool == DrawingTool.square ||
                // Add other tools that use temporaryShape.
                // Note: Pentagon, Hexagon, Octagon might use temporaryShape if they are drawn via a two-point drag.
                drawingState.currentTool == DrawingTool.pentagon ||
                drawingState.currentTool == DrawingTool.hexagon ||
                drawingState.currentTool == DrawingTool.octagon 
               )) {
      shapeToRender = drawingState.temporaryShape;
      // isTemporary = true; // Unused
    }
    
    if (shapeToRender == null) return layers; // layers is not defined here, should be: if (shapeToRender == null) return [];


    List<Widget> tempLayers = []; // Define tempLayers here

    if (shapeToRender is PolygonShapeData) {
      tempLayers.add(PolygonLayer(polygons: [shapeToRender.polygon], polygonCulling: options.polygonCulling));
    } else if (shapeToRender is PolylineShapeData) { 
      tempLayers.add(PolylineLayer(polylines: [shapeToRender.polyline], polylineCulling: options.polylineCulling));
    } else if (shapeToRender is CircleShapeData) {
      tempLayers.add(CircleLayer(circles: [shapeToRender.circleMarker], circleCulling: options.circleCulling));
    }

    return tempLayers;
  }

  List<Widget> _buildPolyEditorLayers() {
    // Accessing internal _isActive. Consider exposing a getter in PolyEditorManager if this direct access is undesirable.
    if (!polyEditorManager.instance!.isActive) return []; 

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
          width: options.vertexHandleRadius * 2.5, 
          height: options.vertexHandleRadius * 2.5,
          offset: Offset(options.vertexHandleRadius * 1.25, options.vertexHandleRadius * 1.25), // Adjust to center if icon anchor is top-left
          child: options.getResizeHandleIcon(), // Use the new helper
          onDragUpdate: (details, newPos) {
            // In DrawingLayerCoordinator: shapeEditManager.handleResize("circle_radius_handle", newPos);
          },
          onDragEnd: (details) {
            // Potentially call confirmEdit or let user do it via toolbar
          },
        ));
      }
      // TODO: Add handles for rectangles if they are not PolyShapeData edited by PolyEditor
    } else if (shape is PolygonShapeData && shape.polygon.points.isNotEmpty) {
        // Example: Add a scaling handle to the last point of the polygon
        // This is a simplified example. Proper handles would be at corners of a bounding box.
        LatLng lastPoint = shape.polygon.points.last; 
        
        // If the shape is rotated, the handle's visual position needs to account for this.
        // This requires access to MapTransformer here or pre-rotated points for handles.
        // For simplicity, let's assume for now the handle is based on the raw point,
        // and ShapeEditManager's handleResize knows how to interpret it with rotation.
        // A more accurate approach would be to calculate the rotated position of this handle.
        // Let's assume `shape.centroid` and `shape.rotationAngle` are available.
        // And we have a _rotatePoint utility (similar to the one in ShapeEditManager).
        // LatLng rotatedHandlePos = _rotatePoint(lastPoint, shape.centroid, shape.rotationAngle, mapTransformer);
        // This ^ requires mapTransformer. For now, use raw point.

        handles.add(DragMarker(
          point: lastPoint, // Ideally, this is the rotated position of the handle's anchor
          width: options.vertexHandleRadius * 2.5,
          height: options.vertexHandleRadius * 2.5,
          offset: Offset(options.vertexHandleRadius * 1.25, options.vertexHandleRadius * 1.25),
          child: options.getResizeHandleIcon(), // A generic scale icon
          onDragStart: (details, point) {
            // Notify ShapeEditManager that a specific handle drag has started.
            // This helps ShapeEditManager determine the anchor point for scaling.
            // For example, if this is the "bottom-right" handle, the anchor is "top-left".
            // _shapeEditManager.startHandleInteraction(shape, "polygon_corner_br", point);
          },
          onDragUpdate: (details, newPos) {
            // Pass a handleId that ShapeEditManager can use
            // For this example, "polygon_corner_br" implies bottom-right.
            // In a real system, this would be derived from which handle was actually created/dragged.
            // _shapeEditManager.handleResize("polygon_corner_br", newPos); 
            // The above line should be:
            // widget.shapeEditManager.handleResize("polygon_corner_br", newPos);
            // but DrawingRenderer doesn't have direct access to ShapeEditManager instance
            // This interaction needs to be plumbed through DrawingLayerCoordinator
            // For now, this is a conceptual placement.
          },
          onDragEnd: (details) {
            // _shapeEditManager.endHandleInteraction();
          },
        ));
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
        borderColor: options.selectionHighlightColor, // Corrected option
        borderStrokeWidth: (shape.borderStrokeWidth ?? options.defaultBorderStrokeWidth) + options.selectionHighlightBorderWidth,
      ) as T;
    } else if (shape is Polyline) {
      return shape.copyWith(
        color: options.selectionHighlightColor, // Corrected option
        // Assuming strokeWidth is the primary visual for polyline selection thickness
        strokeWidth: shape.strokeWidth + options.selectionHighlightBorderWidth,
      ) as T;
    } else if (shape is CircleMarker) {
      return shape.copyWith(
        borderColor: options.selectionHighlightColor, // Corrected option
        borderStrokeWidth: (shape.borderStrokeWidth ?? options.defaultBorderStrokeWidth) + options.selectionHighlightBorderWidth,
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
