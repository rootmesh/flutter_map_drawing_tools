import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'dart:math' as math;

// Callback for when a new shape is created and should be added to the main list
typedef OnShapeFinalizedCallback = void Function(ShapeData shape);

class NewShapeGestureManager {
  final DrawingState drawingState;
  final DrawingToolsOptions options;
  final MapController mapController; // Needed for disabling map interaction
  final OnShapeFinalizedCallback onShapeFinalized;

  // Temporary state for drawing
  ShapeData? _draftShapeData;
  LatLng? _startDragPoint;
  bool _isDrawingCircleRadius = false; // True if currently dragging to define circle radius
  bool _isCurrentDraftInvalid = false; // NEW: Tracks if the current draft is invalid

  NewShapeGestureManager({
    required this.drawingState,
    required this.options,
    required this.mapController,
    required this.onShapeFinalized,
  });

  // Main handler for map events
  void handleMapEvent(MapEvent event, MapTransformer mapTransformer) {
    if (drawingState.currentTool == DrawingTool.none || drawingState.currentTool == DrawingTool.edit || drawingState.currentTool == DrawingTool.delete) {
      _resetDrawingState();
      return;
    }

    // Disable map interaction during certain drawing phases
    if (_isDrawingCircleRadius || (drawingState.currentTool == DrawingTool.rectangle && _startDragPoint != null)) {
      _setMapInteractive(false);
    }

    if (event is MapEventTap) {
      _handleTap(event, mapTransformer);
    } else if (event is MapEventPointerDown) {
      _handlePointerDown(event, mapTransformer);
    } else if (event is MapEventPointerMove && event.original?.buttons == kPrimaryMouseButton) {
      _handlePointerMove(event, mapTransformer);
    } else if (event is MapEventPointerUp) {
      _handlePointerUp(event, mapTransformer);
    }
  }

  void _handleTap(MapEventTap event, MapTransformer mapTransformer) {
    final tapPosition = event.tapPosition;

    switch (drawingState.currentTool) {
      case DrawingTool.polygon:
      case DrawingTool.polyline:
        // Validation for individual points in polygons/polylines will be handled by PolyEditorManager
        if (!drawingState.isMultiPartDrawingInProgress) {
          drawingState.startNewDrawingPart(drawingState.currentTool);
        }
        drawingState.addPointToCurrentPart(tapPosition);
        break;
      case DrawingTool.point:
        // Perform validation for point placement
        _isCurrentDraftInvalid = !(options.validateShapePlacement?.call([tapPosition]) ?? true);
        if (_isCurrentDraftInvalid) {
          options.onPlacementInvalid?.call("Point placement is not allowed here.");
          // Potentially show a temporary invalid marker if desired, then _resetDrawingState in finalize
        }
        _finalizePoint(tapPosition); // finalizePoint will check _isCurrentDraftInvalid
        if (!_isCurrentDraftInvalid) { // Only deselect tool if point was successfully placed
            drawingState.setCurrentTool(DrawingTool.none); 
        }
        break;
      case DrawingTool.circle:
        if (!_isDrawingCircleRadius) {
          _startDrawingCircle(tapPosition); // Validation is inside _startDrawingCircle
        } else {
          // Second tap could finalize, check validity
          _validateCurrentDraftCircle(); // Update _isCurrentDraftInvalid
          if (!_isCurrentDraftInvalid) {
            _finalizeCircle(); // finalizeCircle will check _isCurrentDraftInvalid again but this is fine
          } else {
            // If invalid, the tap doesn't finalize, user might try to move more or cancel.
            // Optionally, could reset if a second tap on invalid is meant to cancel.
            options.onPlacementInvalid?.call("Circle placement is not allowed here.");
          }
        }
        break;
      case DrawingTool.rectangle:
      case DrawingTool.square: 
         // Rectangles are drawn by drag. Tap might select or do nothing.
        break;
      default:
        break;
    }
  }

