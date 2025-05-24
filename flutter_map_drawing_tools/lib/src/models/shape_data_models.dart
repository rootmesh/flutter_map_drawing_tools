import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// import 'package:uuid/uuid.dart'; // Uuid is used in ShapeData base class
// import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart'; // Not directly used here

import 'drawing_state.dart' show ShapeData; // Import base class

/// {@template polygon_shape_data}
/// Represents a polygon shape, extending [ShapeData].
///
/// Contains a [Polygon] object from `flutter_map` and provides methods
/// for calculating its centroid and creating a copy.
/// {@endtemplate}
class PolygonShapeData extends ShapeData {
  /// {@macro polygon_shape_data}
  PolygonShapeData({String? id, required this.polygon, this.rotationAngle = 0.0}) : super(id: id);

  /// The `flutter_map` [Polygon] object representing this shape.
  final Polygon polygon;

  @override
  final double rotationAngle;

  @override
  LatLng get centroid {
    if (polygon.points.isEmpty) return const LatLng(0,0);
    if (polygon.points.length == 1) return polygon.points.first;
    
    // For a closed polygon, the last point is often a repeat of the first.
    // Exclude it from centroid calculation if so for a more accurate geometric center.
    List<LatLng> uniquePoints = polygon.points.length > 1 && 
                                polygon.points.first.latitude == polygon.points.last.latitude &&
                                polygon.points.first.longitude == polygon.points.last.longitude
                                ? polygon.points.sublist(0, polygon.points.length -1)
                                : polygon.points;
    
    if (uniquePoints.isEmpty) return polygon.points.isNotEmpty ? polygon.points.first : const LatLng(0,0);

    double latitude = 0, longitude = 0;
    for (var point in uniquePoints) {
      latitude += point.latitude;
      longitude += point.longitude;
    }
    return LatLng(latitude / uniquePoints.length, longitude / uniquePoints.length);
  }

  @override
  PolygonShapeData copy() {
    return PolygonShapeData(
      id: id,
      polygon: polygon.fullCopy(), // Use fullCopy extension
      rotationAngle: rotationAngle,
    );
  }

  @override
  PolygonShapeData copyWithRotation(double newRotationAngle) {
    return PolygonShapeData(
      id: id,
      polygon: polygon, // Original polygon geometry is preserved; rotation is an attribute
      rotationAngle: newRotationAngle,
    );
  }
  
  // Helper to create a new instance with a modified polygon (e.g., after points are rotated)
  PolygonShapeData copyWithUpdatedGeometry(Polygon newPolygon) {
    return PolygonShapeData(
      id: id,
      polygon: newPolygon,
      rotationAngle: rotationAngle, // Preserve existing rotation angle
    );
  }
}

extension _PolygonCopyWithHelper on Polygon {
  Polygon fullCopy() {
    return Polygon(
        points: List.from(points.map((p) => LatLng(p.latitude, p.longitude))),
        holePointsList: holePointsList?.map((hole) => List.from(hole.map((p) => LatLng(p.latitude, p.longitude)))).toList(),
        color: color,
        borderStrokeWidth: borderStrokeWidth,
        borderColor: borderColor,
        isFilled: isFilled,
        strokeCap: strokeCap,
        strokeJoin: strokeJoin,
        label: label,
        labelStyle: labelStyle,
        rotateLabel: rotateLabel,
        disableHolesBorder: disableHolesBorder,
        isDotted: isDotted,
        updateParentBeliefs: updateParentBeliefs,
      );
  }
}

/// {@template multi_polyline_shape_data}
/// Represents a multi-polyline shape, extending [ShapeData].
///
/// Contains a list of [Polyline] objects from `flutter_map`.
/// {@endtemplate}
class MultiPolylineShapeData extends ShapeData {
  /// {@macro multi_polyline_shape_data}
  MultiPolylineShapeData({String? id, required this.polylines, this.rotationAngle = 0.0}) : super(id: id);

  /// The list of `flutter_map` [Polyline] objects representing this shape.
  /// These polylines' points are relative to the overall MultiPolylineShapeData's centroid for rotation.
  final List<Polyline> polylines;

  @override
  final double rotationAngle;

  @override
  LatLng get centroid {
    if (polylines.isEmpty || polylines.every((p) => p.points.isEmpty)) {
      return const LatLng(0, 0);
    }

    double totalLatitude = 0;
    double totalLongitude = 0;
    int totalPoints = 0;

    for (var polyline in polylines) {
      if (polyline.points.isNotEmpty) {
        for (var point in polyline.points) {
          totalLatitude += point.latitude;
          totalLongitude += point.longitude;
        }
        totalPoints += polyline.points.length;
      }
    }

    if (totalPoints == 0) return const LatLng(0, 0);
    return LatLng(totalLatitude / totalPoints, totalLongitude / totalPoints);
  }

  @override
  MultiPolylineShapeData copy() {
    return MultiPolylineShapeData(
      id: id,
      polylines: polylines.map((polyline) => polyline.fullCopy()).toList(), // Use fullCopy
      rotationAngle: rotationAngle,
    );
  }

