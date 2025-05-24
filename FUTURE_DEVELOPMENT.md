# Future Development for flutter_map_drawing_tools

This document outlines planned features, desirable refinements, and areas for future work to enhance the `flutter_map_drawing_tools` plugin. The initial refactoring of `DrawingLayer.dart` into a modular architecture (with `DrawingLayerCoordinator`, `NewShapeGestureManager`, `ShapeSelectionManager`, `ShapeEditManager`, `PolyEditorManager`, and `DrawingRenderer`) and the implementation of "Invalid Placement Indication" and comprehensive testing have laid a solid foundation.

The following items are grouped by their nature and expand upon the original future development goals, incorporating details from the comprehensive plugin specification.

## I. Core Drawing & Editing Enhancements (Building on Refactoring)

These features were part of the original post-refactoring goals and remain priorities:

1.  **Refined Multi-Part Drawing User Experience (Originally Item 2):**
    *   Achieve a seamless and intuitive interaction with `PolyEditor` when drawing the *active segment* of a multi-part polygon or polyline. This includes robust vertex addition, real-time movement, and deletion for the segment *before* it's completed as a "part".
    *   Establish a clear visual distinction (e.g., styling, interaction cues) for `PolyEditor` when it's being used for a new multi-part segment versus when it's employed for vertex-editing an existing, finalized shape.
    *   **Implement true `MultiLineString` and `MultiPolygon` `ShapeData` types.** This would allow multiple disjoint geometries (e.g., several separate polylines drawn in one session) to be stored under a single `ShapeData` ID.
    *   **Consolidation Logic:** Implement logic to consolidate multiple drawn parts (polygons, polylines, predefined shapes, circles, points) in a single drawing session into a single GeoJSON Multi-geometry (`MultiPolygon`, `MultiLineString`, `MultiPoint` with radius for circles) upon a "Confirm/Save Drawing" action, triggering `onShapeCreated` with the consolidated shape.

2.  **Comprehensive Styling Customization via `DrawingToolsOptions` (Originally Item 3):**
    *   Fully integrate *all* defined color and style options from `DrawingToolsOptions` (e.g., `drawingFillColor`, `temporaryLineColor`, `selectionHighlightColor`, `editingHandleColor`, specific tool styling) into the `DrawingRenderer` and relevant managers.
    *   Ensure that `PolyEditor` icons (`vertexIconBuilder`, `intermediateIconBuilder`) are correctly and dynamically applied via `PolyEditorManager` using the configured `DrawingToolsOptions` for all relevant states (new drawing, vertex editing).

3.  **Numerical Input for Rescale (Originally Item 4):**
    *   Implement the specified mobile-friendly bottom sheet or overlay UI that allows for numerical input of dimensions (e.g., width, height, radius, side length) when the rescale tool is active for a shape. This UI should:
        *   Dynamically update its displayed values as the user performs drag-based rescaling.
        *   Allow direct text input of desired dimensions by the user.
        *   Include a "Done" or "Apply" button to confirm changes made via numerical input.

4.  **Advanced Shape Editing Features (Originally Item 5, expanded):**
    *   **Full Rotate and Rescale Implementation:** Complete the implementation for free rotation and proportional rescaling (with interactive handles) for all applicable shape types within `ShapeEditManager`.
    *   **Undo/Redo Stack:** Implement a robust undo/redo mechanism for drawing actions (adding points, completing parts) and editing operations (move, rotate, scale, vertex changes).
    *   **Complex Geometry Validation:** Introduce more sophisticated client-side validation for complex polygons prior to finalization, such as checking for self-intersections or ensuring correct winding order for hole geometries.

## II. New Feature Implementation (From Detailed Specification)

These features are primarily drawn from the detailed plugin specification and represent new additions or significant expansions:

5.  **Drawing Toolbar UI Implementation:**
    *   Develop a persistent Floating Action Button (FAB) based toolbar, typically on the bottom right of the map.
    *   Use Material Design Icons (e.g., `Icons.polyline`, `Icons.crop_square`, `Icons.circle_outlined`, `Icons.place`) for tool selection.
    *   Implement clear visual indication for the active drawing mode (e.g., highlighted icon, text display).
    *   Include a "Cancel Drawing" button or allow tapping the active tool icon again to exit the current drawing mode.
    *   Ensure visual feedback during drawing:
        *   Dashed lines connecting points in real-time for polygons/polylines/predefined regular polygons.
        *   Semi-transparent circles dynamically resizing during circle drawing.

6.  **Predefined Regular Polygon Drawing Tools:**
    *   Add tools for drawing predefined regular polygons: Pentagon, Hexagon, Octagon (Rectangle is already partially supported).
    *   Workflow: User taps to set the first corner or center, then drags to define an opposite corner or radius.
    *   Include a rotation handle for initial orientation before finalization.

