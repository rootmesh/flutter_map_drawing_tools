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
  PolygonShapeData({String? id, required this.polygon}) : super(id: id);

  /// The `flutter_map` [Polygon] object representing this shape.
  final Polygon polygon;

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
      polygon: Polygon( // Manually copy all relevant Polygon properties
        points: List.from(polygon.points.map((p) => LatLng(p.latitude, p.longitude))),
        holePointsList: polygon.holePointsList?.map((hole) => List.from(hole.map((p) => LatLng(p.latitude, p.longitude)))).toList(),
        color: polygon.color,
        borderStrokeWidth: polygon.borderStrokeWidth,
        borderColor: polygon.borderColor,
        isFilled: polygon.isFilled,
        strokeCap: polygon.strokeCap,
        strokeJoin: polygon.strokeJoin,
        label: polygon.label,
        labelStyle: polygon.labelStyle,
        rotateLabel: polygon.rotateLabel,
        disableHolesBorder: polygon.disableHolesBorder,
        isDotted: polygon.isDotted,
        updateParentBeliefs: polygon.updateParentBeliefs,
      )
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
  PolylineShapeData({String? id, required this.polyline}) : super(id: id);

  /// The `flutter_map` [Polyline] object representing this shape.
  final Polyline polyline;
  
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
      polyline: Polyline( // Manually copy all relevant Polyline properties
        points: List.from(polyline.points.map((p) => LatLng(p.latitude, p.longitude))),
        color: polyline.color,
        strokeWidth: polyline.strokeWidth,
        borderColor: polyline.borderColor,
        borderStrokeWidth: polyline.borderStrokeWidth,
        gradientColors: polyline.gradientColors != null ? List.from(polyline.gradientColors!) : null,
        isDotted: polyline.isDotted,
        colorsStop: polyline.colorsStop != null ? List.from(polyline.colorsStop!) : null,
        strokeCap: polyline.strokeCap,
        strokeJoin: polyline.strokeJoin,
        useStrokeWidthInMeter: polyline.useStrokeWidthInMeter,
      )
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
  CircleShapeData({String? id, required this.circle}) : super(id: id);

  /// The `flutter_map` [CircleMarker] object representing this shape.
  final CircleMarker circle;

  @override
  LatLng get centroid => circle.point;

  @override
  CircleShapeData copy() {
    return CircleShapeData(
      id: id,
      circle: CircleMarker( // Manually copy all relevant CircleMarker properties
        point: LatLng(circle.point.latitude, circle.point.longitude),
        radius: circle.radius,
        useRadiusInMeter: circle.useRadiusInMeter,
        color: circle.color,
        borderColor: circle.borderColor,
        borderStrokeWidth: circle.borderStrokeWidth,
        extraData: circle.extraData, 
      )
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
  MarkerShapeData({String? id, required this.marker}) : super(id: id);

  /// The `flutter_map` [Marker] object representing this shape.
  final Marker marker;

  @override
  LatLng get centroid => marker.point;

  @override
  MarkerShapeData copy() {
    return MarkerShapeData(
      id: id,
      marker: Marker( // Manually copy all relevant Marker properties
        point: LatLng(marker.point.latitude, marker.point.longitude),
        width: marker.width,
        height: marker.height,
        alignment: marker.alignment,
        child: marker.child, // Child widget is shallow copied
        rotate: marker.rotate,
        // anchor: marker.anchor, // Anchor is complex, handle if mutable and deep copy needed
      )
    );
  }
}