  @override
  MultiPolylineShapeData copyWithRotation(double newRotationAngle) {
    return MultiPolylineShapeData(
      id: id,
      polylines: polylines, // Original polylines are preserved; points are relative to group centroid for rotation
      rotationAngle: newRotationAngle,
    );
  }

  // Helper to create a new instance with a modified list of polylines (e.g., after points are rotated)
  MultiPolylineShapeData copyWithUpdatedGeometry(List<Polyline> newPolylines) {
    return MultiPolylineShapeData(
      id: id,
      polylines: newPolylines,
      rotationAngle: rotationAngle, // Preserve existing rotation angle
    );
  }
}

/// {@template multi_polygon_shape_data}
/// Represents a multi-polygon shape, extending [ShapeData].
///
/// Contains a list of [Polygon] objects from `flutter_map`.
/// {@endtemplate}
class MultiPolygonShapeData extends ShapeData {
  /// {@macro multi_polygon_shape_data}
  MultiPolygonShapeData({String? id, required this.polygons, this.rotationAngle = 0.0}) : super(id: id);

  /// The list of `flutter_map` [Polygon] objects representing this shape.
  /// These polygons' points are relative to the overall MultiPolygonShapeData's centroid for rotation.
  final List<Polygon> polygons;

  @override
  final double rotationAngle;

  @override
  LatLng get centroid {
    if (polygons.isEmpty || polygons.every((p) => p.points.isEmpty)) {
      return const LatLng(0, 0);
    }

    double totalLatitude = 0;
    double totalLongitude = 0;
    int totalCentroidPoints = 0; // Count of polygons contributing to centroid

    for (var polygon in polygons) {
      if (polygon.points.isNotEmpty) {
        // Calculate centroid for this individual polygon
        List<LatLng> uniquePoints = polygon.points.length > 1 &&
                                    polygon.points.first.latitude == polygon.points.last.latitude &&
                                    polygon.points.first.longitude == polygon.points.last.longitude
                                    ? polygon.points.sublist(0, polygon.points.length - 1)
                                    : polygon.points;
        
        if (uniquePoints.isNotEmpty) {
          double polyLatitude = 0, polyLongitude = 0;
          for (var point in uniquePoints) {
            polyLatitude += point.latitude;
            polyLongitude += point.longitude;
          }
          totalLatitude += polyLatitude / uniquePoints.length;
          totalLongitude += polyLongitude / uniquePoints.length;
          totalCentroidPoints++;
        }
      }
    }

    if (totalCentroidPoints == 0) return const LatLng(0,0);
    return LatLng(totalLatitude / totalCentroidPoints, totalLongitude / totalCentroidPoints);
  }

  @override
  MultiPolygonShapeData copy() {
    return MultiPolygonShapeData(
      id: id,
      polygons: polygons.map((polygon) => polygon.fullCopy()).toList(), // Use fullCopy
      rotationAngle: rotationAngle,
    );
  }

  @override
  MultiPolygonShapeData copyWithRotation(double newRotationAngle) {
    return MultiPolygonShapeData(
      id: id,
      polygons: polygons, // Original polygons are preserved; points are relative to group centroid
      rotationAngle: newRotationAngle,
    );
  }

  // Helper to create a new instance with a modified list of polygons (e.g., after points are rotated)
  MultiPolygonShapeData copyWithUpdatedGeometry(List<Polygon> newPolygons) {
    return MultiPolygonShapeData(
      id: id,
      polygons: newPolygons,
      rotationAngle: rotationAngle, // Preserve existing rotation angle
    );
  }
}

/// {@template polyline_shape_data}
/// Represents a polyline (LineString) shape, extending [ShapeData].
///
/// Contains a [Polyline] object from `flutter_map` and provides methods
/// for calculating its centroid (average of points) and creating a copy.
/// {@endtemplate}
class PolylineShapeData extends ShapeData {
  /// {@macro polyline_shape_data}
  PolylineShapeData({String? id, required this.polyline, this.rotationAngle = 0.0}) : super(id: id);

  /// The `flutter_map` [Polyline] object representing this shape.
  final Polyline polyline;

  @override
  final double rotationAngle;
  
  @override
  LatLng get centroid {
    if (polyline.points.isEmpty) return const LatLng(0,0);
    if (polyline.points.length == 1) return polyline.points.first;

    double latitude = 0, longitude = 0;
    for (var point in polyline.points) {
      latitude += point.latitude;
      longitude += point.longitude;
    }
    return LatLng(latitude / polyline.points.length, longitude / polyline.points.length);
  }

  @override
  PolylineShapeData copy() {
    return PolylineShapeData(
      id: id,
      polyline: polyline.fullCopy(), // Use fullCopy extension
      rotationAngle: rotationAngle,
    );
  }

  @override
  PolylineShapeData copyWithRotation(double newRotationAngle) {
    return PolylineShapeData(
      id: id,
      polyline: polyline, // Original polyline geometry is preserved
      rotationAngle: newRotationAngle,
    );
  }

