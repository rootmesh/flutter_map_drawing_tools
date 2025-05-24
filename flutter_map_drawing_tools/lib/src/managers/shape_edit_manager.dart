import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart'; // For EditMode
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map/plugin_api.dart'; // For MapTransformer
import 'dart:math' as math;

// Callback for when an edit is applied and the UI might need a refresh
typedef OnEditFinalizedCallback = void Function(ShapeData updatedShape);
typedef OnEditCancelledCallback = void Function(ShapeData originalShape);

class ShapeEditManager {
  final DrawingState drawingState;
  final DrawingToolsOptions options;
  final MapController mapController; // For map interaction control if needed

  MapTransformer? _mapTransformer; // Will be updated via a method

  // State for active editing
  LatLng? _dragStartLatLng; // Geographical position where dragging started
  ShapeData? _initialShapeDataForEdit; // Shape state when dragging started, relative to originalShapeDataBeforeDrag

  ShapeEditManager({
    required this.drawingState,
    required this.options,
    required this.mapController,
  });

  void updateMapTransformer(MapTransformer transformer) {
    _mapTransformer = transformer;
  }

  /// Call this when a shape is selected and an edit mode (dragging, scaling, rotating) is activated.
  /// This method assumes `drawingState.selectedShapeId` and `drawingState.originalShapeDataBeforeDrag` are already set.
  void onEditModeChanged() {
    if (drawingState.selectedShapeId != null && drawingState.activeEditMode != EditMode.none) {
      // If there's no draft yet (e.g. first time entering this mode for the selected shape),
      // set the draft to be the same as the original to start with.
      if (drawingState.draftShapeDataWhileDragging == null || drawingState.draftShapeDataWhileDragging!.id != drawingState.selectedShapeId) {
         // originalShapeDataBeforeDrag should be the pristine copy from before any edits in this selection session
        drawingState.setDraftShapeDataWhileDragging(drawingState.originalShapeDataBeforeDrag?.copy());
      }
       _initialShapeDataForEdit = drawingState.draftShapeDataWhileDragging?.copy(); // The current draft becomes the base for this specific drag operation
    } else {
      _resetEditState();
    }
  }


  /// Handles map events for editing operations like dragging, scaling, rotating.
  void handleMapEvent(MapEvent event) {
    if (drawingState.selectedShapeId == null || drawingState.originalShapeDataBeforeDrag == null) {
      _resetEditState();
      return;
    }
    if (_mapTransformer == null) return; // Ensure transformer is available

    // The actual shape being manipulated during drag/scale/rotate is drawingState.draftShapeDataWhileDragging
    // drawingState.originalShapeDataBeforeDrag is the reference if the user cancels.

    final currentEditMode = drawingState.activeEditMode;

    if (event is MapEventPointerDown) {
      if (currentEditMode == EditMode.dragging) {
        _dragStartLatLng = event.pointerPosition;
        _initialShapeDataForEdit = drawingState.draftShapeDataWhileDragging?.copy() ?? drawingState.originalShapeDataBeforeDrag?.copy();
        _setMapInteractive(false); // Disable map panning/zooming during shape drag
      }
    } else if (event is MapEventPointerMove && event.original?.buttons == kPrimaryMouseButton) {
      if (currentEditMode == EditMode.dragging && _dragStartLatLng != null && _initialShapeDataForEdit != null) {
        _handleShapeDrag(event.pointerPosition);
      }
    } else if (event is MapEventPointerUp) {
      if (currentEditMode == EditMode.dragging) {
        if (_dragStartLatLng != null) {
          // Dragging is finalized by the ContextualToolbar's confirm/cancel,
          // so pointer up here just means the gesture ended. The draft remains.
          _dragStartLatLng = null;
          // _initialShapeDataForEdit remains as is until next drag or confirm/cancel
        }
        _setMapInteractive(true); // Re-enable map interaction
      }
    }
  }

