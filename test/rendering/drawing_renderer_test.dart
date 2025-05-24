import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:flutter_map_drawing_tools/src/managers/poly_editor_manager.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map_drawing_tools/src/rendering/drawing_renderer.dart';
import 'package:flutter_map_drawing_tools/src/widgets/contextual_editing_toolbar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks
@GenerateMocks([
  DrawingState,
  DrawingToolsOptions,
  PolyEditorManager,
  BuildContext,
], customMocks: [
  MockSpec<VoidCallback>(as: #MockVoidCallbackGeneric, returnNullOnMissingStub: true),
  MockSpec<Function(EditMode)>(as: #MockOnToggleEditModeCallback, returnNullOnMissingStub: true),
])
import 'drawing_renderer_test.mocks.dart';

void main() {
  late MockDrawingState mockDrawingState;
  late MockDrawingToolsOptions mockOptions;
  late MockPolyEditorManager mockPolyEditorManager;
  late MockBuildContext mockBuildContext; // Though BuildContext is often not deeply used in render logic
  late DrawingRenderer renderer;

  // Callbacks for toolbar (can be simple mocks or real functions for some tests if needed)
  late MockOnToggleEditModeCallback mockOnToggleEditMode;
  late MockVoidCallbackGeneric mockOnConfirmEdit;
  late MockVoidCallbackGeneric mockOnCancelEdit;
  late MockVoidCallbackGeneric mockOnDeleteShape;


  // Default shapes for testing
  final testPolygonData = PolygonShapeData(
    polygon: Polygon(points: [LatLng(0,0), LatLng(0,1), LatLng(1,1)], color: Colors.blue, borderStrokeWidth: 2, borderColor: Colors.blue),
    id: "poly1",
  );
  final testPolylineData = PolylineShapeData(
    polyline: Polyline(points: [LatLng(2,2), LatLng(3,3)], color: Colors.green, strokeWidth: 3),
    id: "line1",
  );
  final testCircleData = CircleShapeData(
    circleMarker: CircleMarker(point: LatLng(4,4), radius: 100, color: Colors.red.withOpacity(0.3), borderColor: Colors.red, borderStrokeWidth: 2, useRadiusInMeter: true),
    id: "circle1",
  );
  final testMarkerData = MarkerShapeData(
    marker: Marker(point: LatLng(5,5), child: Text("M"), width: 30, height: 30),
    id: "marker1",
  );

  setUp(() {
    mockDrawingState = MockDrawingState();
    mockOptions = MockDrawingToolsOptions();
    mockPolyEditorManager = MockPolyEditorManager();
    mockBuildContext = MockBuildContext();

    mockOnToggleEditMode = MockOnToggleEditModeCallback();
    mockOnConfirmEdit = MockVoidCallbackGeneric();
    mockOnCancelEdit = MockVoidCallbackGeneric();
    mockOnDeleteShape = MockVoidCallbackGeneric();

    // Default stubbing for DrawingToolsOptions
    when(mockOptions.selectedShapeColor).thenReturn(Colors.yellow);
    when(mockOptions.selectedShapeBorderWidthIncrease).thenReturn(2.0);
    when(mockOptions.temporaryLineColor).thenReturn(Colors.grey);
    when(mockOptions.invalidDrawingColor).thenReturn(Colors.pink); // Distinct invalid color
    when(mockOptions.editingHandleColor).thenReturn(Colors.orange);
    when(mockOptions.vertexHandleIcon).thenReturn(Icon(Icons.circle, size:10));
    when(mockOptions.intermediateVertexHandleIcon).thenReturn(Icon(Icons.add_circle, size:8));
    when(mockOptions.vertexHandleRadius).thenReturn(10.0); // For resize handle example
    when(mockOptions.resizeHandleIcon).thenReturn(Icon(Icons.drag_handle));
    when(mockOptions.toolbarPosition).thenReturn(null); // Default toolbar position
    when(mockOptions.polygonCulling).thenReturn(false);
    when(mockOptions.polylineCulling).thenReturn(false);
    when(mockOptions.circleCulling).thenReturn(false);


    // Default stubbing for DrawingState
    when(mockDrawingState.currentShapes).thenReturn([]);
    when(mockDrawingState.temporaryShape).thenReturn(null);
    when(mockDrawingState.draftShapeDataWhileDragging).thenReturn(null);
    when(mockDrawingState.selectedShapeId).thenReturn(null);
    when(mockDrawingState.activeEditMode).thenReturn(EditMode.none);
    when(mockDrawingState.currentTool).thenReturn(DrawingTool.none);
    when(mockDrawingState.findShapeById(any)).thenReturn(null);


    // Default stubbing for PolyEditorManager
    when(mockPolyEditorManager.getPolylineForRendering()).thenReturn(null);
    when(mockPolyEditorManager.getEditMarkers()).thenReturn([]);
    // Accessing internal _isActive directly: `when(mockPolyEditorManager._isActive).thenReturn(false);`
    // For a mock, we'd mock a public getter if _isActive was not public. Assuming _isActive is an internal detail
    // and its effect is tested via getPolylineForRendering/getEditMarkers returning empty/null.
    // Let's assume a way to set its active state for tests:
    when(mockPolyEditorManager.instance).thenReturn(null); // Default to no active PolyEditor instance for _isActive check in renderer

    renderer = DrawingRenderer(
      drawingState: mockDrawingState,
      options: mockOptions,
      polyEditorManager: mockPolyEditorManager,
      onToggleEditMode: mockOnToggleEditMode,
      onConfirmEdit: mockOnConfirmEdit,
      onCancelEdit: mockOnCancelEdit,
      onDeleteShape: mockOnDeleteShape,
    );
  });

  group('Initialization', () {
    test('initializes correctly', () {
      expect(renderer, isNotNull);
    });
  });

  group('Rendering Finalized Shapes', () {
    test('renders various shape types', () {
      when(mockDrawingState.currentShapes).thenReturn([testPolygonData, testPolylineData, testCircleData, testMarkerData]);
      final layers = renderer.buildLayers(mockBuildContext);

      expect(layers.whereType<PolygonLayer>().first.polygons.first, testPolygonData.polygon);
      expect(layers.whereType<PolylineLayer>().first.polylines.first, testPolylineData.polyline);
      expect(layers.whereType<CircleLayer>().first.circles.first, testCircleData.circleMarker);
      expect(layers.whereType<MarkerLayer>().first.markers.first, testMarkerData.marker);
    });

    test('applies selection highlight to polygon', () {
      when(mockDrawingState.currentShapes).thenReturn([testPolygonData]);
      when(mockDrawingState.selectedShapeId).thenReturn(testPolygonData.id);
      
      final layers = renderer.buildLayers(mockBuildContext);
      final renderedPolygon = layers.whereType<PolygonLayer>().first.polygons.first;
      
      expect(renderedPolygon.borderColor, mockOptions.selectedShapeColor);
      expect(renderedPolygon.borderStrokeWidth, testPolygonData.polygon.borderStrokeWidth! + mockOptions.selectedShapeBorderWidthIncrease);
    });
    
    test('applies selection highlight to polyline', () {
      when(mockDrawingState.currentShapes).thenReturn([testPolylineData]);
      when(mockDrawingState.selectedShapeId).thenReturn(testPolylineData.id);
      
      final layers = renderer.buildLayers(mockBuildContext);
      final renderedPolyline = layers.whereType<PolylineLayer>().first.polylines.first;
      
      expect(renderedPolyline.color, mockOptions.selectedShapeColor);
      expect(renderedPolyline.strokeWidth, testPolylineData.polyline.strokeWidth + mockOptions.selectedShapeBorderWidthIncrease);
    });
    
    test('applies selection highlight to circle', () {
      when(mockDrawingState.currentShapes).thenReturn([testCircleData]);
      when(mockDrawingState.selectedShapeId).thenReturn(testCircleData.id);
      
      final layers = renderer.buildLayers(mockBuildContext);
      final renderedCircle = layers.whereType<CircleLayer>().first.circles.first;
      
      expect(renderedCircle.borderColor, mockOptions.selectedShapeColor);
      expect(renderedCircle.borderStrokeWidth, testCircleData.circleMarker.borderStrokeWidth! + mockOptions.selectedShapeBorderWidthIncrease);
    });


    test('does NOT render finalized shape if being vertex-edited', () {
      when(mockDrawingState.currentShapes).thenReturn([testPolygonData]);
      when(mockDrawingState.selectedShapeId).thenReturn(testPolygonData.id);
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.vertexEditing); // Vertex editing active

      final layers = renderer.buildLayers(mockBuildContext);
      expect(layers.whereType<PolygonLayer>(), isEmpty); // Should not render the finalized version
    });
    
    test('does NOT render finalized shape if draft exists for dragging/scaling/rotating', () {
      when(mockDrawingState.currentShapes).thenReturn([testPolygonData]);
      when(mockDrawingState.selectedShapeId).thenReturn(testPolygonData.id);
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.dragging); // Or scaling/rotating
      when(mockDrawingState.draftShapeDataWhileDragging).thenReturn(testPolygonData.copyWith(id: testPolygonData.id)); // Draft exists

      final layers = renderer.buildLayers(mockBuildContext);
      expect(layers.whereType<PolygonLayer>(), isEmpty);
    });
  });

  group('Rendering Temporary Shapes', () {
    test('renders temporary circle with temporary styling', () {
      final tempCircle = CircleShapeData(
        circleMarker: CircleMarker(point: LatLng(6,6), radius: 50, color: mockOptions.temporaryLineColor.withOpacity(0.3), borderColor: mockOptions.temporaryLineColor, useRadiusInMeter: true),
        id: "temp_circle"
      );
      when(mockDrawingState.temporaryShape).thenReturn(tempCircle);
      when(mockDrawingState.currentTool).thenReturn(DrawingTool.circle); // Tool that uses temporaryShape

      final layers = renderer.buildLayers(mockBuildContext);
      final circleLayer = layers.whereType<CircleLayer>().first;
      expect(circleLayer.circles.first, tempCircle.circleMarker);
      expect(circleLayer.circles.first.color, mockOptions.temporaryLineColor.withOpacity(0.3));
      expect(circleLayer.circles.first.borderColor, mockOptions.temporaryLineColor);
    });

    test('renders temporary polygon with invalid styling if color indicates it', () {
       final invalidTempPolygon = PolygonShapeData(
        polygon: Polygon(points: [LatLng(7,7)], color: mockOptions.invalidDrawingColor.withOpacity(0.3), borderColor: mockOptions.invalidDrawingColor),
        id: "invalid_temp_poly"
      );
      when(mockDrawingState.temporaryShape).thenReturn(invalidTempPolygon);
      when(mockDrawingState.currentTool).thenReturn(DrawingTool.rectangle); // Tool that uses temporaryShape

      final layers = renderer.buildLayers(mockBuildContext);
      final polygonLayer = layers.whereType<PolygonLayer>().first;
      expect(polygonLayer.polygons.first, invalidTempPolygon.polygon);
      expect(polygonLayer.polygons.first.color, mockOptions.invalidDrawingColor.withOpacity(0.3));
      expect(polygonLayer.polygons.first.borderColor, mockOptions.invalidDrawingColor);
    });
  });

  group('Rendering Draft Shapes', () {
    test('renders draft polygon with editing styling', () {
      final draftPolygon = PolygonShapeData(
        polygon: Polygon(points: [LatLng(8,8)], color: mockOptions.editingHandleColor.withOpacity(0.3), borderColor: mockOptions.editingHandleColor),
        id: "draft_poly"
      );
      when(mockDrawingState.draftShapeDataWhileDragging).thenReturn(draftPolygon);
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.dragging); // An edit mode that uses draft

      final layers = renderer.buildLayers(mockBuildContext);
      final polygonLayer = layers.whereType<PolygonLayer>().first;
      expect(polygonLayer.polygons.first, draftPolygon.polygon);
       // The renderer now uses the color from the draft shape directly.
      expect(polygonLayer.polygons.first.color, mockOptions.editingHandleColor.withOpacity(0.3));
      expect(polygonLayer.polygons.first.borderColor, mockOptions.editingHandleColor);
    });
  });

  group('Rendering PolyEditor Components', () {
    final polyEditorLine = Polyline(points: [LatLng(9,9), LatLng(10,10)], color: Colors.purple, strokeWidth: 3, isDotted: true);
    final polyEditorMarkers = [DragMarker(point: LatLng(9,9), child: Text("H"))];

    setUp(() {
      // Simulate PolyEditor being active by returning a non-null instance for the _isActive check
      // This requires PolyEditorManager.instance to be part of the condition in renderer's _buildPolyEditorLayers
      // The actual condition in renderer is `if (!polyEditorManager._isActive) return [];`
      // which is not directly mockable. We test the effect: if getPolyline/getEditMarkers return data.
      // For this test, we'll assume polyEditorManager._isActive would be true.
      // Let's mock the public getters instead.
      when(mockPolyEditorManager.getPolylineForRendering()).thenReturn(polyEditorLine);
      when(mockPolyEditorManager.getEditMarkers()).thenReturn(polyEditorMarkers);
    });
    
    test('renders PolyEditor line and markers when active', () {
      final layers = renderer.buildLayers(mockBuildContext);
      
      final polylineLayer = layers.whereType<PolylineLayer>().firstWhere((l) => l.polylines.contains(polyEditorLine), orElse: () => PolylineLayer(polylines: []));
      expect(polylineLayer.polylines, contains(polyEditorLine));
      
      final markerLayer = layers.whereType<DragMarkers>().first; // DragMarkers is the layer type for PolyEditor handles
      expect(markerLayer.markers, equals(polyEditorMarkers));
    });

    test('PolyEditor line uses invalid color if content is invalid', () {
      final invalidPolyEditorLine = Polyline(points: [LatLng(9,9)], color: mockOptions.invalidDrawingColor, isDotted: true);
      when(mockPolyEditorManager.getPolylineForRendering()).thenReturn(invalidPolyEditorLine); // Manager returns it styled as invalid

      final layers = renderer.buildLayers(mockBuildContext);
      final polylineLayer = layers.whereType<PolylineLayer>().firstWhere((l) => l.polylines.contains(invalidPolyEditorLine), orElse: () => PolylineLayer(polylines: []));
      expect(polylineLayer.polylines.first.color, mockOptions.invalidDrawingColor);
    });
  });

  group('Rendering ContextualEditingToolbar', () {
    test('renders toolbar when a shape is selected and tool is edit/none', () {
      when(mockDrawingState.selectedShapeId).thenReturn(testPolygonData.id);
      when(mockDrawingState.findShapeById(testPolygonData.id)).thenReturn(testPolygonData);
      when(mockDrawingState.currentTool).thenReturn(DrawingTool.edit); // Or .none

      final layers = renderer.buildLayers(mockBuildContext);
      expect(layers.whereType<Positioned>().where((p) => p.child is ContextualEditingToolbar), isNotEmpty);
    });

    test('does NOT render toolbar if no shape selected', () {
      when(mockDrawingState.selectedShapeId).thenReturn(null);
      final layers = renderer.buildLayers(mockBuildContext);
      expect(layers.whereType<Positioned>().where((p) => p.child is ContextualEditingToolbar), isEmpty);
    });
    
    test('does NOT render toolbar if in vertex editing mode (default behavior)', () {
      when(mockDrawingState.selectedShapeId).thenReturn(testPolygonData.id);
      when(mockDrawingState.findShapeById(testPolygonData.id)).thenReturn(testPolygonData);
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.vertexEditing);

      final layers = renderer.buildLayers(mockBuildContext);
      expect(layers.whereType<Positioned>().where((p) => p.child is ContextualEditingToolbar), isEmpty);
    });
  });

  group('Rendering Resize Handles (Circle Example)', () {
    test('renders circle resize handle when scaling a circle', () {
      when(mockDrawingState.selectedShapeId).thenReturn(testCircleData.id);
      when(mockDrawingState.findShapeById(testCircleData.id)).thenReturn(testCircleData);
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.scaling);

      final layers = renderer.buildLayers(mockBuildContext);
      final dragMarkersLayer = layers.whereType<DragMarkers>().firstOrNull;
      expect(dragMarkersLayer, isNotNull);
      expect(dragMarkersLayer!.markers.length, 1);
      // Further checks on marker properties if needed (e.g., child type, position relative to circle)
      final handleMarker = dragMarkersLayer.markers.first;
      final expectedHandlePos = const Distance().offset(testCircleData.circleMarker.point, testCircleData.circleMarker.radius, 90);
      expect(handleMarker.point.latitude, closeTo(expectedHandlePos.latitude, 1e-6));
      expect(handleMarker.point.longitude, closeTo(expectedHandlePos.longitude, 1e-6));
      expect(handleMarker.child, isA<Icon>());
    });
  });
}

// Helper extension for Polygon copyWith if not available in the model
extension _PolygonCopyWithHelper on Polygon {
  Polygon copyWith({
    List<LatLng>? points,
    List<List<LatLng>>? holePointsList,
    Color? color,
    double? borderStrokeWidth,
    Color? borderColor,
    bool? disableHolesBorder,
    bool? isFilled,
    bool? isDotted,
  }) {
    return Polygon(
      points: points ?? this.points,
      holePointsList: holePointsList ?? this.holePointsList,
      color: color ?? this.color,
      borderStrokeWidth: borderStrokeWidth ?? this.borderStrokeWidth,
      borderColor: borderColor ?? this.borderColor,
      disableHolesBorder: disableHolesBorder ?? this.disableHolesBorder,
      isFilled: isFilled ?? this.isFilled,
      isDotted: isDotted ?? this.isDotted,
      label: label,
      labelStyle: labelStyle,
      rotateLabel: rotateLabel,
      updateParentBeliefs: updateParentBeliefs,
    );
  }
}
