import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map_drawing_tools/src/widgets/drawing_layer.dart';
import 'package:flutter_map_drawing_tools/src/widgets/drawing_layer_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'dart:async'; // For StreamController

// Generate mocks for MapController and DrawingState
@GenerateMocks([
  MapController,
  DrawingState,
], customMocks: [
  MockSpec<Function(ShapeData)>(as: #MockOnShapeCallback, returnNullOnMissingStub: true),
  MockSpec<Function(String)>(as: #MockOnShapeIdCallback, returnNullOnMissingStub: true),
])
import 'drawing_layer_test.mocks.dart';

void main() {
  late MockMapController mockMapController;
  late MockDrawingState mockDrawingState;
  late DrawingToolsOptions testOptions;
  late MockOnShapeCallback mockOnShapeCreated;
  late MockOnShapeCallback mockOnShapeUpdated;
  late MockOnShapeIdCallback mockOnShapeDeleted;

  setUp(() {
    mockMapController = MockMapController();
    mockDrawingState = MockDrawingState();
    testOptions = const DrawingToolsOptions(
      validDrawingColor: Colors.green, // Use a distinct color for options testing
      temporaryLineColor: Colors.amber,
    );
    mockOnShapeCreated = MockOnShapeCallback();
    mockOnShapeUpdated = MockOnShapeCallback();
    mockOnShapeDeleted = MockOnShapeIdCallback();

    // Default stubbing for MapController
    // Provide a dummy stream for mapEventStream, as DrawingLayerCoordinator will try to listen to it.
    when(mockMapController.mapEventStream).thenAnswer((_) => StreamController<MapEvent>.broadcast().stream);
    // Provide a default camera and transformer
    when(mockMapController.camera).thenReturn(MapCamera(center: LatLng(0,0), zoom: 13));
     final testMapTransformer = MapTransformer(
      mapState: MapState(
        crs: const Epsg3857(),
        center: LatLng(0,0),
        zoom: 13,
      ),
    );
    when(mockMapController.transformer).thenReturn(testMapTransformer);


    // Default stubbing for DrawingState
    when(mockDrawingState.currentTool).thenReturn(DrawingTool.none);
    when(mockDrawingState.selectedShapeId).thenReturn(null);
    when(mockDrawingState.activeEditMode).thenReturn(EditMode.none);
    when(mockDrawingState.isMultiPartDrawingInProgress).thenReturn(false);
    when(mockDrawingState.addListener(any)).thenReturn(null); // For addListener
    when(mockDrawingState.removeListener(any)).thenReturn(null); // For removeListener
  });

  testWidgets('DrawingLayer instantiates DrawingLayerCoordinator and forwards parameters', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp( // Needed for Directionality, MediaQuery, etc.
        home: Scaffold(
          body: FlutterMap( // DrawingLayer is typically a child of FlutterMap
            options: MapOptions(initialCenter: LatLng(0,0), initialZoom: 13),
            children: [
              DrawingLayer(
                mapController: mockMapController,
                drawingState: mockDrawingState,
                options: testOptions,
                onShapeCreated: mockOnShapeCreated,
                onShapeUpdated: mockOnShapeUpdated,
                onShapeDeleted: mockOnShapeDeleted,
              ),
            ],
          ),
        ),
      ),
    );

    // Verify that DrawingLayerCoordinator is in the widget tree
    final coordinatorFinder = find.byType(DrawingLayerCoordinator);
    expect(coordinatorFinder, findsOneWidget);

    // Verify that parameters are correctly forwarded
    final coordinatorWidget = tester.widget<DrawingLayerCoordinator>(coordinatorFinder);
    expect(coordinatorWidget.mapController, equals(mockMapController));
    expect(coordinatorWidget.drawingState, equals(mockDrawingState));
    expect(coordinatorWidget.options, equals(testOptions));
    expect(coordinatorWidget.options.validDrawingColor, Colors.green); // Check a specific option
    expect(coordinatorWidget.onShapeCreated, equals(mockOnShapeCreated));
    expect(coordinatorWidget.onShapeUpdated, equals(mockOnShapeUpdated));
    expect(coordinatorWidget.onShapeDeleted, equals(mockOnShapeDeleted));
  });
}