  void _handleShapeDrag(LatLng currentDragLatLng) {
    if (_dragStartLatLng == null || _initialShapeDataForEdit == null) return;

    double latDiff = currentDragLatLng.latitude - _dragStartLatLng!.latitude;
    double lngDiff = currentDragLatLng.longitude - _dragStartLatLng!.longitude;

    ShapeData? newDraftShape;

    if (_initialShapeDataForEdit is PolygonShapeData) {
      final initialPolygon = (_initialShapeDataForEdit as PolygonShapeData).polygon;
      List<LatLng> newPoints = initialPolygon.points.map((p) => LatLng(p.latitude + latDiff, p.longitude + lngDiff)).toList();
      List<List<LatLng>>? newHolePointsList;
      if (initialPolygon.holePointsList != null) {
        newHolePointsList = initialPolygon.holePointsList!
            .map((hole) => hole.map((p) => LatLng(p.latitude + latDiff, p.longitude + lngDiff)).toList())
            .toList();
      }
      newDraftShape = (_initialShapeDataForEdit as PolygonShapeData).copyWithPolygon(
        initialPolygon.copyWithGeometry(points: newPoints, holePointsList: newHolePointsList),
      );
    } else if (_initialShapeDataForEdit is PolylineShapeData) {
      final initialPolyline = (_initialShapeDataForEdit as PolylineShapeData).polyline;
      List<LatLng> newPoints = initialPolyline.points.map((p) => LatLng(p.latitude + latDiff, p.longitude + lngDiff)).toList();
      newDraftShape = (_initialShapeDataForEdit as PolylineShapeData).copyWithPolyline(
        initialPolyline.copyWithGeometry(points: newPoints),
      );
    } else if (_initialShapeDataForEdit is CircleShapeData) {
      final initialCircle = (_initialShapeDataForEdit as CircleShapeData).circleMarker;
      LatLng newCenter = LatLng(initialCircle.point.latitude + latDiff, initialCircle.point.longitude + lngDiff);
      newDraftShape = (_initialShapeDataForEdit as CircleShapeData).copyWithCircleMarker(
        initialCircle.copyWith(point: newCenter),
      );
    } else if (_initialShapeDataForEdit is MarkerShapeData) {
      final initialMarker = (_initialShapeDataForEdit as MarkerShapeData).marker;
      LatLng newPoint = LatLng(initialMarker.point.latitude + latDiff, initialMarker.point.longitude + lngDiff);
      newDraftShape = (_initialShapeDataForEdit as MarkerShapeData).copyWithMarker(
        initialMarker.copyWith(point: newPoint),
      );
    }

    if (newDraftShape != null) {
      drawingState.setDraftShapeDataWhileDragging(newDraftShape);
    }
  }

