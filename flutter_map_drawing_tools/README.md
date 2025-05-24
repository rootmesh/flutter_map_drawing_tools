# Flutter Map Drawing Tools

A Flutter plugin for `flutter_map` to add interactive drawing, editing, and GeoJSON import/export functionalities. This plugin provides a `DrawingLayer` to be used within a `FlutterMap` widget, a `DrawingToolbar` for tool selection, and a `DrawingToolsController` for programmatic control and operations like GeoJSON import/export.

## Features

*   **Drawing Tools:**
    *   Polygons (including multi-part polygons with holes)
    *   Polylines (including multi-segment polylines)
    *   Rectangles
    *   Circles
    *   Points (Markers)
    *   Regular Polygons (Pentagon, Hexagon, Octagon) - (Note: These are drawn as simple polygons; specific geometric constraints for regular polygons during creation are basic).
*   **Editing Tools (for selected shapes):**
    *   **Move:** Drag shapes to new locations.
    *   **Rotate:** Rotate shapes around their center.
    *   **Rescale:** Resize Circles and Rectangles using draggable handles.
    *   **Vertex Edit:** Interactively edit the vertices of Polygons and Polylines using `flutter_map_line_editor`.
    *   **Delete:** Remove shapes.
*   **GeoJSON:**
    *   **Import:** Import shapes from a GeoJSON string. Supports Point, LineString, Polygon, MultiLineString, MultiPolygon. Points with a "radius" property are imported as Circles.
    *   **Export:** Export all drawn shapes to a GeoJSON `FeatureCollection` string.
*   **State Management:**
    *   Centralized `DrawingState` (ChangeNotifier) for managing current tool, selected shape, and all drawn shapes.
    *   `DrawingToolsController` for programmatic interaction (import/export, future operations).
*   **Customization:**
    *   Basic customization via `DrawingToolsOptions`, including some colors and icon builders.

## Usage

Here's a simplified example of how to integrate the drawing tools into your Flutter app:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_drawing_tools/flutter_map_drawing_tools.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    // Provide DrawingState to the widget tree
    ChangeNotifierProvider(
      create: (_) => DrawingState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late DrawingToolsController _drawingToolsController;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Access DrawingState provided by the ChangeNotifierProvider
    final drawingState = Provider.of<DrawingState>(context, listen: false);
    _drawingToolsController = DrawingToolsController(drawingState: drawingState);
  }

  @override
  Widget build(BuildContext context) {
    // Consume DrawingState for building UI elements that depend on it
    // For example, to get the active tool for the toolbar
    final activeTool = context.watch<DrawingState>().currentTool;

    return Scaffold(
      appBar: AppBar(title: const Text('Drawing Tools Example')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(51.509364, -0.128928),
          initialZoom: 9.2,
          // Disable map gestures when drawing or editing to avoid conflicts
          // This can be dynamically managed based on DrawingState.isDrawing or activeEditMode
          // interactionOptions: InteractionOptions(
          //   flags: context.watch<DrawingState>().isDrawing || context.watch<DrawingState>().activeEditMode != EditMode.none
          //       ? InteractiveFlag.none
          //       : InteractiveFlag.all,
          // ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          DrawingLayer(
            mapController: _mapController,
            drawingState: Provider.of<DrawingState>(context, listen: false), // Pass state
            options: DrawingToolsOptions(
              // Example: Custom point icon
              pointIconBuilder: (shapeData, isSelected) {
                return Icon(
                  isSelected ? Icons.location_pin : Icons.location_on_outlined,
                  color: isSelected ? Colors.amber : Colors.blue,
                  size: isSelected ? 40 : 30,
                );
              },
              // Other options can be set here
              validDrawingColor: Colors.green,
              selectionHighlightColor: Colors.orangeAccent,
            ),
            onShapeCreated: (shape) {
              debugPrint('Shape created: ${shape.id}, type: ${shape.runtimeType}');
              // Example: Export to GeoJSON after creation
              // String? geoJson = _drawingToolsController.exportGeoJson();
              // if (geoJson != null) debugPrint('Exported GeoJSON: $geoJson');
            },
            onShapeUpdated: (shape) => debugPrint('Shape updated: ${shape.id}'),
            onShapeDeleted: (id) => debugPrint('Shape deleted: $id'),
          ),
        ],
      ),
      floatingActionButton: DrawingToolbar(
        activeTool: activeTool, // Pass the active tool from DrawingState
        onToolSelected: (DrawingTool tool) {
          // Update DrawingState when a tool is selected from the toolbar
          Provider.of<DrawingState>(context, listen: false).setCurrentTool(tool);
          // Potentially deselect shape if a new drawing tool is chosen
          if (tool != DrawingTool.edit && tool != DrawingTool.none && tool != DrawingTool.cancel) {
            Provider.of<DrawingState>(context, listen: false).deselectShape();
          }
        },
        // availableTools: [DrawingTool.polygon, DrawingTool.point, ...], // Customize tools
      ),
    );
  }
}

