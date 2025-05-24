import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map/plugin_api.dart'; // For MapTransformer
import 'dart:math' as math;

// Threshold for tapping near a polyline or marker (in screen pixels)
const double _kPolylineHitThreshold = 15.0; // TODO: Make this configurable via DrawingToolsOptions
const double _kMarkerHitThreshold = 20.0;   // TODO: Make this configurable via DrawingToolsOptions

class ShapeSelectionManager {
  final DrawingState drawingState;
  final DrawingToolsOptions options;

  ShapeSelectionManager({
    required this.drawingState,
    required this.options,
  });

  /// Handles tap events on the map to select or deselect shapes.
  ///
  /// [tapPosition] is the geographical coordinate of the tap.
  /// [mapTransformer] is used to convert geographical coordinates to screen coordinates for hit-testing.
  /// Returns `true` if a shape was selected or deselected, `false` otherwise.
  bool handleTap(LatLng tapPosition, MapTransformer mapTransformer) {
    // Allow selection if no tool is active, or if edit/delete tool is active.
    // Do not allow selection if a shape is currently being drawn (e.g. multi-part polygon).
    if (drawingState.isMultiPartDrawingInProgress) {
      return false;
    }
    
    // Iterate shapes in reverse order so topmost rendered shapes are checked first
    for (var shape in drawingState.currentShapes.reversed) {
      bool hit = false;
      if (shape is PolygonShapeData) {
        hit = _isTapOnPolygon(tapPosition, shape);
      } else if (shape is PolylineShapeData) {
        hit = _isTapOnPolyline(tapPosition, shape, mapTransformer);
      } else if (shape is CircleShapeData) {
        hit = _isTapOnCircle(tapPosition, shape);
      } else if (shape is MarkerShapeData) {
        hit = _isTapOnMarker(tapPosition, shape, mapTransformer);
      }

      if (hit) {
        if (drawingState.selectedShapeId == shape.id) {
          // If the tapped shape is already selected, deselect it (or cycle edit modes - future enhancement)
          // For now, tapping an already selected shape does nothing, selection is sticky until another shape is tapped
          // or drawingState.deselectShape() is called externally (e.g. by pressing an escape key or a deselect button)
          // To enable deselection by tapping again:
          // drawingState.deselectShape();
          // return true;
        } else {
          drawingState.selectShape(shape.id, shape.copy()); // Pass a copy for original data before drag
        }
        return true; // Stop after the first hit
      }
    }

    // If no shape was hit, and a shape is currently selected, deselect it.
    if (drawingState.selectedShapeId != null) {
      drawingState.deselectShape();
      return true; // A deselection occurred
    }

    return false; // No shape was selected or deselected
  }

  bool _isTapOnPolygon(LatLng tap, PolygonShapeData polygonData) {
    // Point-in-polygon test for the exterior ring
    if (!_isPointInRing(tap, polygonData.polygon.points)) {
      return false; // Not in the exterior ring
    }

    // If it's in the exterior ring, check if it's inside any of the hole rings
    if (polygonData.polygon.holePointsList != null) {
      for (var holeRing in polygonData.polygon.holePointsList!) {
        if (_isPointInRing(tap, holeRing)) {
          return false; // Point is inside a hole
        }
      }
    }
    return true; // Point is in the exterior ring and not in any hole
  }

  /// Ray casting algorithm to determine if a point is inside a ring (polygon or hole).
  bool _isPointInRing(LatLng p, List<LatLng> ring) {
    if (ring.length < 3) return false; // Not a valid ring

    bool isInside = false;
    LatLng p1 = ring[0];
    for (int i = 1; i <= ring.length; i++) {
      LatLng p2 = ring[i % ring.length]; // Handle wrapping for the last segment

      // Check if point is colinear and on segment (edge case)
      if (p.latitude == p1.latitude && p.latitude == p2.latitude) { // Horizontal segment
          if (p.longitude >= math.min(p1.longitude, p2.longitude) && p.longitude <= math.max(p1.longitude, p2.longitude)) {
              return true; // On horizontal segment
          }
      }
      if (p.longitude == p1.longitude && p.longitude == p2.longitude) { // Vertical segment
          if (p.latitude >= math.min(p1.latitude, p2.latitude) && p.latitude <= math.max(p1.latitude, p2.latitude)) {
              return true; // On vertical segment
          }
      }


      if (((p2.latitude <= p.latitude && p.latitude < p1.latitude) ||
           (p1.latitude <= p.latitude && p.latitude < p2.latitude)) &&
          (p.longitude < (p1.longitude - p2.longitude) * (p.latitude - p2.latitude) / (p1.latitude - p2.latitude) + p2.longitude)) {
        isInside = !isInside;
      }
      p1 = p2;
    }
    return isInside;
  }