  /// Called when a resize handle is dragged.
  /// [handleId] identifies which handle was dragged (e.g., "top-left", "middle-right", or an index).
  /// [dragPosition] is the new geographical position of the dragged handle.
  /// This method assumes `drawingState.draftShapeDataWhileDragging` holds the current state of the shape being edited.
  void handleResize(String handleId, LatLng dragPosition) {
    if (drawingState.draftShapeDataWhileDragging == null || drawingState.originalShapeDataBeforeDrag == null || _mapTransformer == null) return;

    // Use originalShapeDataBeforeDrag as the stable base for calculating scaled shape,
    // but apply to the current draft's appearance (color, etc.) if needed.
    // Or, more simply, scale based on the current draftShapeDataWhileDragging.
    // Let's use _initialShapeDataForEdit which is set when scaling/dragging starts.
    // This avoids cumulative errors if scaling from the continuously updated draft.

    final shapeToScale = _initialShapeDataForEdit ?? drawingState.originalShapeDataBeforeDrag!;
    ShapeData? newDraftShape;

    // Convert current handle position and shape points to screen coordinates for easier calculation
    final centerGeo = shapeToScale.centroid;
    if (centerGeo == null) return; // Cannot scale if no center (should not happen for scalable shapes)

    // This is a simplified example. A robust solution would need to:
    // 1. Identify the fixed point opposite the dragged handle.
    // 2. Calculate scale factor based on mouse movement relative to the fixed point.
    // 3. Apply this scale factor to all points of the shape.
    // For shapes like rectangles, scaling is relative to the opposite corner/edge.
    // For circles, it's relative to the center.

    if (shapeToScale is CircleShapeData) {
      final radius = const Distance().as(LengthUnit.Meter, centerGeo, dragPosition);
      if (radius > 0) {
        newDraftShape = (drawingState.draftShapeDataWhileDragging as CircleShapeData).copyWithCircleMarker(
          (drawingState.draftShapeDataWhileDragging as CircleShapeData).circleMarker.copyWith(radius: radius)
        );
      }
    } else if (shapeToScale is PolygonShapeData) {
      // Placeholder for complex polygon scaling.
      // This would involve identifying which handle was dragged, calculating scale factors,
      // and transforming points relative to an anchor point (e.g., opposite handle or centroid).
      // For simplicity, we'll imagine a basic scaling from centroid for now.
      final initialPolygon = shapeToScale.polygon;
      final initialPoints = initialPolygon.points;
      if (initialPoints.isEmpty) return;

      CustomPoint centerPixel = _mapTransformer!.latLngToPixel(centerGeo, _mapTransformer!.centerZoom.zoom);
      CustomPoint handlePixel = _mapTransformer!.latLngToPixel(dragPosition, _mapTransformer!.centerZoom.zoom);
      
      // Find the original handle position to calculate scale factor
      // This requires knowing which handleId corresponds to which point or how to calculate it.
      // This part is complex and depends on handle setup.
      // For a very naive example, let's assume handleId gives us an index of a point to scale relative to center.
      // This is NOT a correct general scaling implementation.
      if (initialPoints.isNotEmpty) {
          CustomPoint originalHandlePixel;
          // This is a guess, proper handle management is needed
          if(handleId == "center_for_radius_scale" && shapeToScale is CircleShapeData) { // Special case for circle if we drag edge
             // Find point on circumference that was conceptually dragged
             originalHandlePixel = _mapTransformer!.latLngToPixel(
                const Distance(meters: (shapeToScale as CircleShapeData).circleMarker.radius)
                    .offset(centerGeo, 90), // Arbitrary bearing
                _mapTransformer!.centerZoom.zoom
             );
          } else {
             // Attempt to find a corresponding point on the original shape if handleId is an index or similar
             // This is highly dependent on how handles are defined and identified.
             // For now, this part will be very approximate.
             // A real implementation needs a mapping from handleId to a specific vertex or control point.
             LatLng? originalHandleGeo; 
             // Try to find a point on the polygon that corresponds to the handle based on its ID
             // This is a placeholder for more sophisticated handle logic.
             // Example: if handleId is an index "0", "1", etc.
             try {
                int pointIndex = int.parse(handleId);
                if(pointIndex < initialPoints.length) originalHandleGeo = initialPoints[pointIndex];
             } catch (e) { /* not an index */ }

             if(originalHandleGeo == null && initialPoints.length > 0) originalHandleGeo = initialPoints.first; // fallback
             if(originalHandleGeo == null) return;

             originalHandlePixel = _mapTransformer!.latLngToPixel(originalHandleGeo, _mapTransformer!.centerZoom.zoom);
          }


          double scaleFactorX = (handlePixel.x - centerPixel.x) / (originalHandlePixel.x - centerPixel.x);
          double scaleFactorY = (handlePixel.y - centerPixel.y) / (originalHandlePixel.y - centerPixel.y);

          if ((originalHandlePixel.x - centerPixel.x).abs() < 1e-3) scaleFactorX = 1.0; // Avoid division by zero
          if ((originalHandlePixel.y - centerPixel.y).abs() < 1e-3) scaleFactorY = 1.0;


          if (!scaleFactorX.isFinite || scaleFactorX == 0) scaleFactorX = 1.0;
          if (!scaleFactorY.isFinite || scaleFactorY == 0) scaleFactorY = 1.0;
          
          // For uniform scaling, use the average or max of scaleFactorX and scaleFactorY, or based on handle type
          // For this placeholder, let's assume non-uniform scaling is possible for polygons:
          
          List<LatLng> newPoints = initialPolygon.points.map((p) {
            CustomPoint pointPixel = _mapTransformer!.latLngToPixel(p, _mapTransformer!.centerZoom.zoom);
            double newX = centerPixel.x + (pointPixel.x - centerPixel.x) * scaleFactorX;
            double newY = centerPixel.y + (pointPixel.y - centerPixel.y) * scaleFactorY;
            return _mapTransformer!.pixelToLatLng(CustomPoint(newX, newY), _mapTransformer!.centerZoom.zoom);
          }).toList();

          List<List<LatLng>>? newHolePointsList;
            if (initialPolygon.holePointsList != null) {
                newHolePointsList = initialPolygon.holePointsList!.map((hole) {
                    return hole.map((p) {
                        CustomPoint pointPixel = _mapTransformer!.latLngToPixel(p, _mapTransformer!.centerZoom.zoom);
                        double newX = centerPixel.x + (pointPixel.x - centerPixel.x) * scaleFactorX;
                        double newY = centerPixel.y + (pointPixel.y - centerPixel.y) * scaleFactorY;
                        return _mapTransformer!.pixelToLatLng(CustomPoint(newX, newY), _mapTransformer!.centerZoom.zoom);
                    }).toList();
                }).toList();
            }

          newDraftShape = (drawingState.draftShapeDataWhileDragging as PolygonShapeData).copyWithPolygon(
            (drawingState.draftShapeDataWhileDragging as PolygonShapeData).polygon.copyWithGeometry(points: newPoints, holePointsList: newHolePointsList)
          );
      }
    }
    // Add Polyline scaling if necessary

    if (newDraftShape != null) {
      drawingState.setDraftShapeDataWhileDragging(newDraftShape);
    }
  }

