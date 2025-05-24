import 'package:flutter/material.dart'; 
import 'package:latlong2/latlong.dart';
import 'drawing_state.dart' show ShapeData; 

/// {@template validate_shape_placement_callback}
/// A callback to validate if a shape (represented by a list of [LatLng] points)
/// can be placed or drawn at its current location/geometry.
///
/// Used by [DrawingToolsOptions.validateShapePlacement].
///
/// - `points`: A list of [LatLng] coordinates representing the shape's geometry.
///   For points and circles, this list will typically contain a single [LatLng] (the center).
///   For polylines and polygons, it will contain all vertices.
///
/// Returns `true` if placement is valid, `false` otherwise.
/// {@endtemplate}
typedef ValidateShapePlacementCallback = bool Function(List<LatLng> points);

/// {@template on_placement_invalid_callback}
/// A callback triggered when a shape placement or drawing action is deemed invalid
/// by the [ValidateShapePlacementCallback].
///
/// Provides a [message] explaining the reason for invalid placement, which can
/// be displayed to the user.
/// {@endtemplate}
typedef OnPlacementInvalidCallback = void Function(String message);

/// {@template point_icon_builder}
/// A callback function that builds a widget for representing a point marker.
///
/// Used by [DrawingToolsOptions.pointIconBuilder].
///
/// - `shapeData`: Optional [ShapeData] associated with the point. This can be `null`
///   when getting a generic icon for a new point being drawn. If provided, it's typically
///   a [MarkerShapeData] instance allowing access to the marker's properties.
/// - `isSelected`: A boolean indicating if the point is currently selected.
///
/// Returns a widget to display as the marker.
/// {@endtemplate}
typedef PointIconBuilder = Widget Function(ShapeData? shapeData, bool isSelected);

/// {@template simple_icon_builder}
/// A callback function that builds a simple icon widget, typically for UI elements
/// like PolyEditor handles.
///
/// Used by [DrawingToolsOptions.intermediateIconBuilder] and [DrawingToolsOptions.vertexIconBuilder].
///
/// Returns a widget to display as the icon.
/// {@endtemplate}
typedef SimpleIconBuilder = Widget Function();

/// {@template drawing_tools_options}
/// Configures the appearance and behavior of the drawing tools.
///
/// Passed to the [DrawingLayer] to customize various aspects of the drawing
/// and editing experience, including colors, icon appearances, and validation logic.
/// {@endtemplate}
class DrawingToolsOptions {
  /// {@macro drawing_tools_options}
  const DrawingToolsOptions({
    this.validateShapePlacement,
    this.validDrawingColor = Colors.blue,
    this.invalidDrawingColor = Colors.red,   
    this.temporaryLineColor = Colors.grey, 
    Color? drawingFillColor, 
    this.selectionHighlightColor = Colors.yellowAccent,
    this.editingHandleColor = Colors.orangeAccent,
    this.pointIconBuilder,
    this.intermediateIconBuilder,
    this.vertexIconBuilder,
    this.onPlacementInvalid, 
  }) : drawingFillColor = drawingFillColor ?? validDrawingColor.withOpacity(0.3);

  /// {@macro validate_shape_placement_callback}
  ///
  /// If `null`, all placements are considered valid by default.
  final ValidateShapePlacementCallback? validateShapePlacement;

  /// {@macro on_placement_invalid_callback}
  ///
  /// If `null`, no specific action is taken when placement is invalid, beyond
  /// visual indication and preventing finalization.
  final OnPlacementInvalidCallback? onPlacementInvalid;
  
  // Colors
  /// Base color for validly drawn shapes and temporary visuals indicating valid placement.
  /// Defaults to [Colors.blue].
  final Color validDrawingColor;        
  
  /// Color used for temporary visuals to indicate an invalid placement or geometry.
  /// Defaults to [Colors.red].
  final Color invalidDrawingColor;      
  
  /// Color for temporary lines shown during shape creation (e.g., active multi-part segment).
  /// Defaults to [Colors.grey].
  final Color temporaryLineColor;       
  
  /// Fill color for temporary shapes being drawn (e.g., rectangles, circles during drag).
  /// Defaults to [validDrawingColor] with 0.3 opacity if not specified.
  final Color drawingFillColor;         
  
  /// Color used for highlighting selected shapes (e.g., border or overlay).
  /// Defaults to [Colors.yellowAccent].
  final Color selectionHighlightColor;  
  
  /// Color for interactive editing handles (e.g., resize handles, PolyEditor vertex/intermediate points).
  /// Defaults to [Colors.orangeAccent].
  final Color editingHandleColor;       

  // Icons / Widgets
  /// {@macro point_icon_builder}
  ///
  /// If `null`, a default [Icons.location_on] is used.
  final PointIconBuilder? pointIconBuilder;        
  
  /// {@macro simple_icon_builder}
  /// Used for the intermediate points (midpoints) in `PolyEditor` when drawing or editing polygons/polylines.
  ///
  /// If `null`, a default [Icons.lens] is used.
  final SimpleIconBuilder? intermediateIconBuilder; 
  
  /// {@macro simple_icon_builder}
  /// Used for the main vertex points in `PolyEditor` when drawing or editing polygons/polylines.
  ///
  /// If `null`, a default [Icons.circle] is used.
  final SimpleIconBuilder? vertexIconBuilder;       

  /// Helper method to get a concrete point icon.
  ///
  /// Provides a default [Icon] if [pointIconBuilder] is not set.
  /// The default icon changes color and size based on the `isSelected` state.
  Widget getPointIcon(ShapeData? shapeData, bool isSelected) {
    if (pointIconBuilder != null) {
      return pointIconBuilder!(shapeData, isSelected);
    }
    return Icon(
      Icons.location_on,
      color: isSelected ? selectionHighlightColor : validDrawingColor,
      size: isSelected ? 36 : 30,
    );
  }

  /// Helper method for `PolyEditor` intermediate (midpoint) icons.
  ///
  /// Provides a default [Icon] if [intermediateIconBuilder] is not set.
  Widget getIntermediateIcon() {
    if (intermediateIconBuilder != null) {
      return intermediateIconBuilder!();
    }
    return Icon(Icons.lens, size: 15, color: editingHandleColor.withOpacity(0.6));
  }
  
  /// Helper method for `PolyEditor` main vertex icons.
  ///
  /// Provides a default [Icon] if [vertexIconBuilder] is not set.
  Widget getVertexIcon() {
    if (vertexIconBuilder != null) {
      return vertexIconBuilder!();
    }
    return Icon(Icons.circle, size: 20, color: editingHandleColor.withOpacity(0.8));
  }
}