7.  **Explicit Editing Mode Dismissal & Workflow:**
    *   Implement a dedicated "Select/Edit" tool on the toolbar.
    *   When a shape is selected and the `ContextualEditingToolbar` appears, ensure that edits must be explicitly confirmed (triggering `onShapeUpdated`) or canceled via buttons on this toolbar to dismiss the editing mode.

8.  **GeoJSON Import/Export API & Workflow:**
    *   **Import:**
        *   Provide a public method `plugin.importGeoJson(String geojsonString)`.
        *   Internally use `GeoJsonParser().parseGeoJsonAsString(geojsonString)` to convert to flutter_map objects.
        *   Trigger an `onGeoJsonImported(List<GeoJsonFeature> features)` callback to the host application for further processing and persistence.
    *   **Export:**
        *   Provide a method on a `DrawingToolsController` (e.g., `controller.exportGeoJson()`) that the host application can call.
        *   The plugin will serialize its internally managed shapes (from `DrawingState`) into a GeoJSON `FeatureCollection` string.
        *   Circles should be exported as `Point` features with a `radius` in their `properties`.
        *   Logically grouped multi-part shapes should be exported as `MultiPolygon`, `MultiLineString`, or `MultiPoint` features.

9.  **Enhanced User Feedback Mechanisms (UI):**
    *   Beyond the red color for invalid placement (already implemented), provide a `SnackBar` message via the `onPlacementInvalid` callback.
    *   Implement subtle visual confirmation for successful save/update operations (e.g., a quick green `SnackBar` or a temporary glow effect on the shape).
    *   Display red `SnackBar` messages with error details for failed operations.
    *   Show loading indicators during potentially long operations like GeoJSON import/export.

## III. Documentation & Example Application

10. **Comprehensive Project Documentation:**
    *   **README:** Update the main `README.md` with detailed setup instructions, usage examples, and an overview of all features.
    *   **API Documentation:** Generate and publish Dart docs for the public API of the plugin, including all classes, methods, options, and callbacks. Clearly document the purpose and usage of each.
    *   **Wiki/Extended Docs:** Consider a GitHub Wiki or extended documentation pages for more detailed guides on specific features, customization, and advanced usage scenarios.

11. **Multi-Platform Example Application:**
    *   **Goal:** Create a well-documented, easy-to-set-up, and easy-to-run example application showcasing all features of the `flutter_map_drawing_tools` plugin.
    *   **Platforms:** Ensure the example runs correctly on iOS, Android, Web, and Desktop (Windows, macOS, Linux).
    *   **Features Showcased:**
        *   Map setup with `flutter_map`.
        *   Initialization of the `DrawingLayer` and `DrawingToolsOptions`.
        *   Integration of the Drawing Toolbar UI.
        *   Demonstration of all drawing tools: Polygon, Polyline, Circle, Rectangle, Point, and other Predefined Regular Polygons.
        *   Demonstration of multi-part drawing and finalization.
        *   Shape selection and deselection.
        *   All editing workflows: Move, Rotate, Rescale (with numerical input UI), Vertex Editing.
        *   Contextual Editing Toolbar usage.
        *   GeoJSON Import: UI to paste or load a GeoJSON string and see it rendered.
        *   GeoJSON Export: UI button to trigger export and display the resulting GeoJSON string.
        *   Callbacks: Show how `onShapeCreated`, `onShapeUpdated`, `onShapeDeleted`, `onGeoJsonImported`, `onPlacementInvalid`, and `onDrawingModeChanged` are used, perhaps by logging to the screen or a console.
        *   Customization: Examples of how to customize colors and behavior using `DrawingToolsOptions`.
        *   Error Handling: Demonstrate how feedback for invalid placement or failed operations is displayed.
    *   **Structure & Setup:**
        *   Clear, concise code with comments.
        *   Minimal external dependencies beyond what's necessary for the demo.
        *   A `README.md` specific to the example, explaining how to run it on each platform.
        *   Pre-prepared sample GeoJSON data for easy import testing.
    *   **User Experience:** The example should be intuitive for a developer to understand how to integrate and use the plugin in their own Flutter application.

## IV. Technical Debt & Considerations

12. **State Management Integration:**
    *   The current `DrawingState` uses `ChangeNotifier`. Evaluate and potentially integrate a more robust state management solution like `provider` or `flutter_bloc` if the complexity warrants it, as mentioned in the specification. This would be a significant architectural change.

13. **Dependency Management Strategy:**
    *   Continue to directly depend on existing, well-maintained plugins (`flutter_map_line_editor`, `flutter_map_geojson`, etc.).
    *   Regularly monitor these dependencies for updates, breaking changes, and compatibility issues.
    *   If critical issues arise or packages become unmaintained, consider contributing to the upstream, finding alternatives, or forking and maintaining them internally as a last resort.

This expanded list of future development items aims to guide the plugin towards becoming a comprehensive and user-friendly solution for interactive drawing on `flutter_map`.
