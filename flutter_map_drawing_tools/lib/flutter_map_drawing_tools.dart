/// A Flutter plugin for `flutter_map` providing interactive drawing tools.
///
/// This library exports the main widgets, controllers, and models necessary
/// to integrate drawing functionalities into a `flutter_map` instance.
/// Key components include:
/// - [DrawingLayer]: The core widget that overlays on `FlutterMap` to handle drawing and shape display.
/// - [DrawingToolbar]: A floating action button-based toolbar for selecting drawing tools.
/// - [DrawingToolsController]: Manages the overall state and operations like GeoJSON import/export.
/// - [DrawingState]: A `ChangeNotifier` holding the current drawing status, selected tools, and shapes.
/// - [DrawingToolsOptions]: Configuration for customizing appearance and behavior.
library flutter_map_drawing_tools;

export 'src/widgets/drawing_toolbar.dart';
export 'src/models/drawing_tool.dart';
export 'src/models/drawing_state.dart';
export 'src/widgets/drawing_layer.dart';
export 'src/models/shape_data_models.dart'; 
export 'src/widgets/contextual_editing_toolbar.dart'; 
export 'src/core/drawing_tools_controller.dart'; // Added export
export 'src/models/drawing_tools_options.dart'; // Added export


// Placeholder class for high-level plugin interaction or future extensions.
// Currently, functionality is primarily managed by DrawingToolsController and DrawingState.
// class FlutterMapDrawingTools {
//   // Static methods or properties for global configuration could go here.
// }

// Note: The original DrawingToolsController and DrawingToolsOptions placeholders
// were removed as their actual implementations are now in src/core and src/models respectively.
// If there was a distinct top-level API envisioned for these names, it would be defined here.
// For now, the library primarily acts as an aggregator of exports.