  void _handlePointerDown(MapEventPointerDown event, MapTransformer mapTransformer) {
    _startDragPoint = event.pointerPosition;

    switch (drawingState.currentTool) {
      case DrawingTool.circle:
        if (!_isDrawingCircleRadius) { 
          _startDrawingCircle(event.pointerPosition); // Validation is inside _startDrawingCircle
        }
        break;
      case DrawingTool.rectangle:
      case DrawingTool.square:
        _isCurrentDraftInvalid = false; // Reset before starting new shape
        drawingState.clearTemporaryShape(); 
        
        // Initial degenerate rectangle (all points same)
        final initialPoints = [_startDragPoint!, _startDragPoint!, _startDragPoint!, _startDragPoint!];
        _draftShapeData = PolygonShapeData(
          polygon: Polygon(
            points: initialPoints, 
            color: options.drawingFillColor, // Use drawingFillColor
            borderColor: options.temporaryLineColor,
            borderStrokeWidth: options.defaultBorderStrokeWidth, // Use option
            isFilled: true,
          ),
          id: "draft_rectangle_${DateTime.now().millisecondsSinceEpoch}" 
        );
        
        // Validate initial point
        if (options.validateShapePlacement != null && !options.validateShapePlacement!(initialPoints.sublist(0,1))) {
          _isCurrentDraftInvalid = true;
          options.onPlacementInvalid?.call("Rectangle starting point is not allowed here.");
          // Update color to invalid
          _draftShapeData = (_draftShapeData as PolygonShapeData).copyWithColor(
              options.invalidDrawingColor.withOpacity(options.drawingFillColor.opacity), // Consistent opacity
              options.invalidDrawingColor);
        }
        drawingState.setTemporaryShape(_draftShapeData);
        _setMapInteractive(false);
        break;
      default:
        _startDragPoint = null; // Not relevant for other tools
        break;
    }
  }