  /// Called when a rotation handle is dragged.
  /// [dragPosition] is the new geographical position of the rotation handle.
  void handleRotate(LatLng dragPosition) {
    if (drawingState.draftShapeDataWhileDragging == null || drawingState.originalShapeDataBeforeDrag == null || _mapTransformer == null) return;

    final shapeToRotate = _initialShapeDataForEdit ?? drawingState.originalShapeDataBeforeDrag!;
    final centerGeo = shapeToRotate.centroid;
    if (centerGeo == null) return; // Cannot rotate if no center

    // Calculate angle: from center to original handle position, vs center to new handle position
    // This requires knowing the original rotation handle's position relative to the shape.
    // For simplicity, calculate angle based on an initial reference point (e.g., north of center)
    // vs current drag position.

    CustomPoint centerPixel = _mapTransformer!.latLngToPixel(centerGeo, _mapTransformer!.centerZoom.zoom);
    CustomPoint dragPixel = _mapTransformer!.latLngToPixel(dragPosition, _mapTransformer!.centerZoom.zoom);

    // Angle of the vector from center to drag position
    double newAngleRadians = math.atan2(dragPixel.y - centerPixel.y, dragPixel.x - centerPixel.x);
    
    // Get the original angle. This requires knowing the shape's orientation *before* this current drag operation started.
    // Let's assume _initialShapeDataForEdit holds the orientation if it has one, or we calculate from a reference point.
    // For this example, we'll assume the rotation is applied to the points of _initialShapeDataForEdit.
    // A more robust system would store an explicit `rotationAngle` on ShapeData if possible.

    // To get the delta rotation, we need the angle of the rotation handle when the drag started.
    // This is complex without a dedicated rotation handle object.
    // Simplified: we calculate total rotation from a fixed reference (e.g. East)
    // And then apply this total rotation to the *original* points of the shape from drawingState.originalShapeDataBeforeDrag

    ShapeData? newDraftShape;

    if (shapeToRotate is PolygonShapeData) {
      final originalPolygon = (drawingState.originalShapeDataBeforeDrag as PolygonShapeData).polygon; // Rotate the true original
      List<LatLng> rotatedPoints = originalPolygon.points.map((p) {
        return _rotatePoint(p, centerGeo, newAngleRadians, _mapTransformer!);
      }).toList();
      List<List<LatLng>>? rotatedHolePointsList;
      if (originalPolygon.holePointsList != null) {
        rotatedHolePointsList = originalPolygon.holePointsList!.map((hole) {
          return hole.map((p) => _rotatePoint(p, centerGeo, newAngleRadians, _mapTransformer!)).toList();
        }).toList();
      }
      // Apply this rotation to the current draft's appearance (color etc)
      newDraftShape = (drawingState.draftShapeDataWhileDragging as PolygonShapeData).copyWithPolygon(
        (drawingState.draftShapeDataWhileDragging as PolygonShapeData).polygon.copyWithGeometry(points: rotatedPoints, holePointsList: rotatedHolePointsList)
      );
    } else if (shapeToRotate is PolylineShapeData) {
       final originalPolyline = (drawingState.originalShapeDataBeforeDrag as PolylineShapeData).polyline;
       List<LatLng> rotatedPoints = originalPolyline.points.map((p) {
        return _rotatePoint(p, centerGeo, newAngleRadians, _mapTransformer!);
      }).toList();
       newDraftShape = (drawingState.draftShapeDataWhileDragging as PolylineShapeData).copyWithPolyline(
        (drawingState.draftShapeDataWhileDragging as PolylineShapeData).polyline.copyWithGeometry(points: rotatedPoints)
      );
    }
    // Circles are rotation invariant around their center. Markers might have a rotation property.
    // Markers would need an explicit `angle` property on `MarkerData` to be rotated.

    if (newDraftShape != null) {
      drawingState.setDraftShapeDataWhileDragging(newDraftShape);
    }
  }

