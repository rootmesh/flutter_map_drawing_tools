# Flutter Map Drawing Tools - Example Usage

## Overview

This application demonstrates the features and usage of the `flutter_map_drawing_tools` plugin. It shows how to integrate the `DrawingLayer` for displaying and interacting with shapes, the `DrawingToolbar` for selecting tools, and the `DrawingToolsController` for operations like GeoJSON import/export, all within a `FlutterMap` context.

## Running the Example

To run this example application:

1.  **Navigate to the example directory:**
    Open your terminal and change to the `example` directory within the plugin's root folder:
    ```bash
    cd example
    ```

2.  **Ensure Flutter is installed:**
    If you haven't already, install Flutter by following the instructions on the [official Flutter website](https://flutter.dev/docs/get-started/install).

3.  **Get dependencies:**
    Run the following command to fetch the necessary Flutter packages:
    ```bash
    flutter pub get
    ```

4.  **Run the application:**
    Connect a device or start an emulator/simulator, then run the app:
    ```bash
    flutter run
    ```
    You can also choose a specific device if multiple are connected (e.g., `flutter run -d chrome` to run on Chrome).

## Features Demonstrated

The `main.dart` file in this example showcases the following key features of the plugin:

*   **Drawing Various Shape Types:**
    *   Polygons (including multi-part polygons with holes)
    *   Polylines (including multi-segment polylines)
    *   Rectangles
    *   Circles
    *   Points (Markers)
*   **Shape Editing:**
    *   Selecting shapes by tapping.
    *   Moving selected shapes.
    *   Rotating selected shapes.
    *   Rescaling selected Circles and Rectangles using draggable handles.
    *   Editing vertices of Polygons and Polylines.
    *   Deleting selected shapes.
*   **GeoJSON Operations:**
    *   Importing shapes from a sample GeoJSON string (demonstrated via a UI button).
    *   Exporting all currently drawn shapes to a GeoJSON string (demonstrated via a UI button, output to debug console).
*   **Toolbar Interaction:**
    *   Using the `DrawingToolbar` to select different drawing tools and actions.
    *   Dynamic updates to the toolbar based on the current drawing context (e.g., showing "Complete Part" and "Finalize" for multi-part drawings).
*   **Customization via `DrawingToolsOptions`:**
    *   Demonstrates using `pointIconBuilder` to provide custom icons for point markers, including different appearances for selected states.
    *   Shows how to set custom colors for `validDrawingColor` and `selectionHighlightColor`.
*   **State Management:**
    *   Uses `ChangeNotifierProvider` to provide `DrawingState` to the widget tree.
    *   Demonstrates how `DrawingLayer` and `DrawingToolbar` interact with `DrawingState`.
    *   Illustrates the use of `DrawingToolsController` for GeoJSON operations.
*   **Callbacks:**
    *   Shows basic usage of `onShapeCreated`, `onShapeUpdated`, and `onShapeDeleted` callbacks from `DrawingLayer`.

This example provides a practical guide to integrating and utilizing the core functionalities of the `flutter_map_drawing_tools` plugin.