  void _handlePointerMove(MapEventPointerMove event, MapTransformer mapTransformer) {
    if (_startDragPoint == null) return;

    final currentDragPoint = event.pointerPosition;

    switch (drawingState.currentTool) {
      case DrawingTool.circle:
        if (_isDrawingCircleRadius && _draftShapeData is CircleShapeData) {
          final center = (_draftShapeData as CircleShapeData).circleMarker.point;
          final radius = const Distance().as(LengthUnit.Meter, center, currentDragPoint);
          _draftShapeData = CircleShapeData(
            circleMarker: CircleMarker(
              point: center,
              radius: radius,
              color: options.drawingFillColor, // Use drawingFillColor
              borderColor: options.temporaryLineColor,
              borderStrokeWidth: options.defaultStrokeWidth, // Use option for circles
              useRadiusInMeter: true,
            ),
            id: (_draftShapeData as CircleShapeData).id 
          );
          _validateCurrentDraftCircle(); // Sets _isCurrentDraftInvalid and updates color
          drawingState.setTemporaryShape(_draftShapeData);
        }
        break;
      case DrawingTool.rectangle:
      case DrawingTool.square:
        if (_draftShapeData is PolygonShapeData) {
          LatLng p1 = _startDragPoint!;
          LatLng p2 = currentDragPoint;
          
          List<LatLng> points;
          if (drawingState.currentTool == DrawingTool.square) {
            double deltaX = (p2.longitude - p1.longitude).abs();
            double deltaY = (p2.latitude - p1.latitude).abs();
            double side = math.max(deltaX, deltaY); // Use screen distance for squareness? For now, geo distance.

            double p2LatSign = (p2.latitude > p1.latitude) ? 1.0 : -1.0;
            double p2LngSign = (p2.longitude > p1.longitude) ? 1.0 : -1.0;

            // Adjust p2 to make it a square relative to p1
            // This geo-space square calculation can be tricky due to map projection.
            // A screen-space square might be more intuitive for users.
            // For now, stick to a geo-space approximation.
            LatLng cornerA = LatLng(p1.latitude, p1.longitude + p2LngSign * side);
            LatLng cornerB = LatLng(p1.latitude + p2LatSign * side, p1.longitude);

            // Choose the point that makes the smaller diagonal to maintain "squareness" better
            // This is still a simplification.
            if (const Distance().distance(p1, cornerA) < const Distance().distance(p1, cornerB)) {
                 p2 = LatLng(p1.latitude + p2LatSign*side, p1.longitude + p2LngSign*side);
            } else {
                 p2 = LatLng(p1.latitude + p2LatSign*side, p1.longitude + p2LngSign*side);
            }
            // Simplified: make side lengths equal in degrees (not accurate for meters)
            // double sideAbs = math.max((p2.latitude - p1.latitude).abs(), (p2.longitude - p1.longitude).abs());
            // p2 = LatLng(p1.latitude + sideAbs * p2LatSign, p1.longitude + sideAbs * p2LngSign);


            points = [
              p1,
              LatLng(p1.latitude, p2.longitude), // (p1.lat, p2.lng)
              p2,                                // (p2.lat, p2.lng)
              LatLng(p2.latitude, p1.longitude), // (p2.lat, p1.lng)
              p1, 
            ];

          } else { // Rectangle
            points = [
              p1,
              LatLng(p1.latitude, p2.longitude),
              p2,
              LatLng(p2.latitude, p1.longitude),
              p1, 
            ];
          }
          
          bool isValid = options.validateShapePlacement?.call(points) ?? true;
          if (!isValid) {
            if (!_isCurrentDraftInvalid) { // Only trigger callback once per invalid drag start
              options.onPlacementInvalid?.call("Rectangle placement is not allowed here.");
            }
            _isCurrentDraftInvalid = true;
          } else {
            _isCurrentDraftInvalid = false;
          }

          _draftShapeData = PolygonShapeData(
            polygon: Polygon(
              points: points,
              color: _isCurrentDraftInvalid ? options.invalidDrawingColor.withOpacity(options.drawingFillColor.opacity) : options.drawingFillColor,
              borderColor: _isCurrentDraftInvalid ? options.invalidDrawingColor : options.temporaryLineColor,
              borderStrokeWidth: options.defaultBorderStrokeWidth, // Use option
              isFilled: true,
            ),
             id: (_draftShapeData as PolygonShapeData).id 
          );
          drawingState.setTemporaryShape(_draftShapeData);
        }
        break;
      default:
        break;
    }
  }

  void _handlePointerUp(MapEventPointerUp event, MapTransformer mapTransformer) {
    // final endDragPoint = event.pointerPosition; // May not be needed if _draftShapeData is up-to-date

    switch (drawingState.currentTool) {
      case DrawingTool.circle:
        if (_isDrawingCircleRadius && _draftShapeData is CircleShapeData) {
          _finalizeCircle();
        }
        break;
      case DrawingTool.rectangle:
      case DrawingTool.square:
        if (_startDragPoint != null && _draftShapeData is PolygonShapeData) {
          _finalizeRectangle();
        }
        break;
      default:
        break;
    }
    _resetDrawingState(); // Common reset for most tools after pointer up
  }

  void _startDrawingCircle(LatLng center) {
    _isCurrentDraftInvalid = false; // Reset before starting new shape
    drawingState.clearTemporaryShape(); 

    // Initial small circle
    _draftShapeData = CircleShapeData(
      circleMarker: CircleMarker(
        point: center,
        radius: 1, 
        color: options.drawingFillColor, // Use drawingFillColor
        borderColor: options.temporaryLineColor,
        borderStrokeWidth: options.defaultStrokeWidth, // Use option for circles
        useRadiusInMeter: true,
      ),
      id: "draft_circle_${DateTime.now().millisecondsSinceEpoch}" 
    );

    _validateCurrentDraftCircle(isInitialPlacement: true); // Validate and set color
    
    drawingState.setTemporaryShape(_draftShapeData);
    _isDrawingCircleRadius = true;
    _startDragPoint = center; 
    _setMapInteractive(false);
  }