```

## Customization

The appearance and behavior of the drawing tools can be customized using the `DrawingToolsOptions` class, which is passed to the `DrawingLayer`.

**Key Customization Options:**

*   **`pointIconBuilder`**: A callback `Widget Function(ShapeData? shapeData, bool isSelected)` that allows you to define custom widgets for point markers. The `isSelected` flag can be used to change the appearance of selected points. This is fully integrated.
*   **Colors:**
    *   `validDrawingColor`: Base color for valid shapes/previews.
    *   `invalidDrawingColor`: Color for invalid placement previews.
    *   `temporaryLineColor`: Color for lines during multi-part drawing.
    *   `drawingFillColor`: Fill for temporary shapes (defaults to `validDrawingColor` with opacity).
    *   `selectionHighlightColor`: Color for highlighting selected shapes.
    *   `editingHandleColor`: Color for editing handles.
*   **Icon Builders for PolyEditor:**
    *   `vertexIconBuilder`: For main vertices in `PolyEditor`.
    *   `intermediateIconBuilder`: For mid-points in `PolyEditor`.

**Note on Styling Integration:** While `DrawingToolsOptions` defines several color and icon properties, their application within `DrawingLayer` for all elements (especially temporary drawing visuals and `PolyEditor` icons/lines based on validity) was not fully completed. The `pointIconBuilder` and core selection highlighting colors are functional.

## Known Limitations

Due to operational constraints encountered with modifying the central `DrawingLayer.dart` file during development, further enhancements to its internal event handling and rendering logic for these features were not completed:

*   **Full "Invalid Placement Indication":** Dynamic styling (using `invalidDrawingColor`) for all temporary drawing visuals (e.g., the active segment of a multi-part polygon/polyline drawn via `PolyEditor`) is not fully implemented. While the `DrawingToolsOptions` exist, their application to dynamically color these elements based on the `_currentPlacementIsValid` flag in `DrawingLayer` is incomplete.
*   **Refined Multi-Part Drawing Experience:** While multi-part polygons (with holes) and polylines can be drawn and finalized, the interactive experience for vertex manipulation of the *currently active drawing segment* using `PolyEditor` might not be fully polished or visually distinct from vertex editing of existing shapes.
*   **Styling Options Application:** The application of several styling options defined in `DrawingToolsOptions` (e.g., `temporaryLineColor` for all cases, `editingHandleColor` for all handle types, dynamic `PolyEditor` icon colors based on state) to all relevant `DrawingLayer` visuals is not yet comprehensive.

## Future Development / Proposed Refactoring

To address the current limitations and facilitate future enhancements, a refactoring of the `DrawingLayer.dart` component is recommended. The proposed strategy involves decomposing its extensive responsibilities into smaller, more focused manager classes, such as:

*   `NewShapeGestureManager`: For handling gestures related to drawing new shapes.
*   `ShapeSelectionManager`: For handling shape selection logic.
*   `ShapeEditManager`: For managing move, rotate, and scale operations.
*   `PolyEditorManager`: For encapsulating all interactions with `PolyEditor` for both multi-part drawing and vertex editing.
*   `DrawingRenderer`: For consolidating rendering logic.

This refactoring aims to improve modularity, testability, and make the codebase easier to maintain and extend.

## How to Run the Example

For detailed instructions on how to run the example application, please see the `README.md` file in the `example` directory.

## Contributing

Issues and pull requests are welcome! If you encounter a bug or have a feature request, please file an issue. If you'd like to contribute, please fork the repository and submit a pull request.