  LatLng _rotatePoint(LatLng point, LatLng center, double angleRadians, MapTransformer transformer) {
    CustomPoint pointPixel = transformer.latLngToPixel(point, transformer.centerZoom.zoom);
    CustomPoint centerPixel = transformer.latLngToPixel(center, transformer.centerZoom.zoom);

    double s = math.sin(angleRadians);
    double c = math.cos(angleRadians);

    // Translate point back to origin
    double px = pointPixel.x - centerPixel.x;
    double py = pointPixel.y - centerPixel.y;

    // Rotate point
    double xnew = px * c - py * s;
    double ynew = px * s + py * c;

    // Translate point back
    px = xnew + centerPixel.x;
    py = ynew + centerPixel.y;

    return transformer.pixelToLatLng(CustomPoint(px, py), transformer.centerZoom.zoom);
  }


  /// Confirms the current edit operation.
  /// The shape in `drawingState.currentShapes` is updated with `drawingState.draftShapeDataWhileDragging`.
  void confirmEdit() {
    if (drawingState.selectedShapeId != null && drawingState.draftShapeDataWhileDragging != null) {
      final updatedShape = drawingState.draftShapeDataWhileDragging!;
      drawingState.updateShape(updatedShape); // This should replace the shape in currentShapes
      // drawingState.onShapeUpdated?.call(updatedShape); // Callback via drawingState listener
    }
    _resetEditStateAfterConfirmOrCancel();
  }

  /// Cancels the current edit operation.
  /// The shape in `drawingState.currentShapes` is reverted to `drawingState.originalShapeDataBeforeDrag`.
  void cancelEdit() {
    if (drawingState.selectedShapeId != null && drawingState.originalShapeDataBeforeDrag != null) {
      drawingState.updateShape(drawingState.originalShapeDataBeforeDrag!); // Revert
      // drawingState.onShapeUpdated?.call(drawingState.originalShapeDataBeforeDrag!); // Callback via drawingState listener
    }
    _resetEditStateAfterConfirmOrCancel();
  }

  void _resetEditStateAfterConfirmOrCancel() {
    drawingState.setDraftShapeDataWhileDragging(null);
    drawingState.setOriginalShapeDataBeforeDrag(null); // Clear the specific "before drag" copy
    // Note: drawingState.selectedShapeId and activeEditMode are typically reset by ContextualToolbar or DrawingLayerCoordinator
    _dragStartLatLng = null;
    _initialShapeDataForEdit = null;
     _setMapInteractive(true); // Ensure map is interactive
  }
  
  void _resetEditState() {
    _dragStartLatLng = null;
    _initialShapeDataForEdit = null;
     _setMapInteractive(true); // Ensure map is interactive
    // Don't clear draft/original here, as this might be called during mode switches
    // where the draft should persist. _resetEditStateAfterConfirmOrCancel is for final cleanup.
  }


  void _setMapInteractive(bool interactive) {
    // If mapController is not available or flags are already set, do nothing.
    try {
        if (interactive) {
            mapController.options.flags |= MapInteractiveFlags.all;
        } else {
            mapController.options.flags &= ~MapInteractiveFlags.drag & ~MapInteractiveFlags.flingAnimation & ~MapInteractiveFlags.pinchMove & ~MapInteractiveFlags.doubleTapZoom;
            // Allow zoom and rotate unless explicitly disabled for an operation
        }
    } catch (e) {
        // Could be that mapController is not fully initialized or disposed.
        debugPrint("ShapeEditManager: Error accessing mapController options flags: $e");
    }
  }

  void dispose() {
    // Reset any lingering state, e.g. ensure map interaction is enabled
    _setMapInteractive(true);
  }
}


// Extensions for copyWith on geometry (points, radius etc.) for ShapeData models
// These should ideally be part of the ShapeData models themselves.
// Adding them here for now if they are not already present.

extension _PolygonShapeDataCopyWithExt on PolygonShapeData {
    PolygonShapeData copyWithPolygon(Polygon newPolygon) {
        return PolygonShapeData(
            polygon: newPolygon,
            id: id,
            label: label,
        );
    }
}

extension _PolylineShapeDataCopyWithExt on PolylineShapeData {
    PolylineShapeData copyWithPolyline(Polyline newPolyline) {
        return PolylineShapeData(
            polyline: newPolyline,
            id: id,
            label: label,
        );
    }
}

extension _CircleShapeDataCopyWithExt on CircleShapeData {
    CircleShapeData copyWithCircleMarker(CircleMarker newCircleMarker) {
        return CircleShapeData(
            circleMarker: newCircleMarker,
            id: id,
            label: label,
        );
    }
}

extension _MarkerShapeDataCopyWithExt on MarkerShapeData {
    MarkerShapeData copyWithMarker(Marker newMarker) {
        return MarkerShapeData(
            marker: newMarker,
            id: id,
            label: label,
        );
    }
}