  void _validateCurrentDraftCircle({bool isInitialPlacement = false}) {
    if (_draftShapeData is CircleShapeData) {
      final circle = (_draftShapeData as CircleShapeData).circleMarker;
      // Validate based on center point and radius (if applicable)
      // For now, let's assume validation is primarily based on the center point for circles.
      // More complex validation could check radius against other shapes or boundaries.
      bool isValid = options.validateShapePlacement?.call([circle.point]) ?? true;
      if (!isValid) {
        // Only call onPlacementInvalid if the state is changing to invalid, or if it's the initial placement
        if (!_isCurrentDraftInvalid || isInitialPlacement) {
             options.onPlacementInvalid?.call("Circle placement is not allowed here.");
        }
        _isCurrentDraftInvalid = true;
      } else {
        _isCurrentDraftInvalid = false;
      }
      // Update color based on validity
      _draftShapeData = (_draftShapeData as CircleShapeData).copyWithColor(
          _isCurrentDraftInvalid ? options.invalidDrawingColor.withOpacity(options.drawingFillColor.opacity) : options.drawingFillColor,
          _isCurrentDraftInvalid ? options.invalidDrawingColor : options.temporaryLineColor
      );
    }
  }

  void _finalizeCircle() {
    if (_isCurrentDraftInvalid) {
      options.onPlacementInvalid?.call("Cannot finalize: Circle placement is invalid.");
      _resetDrawingState(); // Clear invalid draft
      return;
    }
    if (_draftShapeData is CircleShapeData) {
      final circleData = _draftShapeData as CircleShapeData;
      if (circleData.circleMarker.radius > 0) { 
        final finalCircle = circleData.copyWithColor(
            options.drawingFillColor, // Use drawingFillColor for final fill
            options.validDrawingColor // Use validDrawingColor for final border
        ).copyWithBorderWidth(options.defaultStrokeWidth); // Ensure final border width
        onShapeFinalized(finalCircle);
      }
    }
    _resetDrawingState();
  }

  void _finalizeRectangle() {
    if (_isCurrentDraftInvalid) {
      options.onPlacementInvalid?.call("Cannot finalize: Rectangle placement is invalid.");
      _resetDrawingState(); // Clear invalid draft
      return;
    }
    if (_draftShapeData is PolygonShapeData) {
      final polygonData = _draftShapeData as PolygonShapeData;
      if (polygonData.polygon.points.length >= 4 &&
          (polygonData.polygon.points[0].latitude != polygonData.polygon.points[2].latitude ||
           polygonData.polygon.points[0].longitude != polygonData.polygon.points[2].longitude)
      ) {
        final finalPolygon = polygonData.copyWithColor(
            options.drawingFillColor, // Use drawingFillColor for final fill
            options.validDrawingColor // Use validDrawingColor for final border
        ).copyWithBorderWidth(options.defaultBorderStrokeWidth); // Ensure final border width
        onShapeFinalized(finalPolygon);
      }
    }
    _resetDrawingState();
  }

  void _finalizePoint(LatLng point) {
    if (_isCurrentDraftInvalid) { 
        options.onPlacementInvalid?.call("Cannot finalize: Point placement is invalid.");
        _resetDrawingState(); 
        return;
    }
    final pointShape = MarkerShapeData(
      marker: Marker(
        point: point,
        width: options.pointMarkerSize, // Use option
        height: options.pointMarkerSize, // Use option
        child: options.getPointIcon(null, false), 
      ),
    );
    onShapeFinalized(pointShape);
    // _resetDrawingState() is not called here for points to allow rapid placement.
    // Tool deselection in _handleTap controls this.
    // If _isCurrentDraftInvalid was true, _resetDrawingState happens, and tool isn't deselected.
  }