  bool _isTapOnPolyline(LatLng tap, PolylineShapeData polylineData, MapTransformer mapTransformer) {
    final points = polylineData.polyline.points;
    if (points.length < 2) return false;

    // Convert geographical points to screen points
    List<CustomPoint<double>> screenPoints = points.map((p) => mapTransformer.latLngToPixel(p, mapTransformer.centerZoom.zoom)).toList();
    CustomPoint<double> tapScreenPoint = mapTransformer.latLngToPixel(tap, mapTransformer.centerZoom.zoom);

    for (int i = 0; i < screenPoints.length - 1; i++) {
      CustomPoint<double> p1 = screenPoints[i];
      CustomPoint<double> p2 = screenPoints[i+1];

      // Calculate distance from tap point to the line segment (p1, p2)
      double distance = _distanceToSegment(tapScreenPoint, p1, p2);
      
      // Use a threshold based on polyline stroke width, defaulting to _kPolylineHitThreshold
      double hitThreshold = (polylineData.polyline.strokeWidth / 2) + _kPolylineHitThreshold;

      if (distance <= hitThreshold) {
        return true;
      }
    }
    return false;
  }

  /// Calculates the minimum distance from a point `p` to a line segment defined by `v` and `w`.
  double _distanceToSegment(CustomPoint<double> p, CustomPoint<double> v, CustomPoint<double> w) {
    double l2 = _distSq(v, w); // Square of the segment length
    if (l2 == 0) return _distSq(p, v).sqrt(); // v == w, distance to point v

    // Project p onto the line defined by v and w
    // t = [(p - v) . (w - v)] / |w - v|^2
    double t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2;
    t = math.max(0, math.min(1, t)); // Clamp t to the range [0, 1] to stay on the segment

    // Projection falls on the segment
    CustomPoint<double> projection = CustomPoint(
      v.x + t * (w.x - v.x),
      v.y + t * (w.y - v.y),
    );
    return _distSq(p, projection).sqrt();
  }

  /// Calculates the square of the distance between two points.
  double _distSq(CustomPoint<double> p1, CustomPoint<double> p2) {
    return math.pow(p1.x - p2.x, 2) + math.pow(p1.y - p2.y, 2).toDouble();
  }


  bool _isTapOnCircle(LatLng tap, CircleShapeData circleData) {
    final center = circleData.circleMarker.point;
    final radius = circleData.circleMarker.radius; // Assuming radius is in meters if useRadiusInMeter is true

    if (!circleData.circleMarker.useRadiusInMeter) {
      // If radius is in pixels, this hit-testing logic is more complex as pixel radius changes with zoom.
      // For simplicity, this example assumes useRadiusInMeter = true for accurate geo-distance check.
      // A robust solution for pixel-based radius would involve converting tap and center to screen points
      // and checking distance against pixel radius.
      // Consider logging a warning or throwing an error if not in meters for now.
      debugPrint("Warning: Circle hit-testing is most accurate with useRadiusInMeter=true.");
      // Fallback: attempt a rough screen-space check (less accurate)
      // This would require mapTransformer passed in.
      return false; // Or implement screen-space check
    }

    final distance = const Distance().as(LengthUnit.Meter, tap, center);
    return distance <= radius;
  }

  bool _isTapOnMarker(LatLng tap, MarkerShapeData markerData, MapTransformer mapTransformer) {
    // Convert marker position and tap position to screen coordinates
    final markerPoint = mapTransformer.latLngToPixel(markerData.marker.point, mapTransformer.centerZoom.zoom);
    final tapPoint = mapTransformer.latLngToPixel(tap, mapTransformer.centerZoom.zoom);

    // Get marker size and alignment
    double width = markerData.marker.width;
    double height = markerData.marker.height;
    Alignment alignment = markerData.marker.alignment ?? Alignment.center;

    // Calculate marker bounds on screen
    // Alignment gives the anchor point within the marker's bounding box.
    // (0,0) in alignment is center, (-1,-1) is top-left, (1,1) is bottom-right.
    double anchorX = width * (alignment.x + 1) / 2;
    double anchorY = height * (alignment.y + 1) / 2;
    
    double left = markerPoint.x - anchorX;
    double top = markerPoint.y - anchorY;
    double right = left + width;
    double bottom = top + height;

    // Check if tap is within the marker's bounding box, with an added threshold
    return (tapPoint.x >= left - _kMarkerHitThreshold &&
            tapPoint.x <= right + _kMarkerHitThreshold &&
            tapPoint.y >= top - _kMarkerHitThreshold &&
            tapPoint.y <= bottom + _kMarkerHitThreshold);
  }

  void dispose() {
    // No resources to dispose in this manager currently.
  }
}
