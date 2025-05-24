import 'dart:convert'; 
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart'; 
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';

/// {@template operation_success_callback}
/// Callback type for successful operations, providing a [message].
/// {@endtemplate}
typedef OperationSuccessCallback = void Function(String message);

/// {@template operation_error_callback}
/// Callback type for failed operations, providing an error [message].
/// {@endtemplate}
typedef OperationErrorCallback = void Function(String message);

/// {@template on_geojson_imported_callback}
/// Callback type for when GeoJSON import is completed, providing a list of [importedShapes].
///
/// Consider using [OperationSuccessCallback] or [OperationErrorCallback] for more general feedback.
/// {@endtemplate}
@Deprecated('Consider using onSuccess/onError for more general feedback.')
typedef OnGeoJsonImportedCallback = void Function(List<ShapeData> importedShapes);

/// {@template drawing_tools_controller}
/// Manages high-level drawing operations and state for the drawing tools plugin.
///
/// This controller interacts with [DrawingState] to manage shapes and provides
/// functionalities like importing and exporting GeoJSON data. It also offers
/// loading state indicators and success/error callbacks for these operations.
/// {@endtemplate}
class DrawingToolsController extends ChangeNotifier {
  /// {@macro drawing_tools_controller}
  DrawingToolsController({
    required this.drawingState,
    @Deprecated('Consider using onSuccess/onError for more general feedback.') this.onGeoJsonImported,
    this.onSuccess,
    this.onError,
  });

  /// The core state manager for drawing operations.
  final DrawingState drawingState;
  
  /// {@macro on_geojson_imported_callback}
  @Deprecated('Consider using onSuccess/onError for more general feedback.')
  final OnGeoJsonImportedCallback? onGeoJsonImported; 
  
  /// {@macro operation_success_callback}
  /// Called when an operation like GeoJSON import or export completes successfully.
  final OperationSuccessCallback? onSuccess;

  /// {@macro operation_error_callback}
  /// Called when an operation like GeoJSON import or export fails.
  final OperationErrorCallback? onError;

  bool _isImporting = false;
  /// Indicates whether a GeoJSON import operation is currently in progress.
  /// Can be used to show loading indicators in the UI.
  bool get isImporting => _isImporting;

  bool _isExporting = false;
  /// Indicates whether a GeoJSON export operation is currently in progress.
  /// Can be used to show loading indicators in the UI.
  bool get isExporting => _isExporting;

