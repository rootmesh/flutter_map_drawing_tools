# Future Development & Proposed Refactoring for flutter_map_drawing_tools

The current version of the `flutter_map_drawing_tools` plugin provides a solid foundation with core drawing and editing functionalities. However, several planned features and desirable refinements could not be fully implemented in this iteration. This was primarily due to significant operational constraints encountered when attempting to modify and enhance the central `DrawingLayer.dart` file, which currently manages a wide range of responsibilities.

The recommended path to address these limitations, improve overall code health, enhance testability, and enable robust future development is a **comprehensive refactoring of `DrawingLayer.dart`**.

## Proposed Refactoring Strategy for `DrawingLayer.dart`

The core idea is to decompose `DrawingLayer.dart` into smaller, more focused, single-responsibility classes. This modular approach will make the codebase easier to understand, maintain, test, and extend. The envisioned components are:

*   **`DrawingLayerCoordinator` (Refactored `DrawingLayer`):** This would remain the main StatefulWidget, but its role would shift to coordinating interactions between the new, specialized manager classes. It would instantiate these managers, manage the `MapEventStreamListener`, and oversee the primary `build()` method (which might delegate rendering tasks to a `DrawingRenderer`).
*   **`NewShapeGestureManager`:** This class would be dedicated to handling all map gestures (`MapEvent` processing) specifically for the *creation of new shapes*. This includes single-gesture shapes like circles and rectangles, as well as the point-by-point addition for multi-part polygons and polylines. It would manage any temporary state related to these new drawings and interact with `DrawingState` to finalize them.
*   **`ShapeSelectionManager`:** Its sole focus would be managing the selection and deselection of existing shapes. This includes handling tap events on the map and implementing the necessary hit-testing logic to identify which shape was tapped. It would then update `DrawingState` with the selection status.
*   **`ShapeEditManager`:** This component would take over the management of active editing modes once a shape is selected (i.e., Move, Rotate, Scale). It would handle the specific gesture interactions for these modes (e.g., dragging the shape, dragging rotation or scaling handles), manage `_draftShapeData` for live previews of these edits, and interact with `DrawingState` to confirm or cancel changes.
*   **`PolyEditorManager`:** This class would encapsulate all aspects of managing the `PolyEditor` instance from `flutter_map_line_editor`. Its key responsibility would be to correctly initialize and configure `PolyEditor` (points, `addClosePathMarker` setting, custom icons from options) based on the current context: whether it's being used for drawing a new segment of a multi-part polygon/polyline, or for vertex-editing an existing, finalized shape. This would include the logic previously envisioned for `_reinitializePolyEditorBasedOnState()`.
*   **`DrawingRenderer` (Conceptual):** This class (or a set of well-defined methods within `DrawingLayerCoordinator`) would be responsible for all rendering logic currently in `DrawingLayer.build()`. It would take data from `DrawingState` (for finalized shapes), `ShapeEditManager` (for `_draftShapeData`), `PolyEditorManager` (for `PolyEditor`'s visual components like lines and handles), and `NewShapeGestureManager` (for temporary visuals of shapes being newly drawn) to construct the complete visual stack of `flutter_map` layers.

## Key Missing/Incomplete Features to be Addressed Post-Refactoring:

Successfully refactoring `DrawingLayer.dart` as described above would unlock the ability to implement the following features more robustly and maintainably:

1.  **Full "Invalid Placement Indication":**
    *   Implement dynamic visual feedback (changing line/fill colors to `invalidDrawingColor` from `DrawingToolsOptions`) for *all* temporary drawing elements when `validateShapePlacement` returns `false`.
    *   This includes the active drawing line/handles managed by `PolyEditor` during multi-part drawing, temporary polygons from predefined shape tools, and temporary circles.
    *   Provide a mechanism for the host application to display user-friendly on-screen messages (e.g., via a callback like `onPlacementInvalid(String message)`) when an invalid placement is attempted, complementing the color changes.
    *   Ensure that the finalization of any shape or multi-part drawing is robustly prevented if its placement is deemed invalid at any stage.

2.  **Refined Multi-Part Drawing User Experience:**
    *   Achieve a seamless and intuitive interaction with `PolyEditor` when drawing the *active segment* of a multi-part polygon or polyline. This includes robust vertex addition, real-time movement, and deletion for the segment *before* it's completed as a "part" using the "Complete Part" button.
    *   Establish a clear visual distinction and behavior for `PolyEditor` when it's being used for a new multi-part segment versus when it's employed for vertex-editing an existing, finalized shape.
    *   Potentially implement true `MultiLineString` and `MultiPolygon` `ShapeData` types. This would allow multiple disjoint geometries (e.g., several separate polylines drawn in one session) to be stored under a single `ShapeData` ID and correctly handled in GeoJSON export as `MultiFeature` types. (Currently, multi-part polylines are finalized as separate `LineString` features).

3.  **Comprehensive Styling Customization via `DrawingToolsOptions`:**
    *   Fully integrate all defined color options from `DrawingToolsOptions` (e.g., `drawingFillColor`, `temporaryLineColor`, `selectionHighlightColor`, `editingHandleColor`) into the refactored rendering logic (`DrawingRenderer` or equivalent). This would allow users to extensively theme the drawing tools.
    *   Ensure that `PolyEditor` icons (`vertexIconBuilder`, `intermediateIconBuilder`) are correctly and dynamically applied via `PolyEditorManager` using the configured `DrawingToolsOptions`.

4.  **Numerical Input for Rescale:**
    *   Implement the specified mobile-friendly bottom sheet or overlay UI that allows for numerical input of dimensions (e.g., width, height, radius, side length) when the rescale tool is active for a shape. This UI should:
        *   Dynamically update its displayed values as the user performs drag-based rescaling.
        *   Allow direct text input of desired dimensions by the user.
        *   Include a "Done" or "Apply" button to confirm changes made via numerical input.

5.  **Advanced Shape Editing Features (Longer-Term Future Considerations):**
    *   **Undo/Redo Stack:** Implement a robust undo/redo mechanism for drawing actions (adding points, completing parts) and editing operations (move, rotate, scale, vertex changes). This would significantly enhance usability.
    *   **Complex Geometry Validation:** Introduce more sophisticated client-side validation for complex polygons prior to finalization, such as checking for self-intersections or ensuring correct winding order for hole geometries. This would help maintain data integrity.

6.  **Enhanced Testability:**
    *   With the codebase modularized into smaller, focused classes, write comprehensive unit tests for the logic within each manager (e.g., gesture interpretation in `NewShapeGestureManager`, transformation calculations in `ShapeEditManager`, state logic in `PolyEditorManager`).
    *   Develop widget tests for individual UI components like the `DrawingToolbar` and the (refactored) `DrawingLayerCoordinator` with its sub-components.
    *   Aim for integration tests that cover key user flows from tool selection to shape finalization and editing.

Addressing these areas, particularly through the proposed refactoring, will lead to a significantly more robust, customizable, feature-rich, and user-friendly plugin that aligns more closely with the original project specification.
```
