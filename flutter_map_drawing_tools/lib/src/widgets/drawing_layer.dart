import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map_drawing_tools/src/widgets/drawing_layer_coordinator.dart'; // Import the new coordinator

// Callbacks for shape events (can remain here or be moved if not directly used by DrawingLayer itself)
typedef OnShapeCreatedCallback = void Function(ShapeData shape);
typedef OnShapeUpdatedCallback = void Function(ShapeData shape);
typedef OnShapeDeletedCallback = void Function(String shapeId);

class DrawingLayer extends StatelessWidget { // Changed to StatelessWidget
  final MapController mapController;
  final DrawingState drawingState;
  final DrawingToolsOptions options;
  final OnShapeCreatedCallback? onShapeCreated;
  final OnShapeUpdatedCallback? onShapeUpdated;
  final OnShapeDeletedCallback? onShapeDeleted;

  const DrawingLayer({
    super.key,
    required this.mapController,
    required this.drawingState,
    this.options = const DrawingToolsOptions(),
    this.onShapeCreated,
    this.onShapeUpdated,
    this.onShapeDeleted,
  });

  @override
  Widget build(BuildContext context) {
    // DrawingLayer now delegates its responsibilities to DrawingLayerCoordinator
    return DrawingLayerCoordinator(
      mapController: mapController,
      drawingState: drawingState,
      options: options,
      onShapeCreated: onShapeCreated,
      onShapeUpdated: onShapeUpdated,
      onShapeDeleted: onShapeDeleted,
    );
  }
}

// All state logic, event handling, and detailed build logic has been moved to DrawingLayerCoordinator.
// Helper extensions are also moved to DrawingLayerCoordinator as they were part of its state/logic.
// If any extensions are truly generic and used by other parts of the library,
// they should be moved to a dedicated utility file. For now, assuming they were specific to DrawingLayer's previous implementation.