  // Call this to finalize a multi-part shape (polygon or polyline).
  // This would typically be called from a UI button.
  // Assumes PolyEditorManager has already validated individual segments during drawing.
  // This method performs a final validation on the assembled shape.
  void finalizeMultiPartShape() {
    if (!drawingState.isMultiPartDrawingInProgress) return;

    final toolWas = drawingState.activeMultiPartTool;
    final List<List<LatLng>> parts = drawingState.consumeDrawingParts(); 

    if (parts.isEmpty || parts.first.isEmpty) {
      drawingState.setCurrentTool(DrawingTool.none);
      return;
    }

    if (toolWas == DrawingTool.polygon) {
      List<LatLng> exteriorRingPoints = List.from(parts.first);
      if (exteriorRingPoints.length < 3) {
        options.onPlacementInvalid?.call("Polygon requires at least 3 points for the exterior ring.");
        drawingState.setCurrentTool(DrawingTool.none);
        return;
      }
      // Ensure polygon is closed for consistent processing and validation
      if (exteriorRingPoints.first.latitude != exteriorRingPoints.last.latitude ||
          exteriorRingPoints.first.longitude != exteriorRingPoints.last.longitude) {
        exteriorRingPoints.add(exteriorRingPoints.first);
      }
      
      // Validate exterior ring
      if (!(options.validateShapePlacement?.call(exteriorRingPoints) ?? true)) {
        options.onPlacementInvalid?.call("Polygon exterior ring placement is invalid.");
        drawingState.setCurrentTool(DrawingTool.none);
        return;
      }

      List<List<LatLng>>? holeRingsPoints;
      if (parts.length > 1) {
        holeRingsPoints = parts.sublist(1).map((holePart) {
          List<LatLng> h = List.from(holePart);
          if (h.length < 3) return null; // Invalid hole part
          // Ensure hole is closed
          if (h.first.latitude != h.last.latitude || h.first.longitude != h.last.longitude) {
            h.add(h.first);
          }
          // Validate each hole ring
          if (!(options.validateShapePlacement?.call(h) ?? true)) {
            // If a hole is invalid, the entire polygon is invalid.
            // Set to null to indicate this hole caused the issue, or collect all invalid holes.
            return null; 
          }
          return h;
        }).toList();

        if (holeRingsPoints.any((h) => h == null)) {
             options.onPlacementInvalid?.call("One or more polygon hole placements are invalid.");
             drawingState.setCurrentTool(DrawingTool.none);
             return;
        }
        // Filter out any nulls that might have resulted from earlier checks, though the any() check should catch it.
        holeRingsPoints = holeRingsPoints.where((h) => h != null && h.length >=4).cast<List<LatLng>>().toList();
        if (holeRingsPoints.isEmpty) holeRingsPoints = null;
      }

      // Final check: exteriorRing must have at least 4 points (3 unique + close).
      if (exteriorRingPoints.length < 4) {
        options.onPlacementInvalid?.call("Polygon exterior ring requires at least 3 unique points.");
        drawingState.setCurrentTool(DrawingTool.none);
        return;
      }

      final newPolygon = Polygon(
        points: exteriorRingPoints,
        holePointsList: holeRingsPoints,
        color: options.drawingFillColor, // Use drawingFillColor
        borderColor: options.validDrawingColor,
        borderStrokeWidth: options.defaultBorderStrokeWidth, // Use option
        isFilled: true,
      );
      onShapeFinalized(PolygonShapeData(polygon: newPolygon));

    } else if (toolWas == DrawingTool.polyline) {
      List<ShapeData> newPolylines = [];
      bool allPolylinesValid = true;
      for (var partPoints in parts) {
        if (partPoints.length < 2) {
          options.onPlacementInvalid?.call("Polyline part requires at least 2 points.");
          allPolylinesValid = false;
          break; 
        }
        if (!(options.validateShapePlacement?.call(partPoints) ?? true)) {
          options.onPlacementInvalid?.call("Polyline part placement is invalid.");
          allPolylinesValid = false;
          break;
        }
        final newPolyline = Polyline(
          points: partPoints,
          color: options.validDrawingColor,
          strokeWidth: options.defaultStrokeWidth, // Use option
        );
        newPolylines.add(PolylineShapeData(polyline: newPolyline));
      }

      if (allPolylinesValid && newPolylines.isNotEmpty) {
        newPolylines.forEach(onShapeFinalized);
      } else if (!allPolylinesValid) {
        // Error message already sent by validation checks
      }
    }
    drawingState.setCurrentTool(DrawingTool.none); 
  }


