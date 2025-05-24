import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_drawing_tools/src/managers/new_shape_gesture_manager.dart';
import 'package:flutter_map_drawing_tools/src/managers/poly_editor_manager.dart';
import 'package:flutter_map_drawing_tools/src/managers/shape_edit_manager.dart';
import 'package:flutter_map_drawing_tools/src/managers/shape_selection_manager.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map_drawing_tools/src/rendering/drawing_renderer.dart';
import 'package:flutter_map_drawing_tools/src/widgets/drawing_layer_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for these classes
@GenerateMocks([
  DrawingState,
  DrawingToolsOptions,
  MapController,
  Stream, // For MapEventStream
  StreamSubscription, // For _mapEventSubscription
  NewShapeGestureManager,
  ShapeSelectionManager,
  ShapeEditManager,
  PolyEditorManager,
  DrawingRenderer,
  MapTransformer, // Although concrete, it's good to mock for controlling its behavior
], customMocks: [
   MockSpec<Function(ShapeData)>(as: #MockOnShapeCallback, returnNullOnMissingStub: true),
])
import 'drawing_layer_coordinator_test.mocks.dart';

// Helper to get a real MapTransformer for tests that need it
MapTransformer getTestMapTransformer({LatLng center = const LatLng(0,0), double zoom = 13.0}) {
  return MapTransformer(
    mapState: MapState(
      crs: const Epsg3857(),
      center: center,
      zoom: zoom,
    ),
  );
}


void main() {
  late MockDrawingState mockDrawingState;
  late MockDrawingToolsOptions mockOptions;
  late MockMapController mockMapController;
  late MockStream<MapEvent> mockMapEventStream; // Mock the Stream itself
  late MockStreamSubscription<MapEvent> mockMapEventSubscription; // Mock the subscription

  late MockNewShapeGestureManager mockNewShapeGestureManager;
  late MockShapeSelectionManager mockShapeSelectionManager;
  late MockShapeEditManager mockShapeEditManager;
  late MockPolyEditorManager mockPolyEditorManager;
  late MockDrawingRenderer mockDrawingRenderer;
  late MockMapTransformer mockMapTransformer;

  // To capture the listener passed to drawingState.addListener
  late Function drawingStateListenerCallback; 

  // This is the state class we are primarily testing
  late _DrawingLayerCoordinatorState state;

  // Helper to create a DrawingLayerCoordinator widget instance
  DrawingLayerCoordinator createWidget() {
    return DrawingLayerCoordinator(
      mapController: mockMapController,
      drawingState: mockDrawingState,
      options: mockOptions,
      // Callbacks are not directly tested here but passed to DrawingRenderer
      onShapeCreated: (_) {},
      onShapeUpdated: (_) {},
      onShapeDeleted: (_) {},
    );
  }

  setUp(() {
    mockDrawingState = MockDrawingState();
    mockOptions = MockDrawingToolsOptions();
    mockMapController = MockMapController();
    mockMapEventStream = MockStream<MapEvent>();
    mockMapEventSubscription = MockStreamSubscription<MapEvent>();

    mockNewShapeGestureManager = MockNewShapeGestureManager();
    mockShapeSelectionManager = MockShapeSelectionManager();
    mockShapeEditManager = MockShapeEditManager();
    mockPolyEditorManager = MockPolyEditorManager();
    mockDrawingRenderer = MockDrawingRenderer();
    mockMapTransformer = MockMapTransformer();


    // Default stubbing for MapController and its stream
    when(mockMapController.mapEventStream).thenReturn(mockMapEventStream);
    when(mockMapEventStream.listen(any, onError: anyNamed('onError'), onDone: anyNamed('onDone'), cancelOnError: anyNamed('cancelOnError')))
        .thenReturn(mockMapEventSubscription);
    when(mockMapController.camera).thenReturn(MapCamera(center: LatLng(0,0), zoom: 13)); // Default camera
    when(mockMapController.rotate).thenReturn(0.0); // Default rotation
     // Stubbing for MapTransformer (can be overridden in specific tests)
    when(mockMapController.transformer).thenReturn(mockMapTransformer);
    when(mockMapTransformer.getTransformer(any)).thenReturn(getTestMapTransformer()); // Return a real one

    // Default stubbing for DrawingState
    when(mockDrawingState.currentTool).thenReturn(DrawingTool.none);
    when(mockDrawingState.selectedShapeId).thenReturn(null);
    when(mockDrawingState.activeEditMode).thenReturn(EditMode.none);
    when(mockDrawingState.isMultiPartDrawingInProgress).thenReturn(false);
    // Capture the listener
    when(mockDrawingState.addListener(any)).thenAnswer((invocation) {
      drawingStateListenerCallback = invocation.positionalArguments.first;
    });
    when(mockDrawingState.removeListener(any)).thenAnswer((_) {});


    // Default stubbing for PolyEditorManager
    when(mockPolyEditorManager.initPolyEditor()).thenReturn(null); // void method
    when(mockPolyEditorManager.reinitializePolyEditorState()).thenReturn(null);
    when(mockPolyEditorManager.dispose()).thenReturn(null);
    when(mockPolyEditorManager.instance).thenReturn(null); // Default to no PolyEditor instance

    // Default stubbing for ShapeEditManager
    when(mockShapeEditManager.onEditModeChanged()).thenReturn(null);
    when(mockShapeEditManager.dispose()).thenReturn(null);
    
    // Default stubbing for DrawingRenderer
    when(mockDrawingRenderer.buildLayers(any)).thenReturn([]);


    // Instantiate the State class directly for focused unit testing
    // This bypasses some widget lifecycle complexities but allows direct method testing.
    // For methods like 'build', WidgetTester is preferred.
    final coordinatorWidget = createWidget();
    state = _DrawingLayerCoordinatorState();
    
    // Manually set widget for the state object if testing state directly
    // This is a bit of a hack for unit testing state. WidgetTester handles this naturally.
    // Need a way to associate the widget with the state.
    // One approach: make managers settable or use a test-specific constructor for state.
    // For now, we will test methods that don't deeply rely on widget properties if not using WidgetTester.
    // Or, use WidgetTester.pumpWidget to create the state.
    
    // Let's setup mocks for the managers that would be created in initState
    // This assumes we can intercept their creation or inject them.
    // For a direct state test, we might need to make them public or pass them in.
    // Alternative: Test via WidgetTester.pumpWidget to ensure initState runs.
  });

  // Helper to simulate initState for the state object when not using WidgetTester
  // This requires managers to be injectable or accessible for verification.
  // For simplicity in this environment, we'll assume manager creation is tested
  // via verifying their methods are called, implying they were created.

  group('Initialization (initState)', () {
    testWidgets('initializes managers and sets up listeners', (WidgetTester tester) async {
      // Use pumpWidget to ensure initState is called
      await tester.pumpWidget(createWidget()); 
      
      // Access the state
      final actualState = tester.state<_DrawingLayerCoordinatorState>(find.byType(DrawingLayerCoordinator));

      // Verify managers were "created" (by checking if their init methods were called if applicable)
      // In the actual code, managers are created directly. Here we'd check for their existence if they were fields.
      expect(actualState.newShapeGestureManager, isNotNull);
      expect(actualState.shapeSelectionManager, isNotNull);
      expect(actualState.shapeEditManager, isNotNull);
      expect(actualState.polyEditorManager, isNotNull);
      expect(actualState.drawingRenderer, isNotNull);
      
      // Verify PolyEditorManager.initPolyEditor was called
      // This requires polyEditorManager to be the instance created by the state.
      // For this, we might need to inject mocks or use a more complex setup.
      // For now, let's assume we can verify if the polyEditorManager field on state was init'd.
      // This test is more about the sequence in initState.
      // If we could inject mocks: verify(mockPolyEditorManager.initPolyEditor()).called(1);

      // Verify listeners
      verify(mockDrawingState.addListener(actualState._onDrawingStateChanged)).called(1);
      verify(mockMapEventStream.listen(actualState._handleMapEvent, 
                                      onError: anyNamed('onError'), 
                                      onDone: anyNamed('onDone'), 
                                      cancelOnError: anyNamed('cancelOnError'))).called(1);
      expect(actualState._mapEventSubscription, isNotNull);
    });
  });

  group('Map Event Handling and StreamBuilder Integration', () {
    late StreamController<MapEvent> mapEventController;

    setUp(() {
      // Reset the map event stream for focused testing of StreamBuilder
      mapEventController = StreamController<MapEvent>.broadcast();
      when(mockMapController.mapEventStream).thenReturn(mapEventController.stream);
      // Ensure the listen call on the new stream returns the mock subscription for dispose verification
      when(mapEventController.stream.listen(any, onError: anyNamed('onError'), onDone: anyNamed('onDone'), cancelOnError: anyNamed('cancelOnError')))
        .thenReturn(mockMapEventSubscription);
    });

    tearDown(() {
      mapEventController.close();
    });
    
    testWidgets('StreamBuilder listens and _handleMapEvent delegates to NewShapeGestureManager', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      final actualState = tester.state<_DrawingLayerCoordinatorState>(find.byType(DrawingLayerCoordinator));
      
      // Replace managers with mocks AFTER initState has run
      actualState.newShapeGestureManager = mockNewShapeGestureManager;
      actualState.shapeSelectionManager = mockShapeSelectionManager;
      actualState.shapeEditManager = mockShapeEditManager;

      when(mockDrawingState.currentTool).thenReturn(DrawingTool.circle);
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.none);

      final tapEvent = MapEventTap(source: MapEventSource.tap, camera: MapCamera.initial(), tapPosition: LatLng(0,0));
      mapEventController.add(tapEvent); // Emit event via stream
      await tester.pump(); // Process the stream event and subsequent setState

      verify(mockNewShapeGestureManager.handleMapEvent(tapEvent, any)).called(1);
      verifyNever(mockShapeSelectionManager.handleTap(any, any));
      verifyNever(mockShapeEditManager.handleMapEvent(any));
    });


    // The following tests directly call _handleMapEvent. They are more like unit tests for the method's logic.
    // The test above verifies the StreamBuilder plumbing.
    testWidgets('Direct call: _handleMapEvent delegates to NewShapeGestureManager for drawing tools', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      final actualState = tester.state<_DrawingLayerCoordinatorState>(find.byType(DrawingLayerCoordinator));
      
      // Replace managers with mocks AFTER initState has run
      actualState.newShapeGestureManager = mockNewShapeGestureManager;
      actualState.shapeSelectionManager = mockShapeSelectionManager;
      actualState.shapeEditManager = mockShapeEditManager;

      when(mockDrawingState.currentTool).thenReturn(DrawingTool.circle);
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.none); // Not vertex editing

      final tapEvent = MapEventTap(source: MapEventSource.tap, camera: MapCamera.initial(), tapPosition: LatLng(0,0));
      actualState._handleMapEvent(tapEvent);

      verify(mockNewShapeGestureManager.handleMapEvent(tapEvent, any)).called(1);
      verifyNever(mockShapeSelectionManager.handleTap(any, any));
      verifyNever(mockShapeEditManager.handleMapEvent(any));
    });

    testWidgets('Direct call: _handleMapEvent delegates to ShapeSelectionManager for selection', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      final actualState = tester.state<_DrawingLayerCoordinatorState>(find.byType(DrawingLayerCoordinator));
      actualState.newShapeGestureManager = mockNewShapeGestureManager;
      actualState.shapeSelectionManager = mockShapeSelectionManager;
      actualState.shapeEditManager = mockShapeEditManager;

      when(mockDrawingState.currentTool).thenReturn(DrawingTool.none); // Or edit/delete tool
      final tapEvent = MapEventTap(source: MapEventSource.tap, camera: MapCamera.initial(), tapPosition: LatLng(0,0));
      actualState._handleMapEvent(tapEvent);

      verify(mockShapeSelectionManager.handleTap(tapEvent.tapPosition, any)).called(1);
      verifyNever(mockNewShapeGestureManager.handleMapEvent(any, any));
      verifyNever(mockShapeEditManager.handleMapEvent(any));
    });

    testWidgets('Direct call: _handleMapEvent delegates to ShapeEditManager for dragging mode', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      final actualState = tester.state<_DrawingLayerCoordinatorState>(find.byType(DrawingLayerCoordinator));
      actualState.newShapeGestureManager = mockNewShapeGestureManager;
      actualState.shapeSelectionManager = mockShapeSelectionManager;
      actualState.shapeEditManager = mockShapeEditManager;

      when(mockDrawingState.selectedShapeId).thenReturn("some_id");
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.dragging);
      when(mockDrawingState.currentTool).thenReturn(DrawingTool.edit);


      final moveEvent = MapEventPointerMove(source: MapEventSource.pointerMove, camera: MapCamera.initial(), pointerPosition: LatLng(0,0), buttons: kPrimaryMouseButton);
      actualState._handleMapEvent(moveEvent);
      
      verify(mockShapeEditManager.handleMapEvent(moveEvent)).called(1);
      verifyNever(mockNewShapeGestureManager.handleMapEvent(any, any));
      verifyNever(mockShapeSelectionManager.handleTap(any, any));
    });
    
    testWidgets('Direct call: _handleMapEvent does not delegate during vertex editing for general map events', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      final actualState = tester.state<_DrawingLayerCoordinatorState>(find.byType(DrawingLayerCoordinator));
      actualState.newShapeGestureManager = mockNewShapeGestureManager;
      actualState.shapeSelectionManager = mockShapeSelectionManager;
      actualState.shapeEditManager = mockShapeEditManager;

      when(mockDrawingState.selectedShapeId).thenReturn("some_id");
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.vertexEditing);
      when(mockDrawingState.currentTool).thenReturn(DrawingTool.edit); 

      final tapEvent = MapEventTap(source: MapEventSource.tap, camera: MapCamera.initial(), tapPosition: LatLng(1,1));
      actualState._handleMapEvent(tapEvent);

      verifyNever(mockNewShapeGestureManager.handleMapEvent(any, any));
      verifyNever(mockShapeSelectionManager.handleTap(any, any));
      verifyNever(mockShapeEditManager.handleMapEvent(any));
    });
  });

  group('DrawingState Listener (_onDrawingStateChanged)', () {
    // To test _onDrawingStateChanged, we need to trigger it after state is initialized.
    // We captured `drawingStateListenerCallback` in the outer setUp.

    testWidgets('calls manager methods and setState on drawing state change', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      final actualState = tester.state<_DrawingLayerCoordinatorState>(find.byType(DrawingLayerCoordinator));
      
      // Replace managers with mocks
      actualState.shapeEditManager = mockShapeEditManager;
      actualState.polyEditorManager = mockPolyEditorManager;
      
      // Simulate a state change by invoking the captured listener
      // Ensure the listener was captured
      expect(drawingStateListenerCallback, isNotNull, reason: "DrawingState listener was not captured.");
      
      // Call the listener directly
      if(drawingStateListenerCallback != null) {
        drawingStateListenerCallback(); // This is equivalent to drawingState.notifyListeners()
      } else {
        fail("Listener not captured");
      }

      // Verify methods called within _onDrawingStateChanged
      verify(mockShapeEditManager.onEditModeChanged()).called(1);
      verify(mockPolyEditorManager.reinitializePolyEditorState()).called(1);
      
      // Verify setState was called (indirectly by checking if build is called again)
      // This requires pump() to process the setState.
      await tester.pump(); // Process the setState
      // If build is called, drawingRenderer.buildLayers would be called again.
      // This relies on drawingRenderer being the one from actualState.
      verify(actualState.drawingRenderer.buildLayers(any)).called(atLeast(1)); // Called once on initial build, once on setState
    });
  });

  group('Build Method', () {
    testWidgets('calls drawingRenderer.buildLayers and builds StreamBuilder', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      final actualState = tester.state<_DrawingLayerCoordinatorState>(find.byType(DrawingLayerCoordinator));
      
      // Replace renderer with mock to verify interaction
      actualState.drawingRenderer = mockDrawingRenderer;
      when(mockDrawingRenderer.buildLayers(any)).thenReturn([Container(key: Key("test_layer"))]); // Return a dummy layer

      // Trigger a build (it already happened with pumpWidget, but to be sure)
      await tester.pump(); 

      verify(mockDrawingRenderer.buildLayers(any)).called(atLeast(1));
      expect(find.byType(GestureDetector), findsOneWidget);
      expect(find.byType(StreamBuilder<MapEvent>), findsOneWidget);
      expect(find.byKey(Key("test_layer")), findsOneWidget); // Check if our dummy layer is there
    });
  });

  group('Dispose', () {
    testWidgets('disposes managers and listeners', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      final actualState = tester.state<_DrawingLayerCoordinatorState>(find.byType(DrawingLayerCoordinator));

      // Replace managers with mocks to verify their dispose methods
      actualState.shapeEditManager = mockShapeEditManager;
      actualState.polyEditorManager = mockPolyEditorManager;
      // Ensure subscription is the mocked one
      actualState._mapEventSubscription = mockMapEventSubscription; 


      // Manually call dispose on the state
      // For StatefulWidget, unmounting it calls dispose.
      await tester.pumpWidget(Container()); // Replace with empty container to unmount

      verify(mockDrawingState.removeListener(actualState._onDrawingStateChanged)).called(1);
      verify(mockMapEventSubscription.cancel()).called(1);
      verify(mockShapeEditManager.dispose()).called(1);
      verify(mockPolyEditorManager.dispose()).called(1);
      // Verify other managers' dispose if they have it
    });
  });
}