  // Helper to create a new instance with a modified polyline
  PolylineShapeData copyWithUpdatedGeometry(Polyline newPolyline) {
    return PolylineShapeData(
      id: id,
      polyline: newPolyline,
      rotationAngle: rotationAngle, // Preserve existing rotation angle
    );
  }
}

extension _PolylineCopyWithHelper on Polyline {
  Polyline fullCopy() {
    return Polyline(
        points: List.from(points.map((p) => LatLng(p.latitude, p.longitude))),
        color: color,
        strokeWidth: strokeWidth,
        borderColor: borderColor,
        borderStrokeWidth: borderStrokeWidth,
        gradientColors: gradientColors != null ? List.from(gradientColors!) : null,
        isDotted: isDotted,
        colorsStop: colorsStop != null ? List.from(colorsStop!) : null,
        strokeCap: strokeCap,
        strokeJoin: strokeJoin,
        useStrokeWidthInMeter: useStrokeWidthInMeter,
      );
  }
}

/// {@template circle_shape_data}
/// Represents a circle shape, extending [ShapeData].
///
/// Contains a [CircleMarker] object from `flutter_map`. The centroid is the circle's center point.
/// {@endtemplate}
class CircleShapeData extends ShapeData {
  /// {@macro circle_shape_data}
  CircleShapeData({String? id, required this.circle, this.rotationAngle = 0.0}) : super(id: id);
  // Note: rotationAngle for a circle around its center doesn't change its appearance.
  // It's included for consistency if ShapeData requires it, or if part of a group.

  /// The `flutter_map` [CircleMarker] object representing this shape.
  final CircleMarker circle;

  @override
  final double rotationAngle;

  @override
  LatLng get centroid => circle.point;

  @override
  CircleShapeData copy() {
    return CircleShapeData(
      id: id,
      circle: circle.fullCopy(), // Use fullCopy extension
      rotationAngle: rotationAngle,
    );
  }

  @override
  CircleShapeData copyWithRotation(double newRotationAngle) {
    // Rotation of a circle around its own center doesn't change its geometry.
    return CircleShapeData(
      id: id,
      circle: circle, // Circle marker itself is not changed by this conceptual rotation
      rotationAngle: newRotationAngle,
    );
  }

  // Helper to create a new instance with a modified circle marker (e.g. new center or radius)
  CircleShapeData copyWithUpdatedGeometry(CircleMarker newCircleMarker) {
    return CircleShapeData(
      id: id,
      circle: newCircleMarker,
      rotationAngle: rotationAngle, // Preserve conceptual angle unless newCircleMarker implies change
    );
  }
}

extension _CircleMarkerCopyWithHelper on CircleMarker {
  CircleMarker fullCopy() {
    return CircleMarker(
        point: LatLng(point.latitude, point.longitude),
        radius: radius,
        useRadiusInMeter: useRadiusInMeter,
        color: color,
        borderColor: borderColor,
        borderStrokeWidth: borderStrokeWidth,
        extraData: extraData, 
      );
  }
}

/// {@template marker_shape_data}
/// Represents a point marker shape, extending [ShapeData].
///
/// Contains a [Marker] object from `flutter_map`. The centroid is the marker's point.
/// {@endtemplate}
class MarkerShapeData extends ShapeData {
  /// {@macro marker_shape_data}
  MarkerShapeData({String? id, required this.marker, this.rotationAngle = 0.0}) : super(id: id);

  /// The `flutter_map` [Marker] object representing this shape.
  final Marker marker;

  @override
  final double rotationAngle;

  @override
  LatLng get centroid => marker.point;

  @override
  MarkerShapeData copy() {
    return MarkerShapeData(
      id: id,
      marker: marker.fullCopy(), // Use fullCopy extension
      rotationAngle: rotationAngle, 
    );
  }

  @override
  MarkerShapeData copyWithRotation(double newRotationAngle) {
    // The Marker's 'rotate' property is a boolean for alignment.
    // True rotation happens via Transform.rotate around the marker's anchor.
    // This `rotationAngle` is conceptual for the ShapeData.
    // The renderer would need to use this angle when wrapping the Marker widget.
    return MarkerShapeData(
      id: id,
      marker: marker, 
      rotationAngle: newRotationAngle,
    );
  }

  // Helper to create a new instance with a modified marker (e.g., new point)
  // The actual rotation of the Marker widget would be handled by the renderer using this.rotationAngle.
  MarkerShapeData copyWithUpdatedGeometry(Marker newMarker) {
    return MarkerShapeData(
      id: id,
      marker: newMarker,
      rotationAngle: rotationAngle,
    );
  }
}

extension _MarkerCopyWithHelper on Marker {
  Marker fullCopy() {
    return Marker(
        point: LatLng(point.latitude, point.longitude),
        width: width,
        height: height,
        alignment: alignment,
        child: child, // Child widget is shallow copied
        rotate: rotate,
        // anchor: anchor, // Not copying anchor as it's complex and often default
      );
  }
}