  void _resetDrawingState() {
    drawingState.clearTemporaryShape();
    _draftShapeData = null;
    _startDragPoint = null;
    _isCurrentDraftInvalid = false; // Reset invalid flag
    if (_isDrawingCircleRadius) {
      _isDrawingCircleRadius = false;
      _setMapInteractive(true); 
    }
    // If map was disabled for rectangle/square drawing, ensure it's re-enabled
    if (drawingState.currentTool == DrawingTool.rectangle || 
        drawingState.currentTool == DrawingTool.square ||
        _isDrawingCircleRadius) { // Also cover if circle drawing was interrupted
        _setMapInteractive(true);
    }
  }

  void _setMapInteractive(bool interactive) {
    if (interactive) {
      mapController.options.flags |= MapInteractiveFlags.all;
    } else {
      // Important: Disable only drag and tap, allow zoom/rotate if needed.
      // Or disable all if that's the desired UX during these specific drawing operations.
      // For simplicity, disabling all for now.
      mapController.options.flags &= ~MapInteractiveFlags.all;
    }
  }

  void dispose() {
    // Clean up if necessary, e.g., if map interaction was disabled and not re-enabled
    if (_isDrawingCircleRadius || (drawingState.currentTool == DrawingTool.rectangle && _startDragPoint != null)) {
       _setMapInteractive(true);
    }
  }
}

// Extension for CircleShapeData to easily update color
extension _CircleShapeDataCopyWith on CircleShapeData {
  CircleShapeData copyWithColor(Color fillColor, Color borderColor) {
    return CircleShapeData(
      circleMarker: CircleMarker(
        point: circleMarker.point,
        radius: circleMarker.radius,
        useRadiusInMeter: circleMarker.useRadiusInMeter,
        color: fillColor, 
        borderColor: borderColor, 
        borderStrokeWidth: circleMarker.borderStrokeWidth, // Keep existing, or add param if needs change
        extraData: circleMarker.extraData,
      ),
      id: id, 
      // label: label, // Label not present in CircleShapeData, remove if it was a mistake
    );
  }
   CircleShapeData copyWithBorderWidth(double borderWidth) {
    return CircleShapeData(
      circleMarker: circleMarker.copyWith(borderStrokeWidth: borderWidth),
      id: id,
    );
  }
}

// Extension for PolygonShapeData to easily update color
extension _PolygonShapeDataCopyWith on PolygonShapeData {
  PolygonShapeData copyWithColor(Color fillColor, Color borderColor) {
    return PolygonShapeData(
      polygon: polygon.copyWith( 
        color: fillColor,
        borderColor: borderColor,
      ),
      id: id, 
      // label: label, // Label not present in PolygonShapeData, remove if it was a mistake
    );
  }
  PolygonShapeData copyWithBorderWidth(double borderWidth) {
    return PolygonShapeData(
      polygon: polygon.copyWith(borderStrokeWidth: borderWidth),
      id: id,
    );
  }
}

// Ensure Polygon itself has a copyWith, if not, it needs to be added or simulated
// For example, if Polygon.copyWith doesn't exist:
// extension _PolygonCopyWith on Polygon {
//   Polygon copyWith({ Color? color, Color? borderColor, List<LatLng>? points, List<List<LatLng>>? holePointsList, double? borderStrokeWidth, bool? isFilled, bool? isDotted }) {
//     return Polygon(
//       points: points ?? this.points,
//       holePointsList: holePointsList ?? this.holePointsList,
//       color: color ?? this.color,
//       borderColor: borderColor ?? this.borderColor,
//       borderStrokeWidth: borderStrokeWidth ?? this.borderStrokeWidth,
//       isFilled: isFilled ?? this.isFilled,
//       isDotted: isDotted ?? this.isDotted,
//       // copy other properties
//     );
//   }
// }