  /// Imports shapes from a GeoJSON string.
  ///
  /// Parses the GeoJSON and adds the resulting shapes to the [DrawingState].
  /// Supported GeoJSON Geometry types:
  /// - Point (becomes [MarkerShapeData] or [CircleShapeData] if 'radius' property exists)
  /// - LineString (becomes [PolylineShapeData])
  /// - Polygon (becomes [PolygonShapeData])
  /// - MultiPolygon (each polygon within becomes a separate [PolygonShapeData])
  /// - MultiLineString (each lineString within becomes a separate [PolylineShapeData])
  ///
  /// For Points to be parsed as Circles, they must have a "radius" or "radius_meters"
  /// property in their GeoJSON `properties`. Otherwise, they become Markers.
  ///
  /// Notifies listeners before starting and after completing the operation
  /// to update [isImporting] state. Calls [onSuccess] or [onError] callbacks.
  ///
  /// Returns `true` if the import process initiated and completed (even if no shapes were found),
  /// `false` if an error occurred during parsing or processing.
  Future<bool> importGeoJson(String geoJsonString) async {
    if (_isImporting) return false; 
    
    _isImporting = true;
    notifyListeners();
    bool success = false;
    
    final List<ShapeData> importedShapes = [];
    final parser = GeoJsonParser(
      defaultMarkerColor: Colors.red, 
      defaultPolygonBorderColor: Colors.blue,
      defaultPolygonFillColor: Colors.blue.withOpacity(0.3),
      defaultPolylineColor: Colors.red,
      circleMarkerParser: (json) {
        final properties = json['properties'] as Map<String, dynamic>?;
        double? radius;
        if (properties != null) {
          if (properties.containsKey('radius_meters')) {
            radius = properties['radius_meters']?.toDouble();
          } else if (properties.containsKey('radius')) {
            radius = properties['radius']?.toDouble();
          }
        }
        if (radius != null) {
          final coordinates = json['geometry']['coordinates'] as List<dynamic>;
          return CircleMarker(
            point: LatLng(coordinates[1] as double, coordinates[0] as double),
            radius: radius, useRadiusInMeter: true,
            color: Colors.cyan.withOpacity(0.3), 
            borderColor: Colors.cyan, borderStrokeWidth: 2,
          );
        }
        return null; 
      },
    );

    try {
      await parser.parseGeoJsonAsString(geoJsonString);

      for (var marker in parser.markers) {
        if (marker is CircleMarker) {
          importedShapes.add(CircleShapeData(circle: marker));
        } else {
          Widget markerWidget = marker.child ?? const Icon(Icons.location_on, color: Colors.red, size: 30);
          importedShapes.add(MarkerShapeData(
            marker: Marker(
              point: marker.point, width: marker.width, height: marker.height,
              alignment: marker.alignment, child: markerWidget, rotate: marker.rotate,
            )
          ));
        }
      }
      for (var polyline in parser.polylines) { importedShapes.add(PolylineShapeData(polyline: polyline)); }
      for (var polygon in parser.polygons) { importedShapes.add(PolygonShapeData(polygon: polygon)); }
      for (var multiPolygon in parser.multiPolygons) {
        for (var polygon in multiPolygon.polygons) { importedShapes.add(PolygonShapeData(polygon: polygon)); }
      }
      for (var multiLine in parser.multiLines) {
          for (var line in multiLine.lines) { importedShapes.add(PolylineShapeData(polyline: line)); }
      }

      if (importedShapes.isNotEmpty) {
        drawingState.addShapes(importedShapes);
        // ignore: deprecated_member_use_from_same_package
        onGeoJsonImported?.call(importedShapes); 
        onSuccess?.call("GeoJSON imported successfully. ${importedShapes.length} shapes added.");
        success = true;
      } else {
        onSuccess?.call("GeoJSON imported, but no compatible shapes were found.");
        success = true; 
      }
    } catch (e) {
      debugPrint("Error importing GeoJSON: $e");
      onError?.call("Error importing GeoJSON: ${e.toString()}");
      success = false;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
    return success;
  }

  /// Exports the current shapes managed by [DrawingState] to a GeoJSON string.
  ///
  /// Converts all `ShapeData` instances ([PolygonShapeData], [PolylineShapeData],
  /// [CircleShapeData], [MarkerShapeData]) into their corresponding GeoJSON Feature representations.
  /// - Polygons include exterior and interior (hole) rings.
  /// - Circles are represented as Points with "radius" and "radius_units" properties.
  /// - All features include their `id` from `ShapeData`.
  ///
  /// Notifies listeners before starting and after completing the operation
  /// to update [isExporting] state. Calls [onSuccess] or [onError] callbacks.
  ///
  /// Returns the GeoJSON string if successful, or `null` if an error occurs.
  String? exportGeoJson() {
    if (_isExporting) return null; 

    _isExporting = true;
    notifyListeners();
    String? geoJsonString;

    try {
      final List<Map<String, dynamic>> features = [];
      for (final shapeData in drawingState.currentShapes) {
        Map<String, dynamic>? geometry;
        Map<String, dynamic> properties = {'id': shapeData.id};

        if (shapeData is PolygonShapeData) {
          final points = shapeData.polygon.points;
          if (points.isNotEmpty) {
            final coordinates = points.map((p) => [p.longitude, p.latitude]).toList();
            List<List<List<double>>> allRings = [coordinates];
            if (shapeData.polygon.holePointsList != null) {
              for (var hole in shapeData.polygon.holePointsList!) {
                allRings.add(hole.map((p) => [p.longitude, p.latitude]).toList());
              }
            }
            geometry = {'type': 'Polygon', 'coordinates': allRings};
          }
        } else if (shapeData is PolylineShapeData) {
          final points = shapeData.polyline.points;
          if (points.length >= 2) {
            final coordinates = points.map((p) => [p.longitude, p.latitude]).toList();
            geometry = {'type': 'LineString', 'coordinates': coordinates};
          }
        } else if (shapeData is CircleShapeData) {
          final point = shapeData.circle.point;
          geometry = {'type': 'Point', 'coordinates': [point.longitude, point.latitude]};
          properties['radius'] = shapeData.circle.radius;
          properties['radius_units'] = 'm'; 
        } else if (shapeData is MarkerShapeData) {
          final point = shapeData.marker.point;
          geometry = {'type': 'Point', 'coordinates': [point.longitude, point.latitude]};
        }

        if (geometry != null) {
          features.add({
            'type': 'Feature', 'id': shapeData.id,
            'geometry': geometry, 'properties': properties,
          });
        }
      }
      final featureCollection = {'type': 'FeatureCollection', 'features': features};
      geoJsonString = jsonEncode(featureCollection);
      onSuccess?.call("GeoJSON exported successfully.");
    } catch (e) {
      debugPrint("Error exporting GeoJSON: $e");
      onError?.call("Error exporting GeoJSON: ${e.toString()}");
      geoJsonString = null; 
    } finally {
      _isExporting = false;
      notifyListeners();
    }
    return geoJsonString;
  }
}
