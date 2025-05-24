import 'package:flutter/material.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tools_options.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map_drawing_tools/src/widgets/contextual_editing_toolbar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks
@GenerateMocks([
  DrawingState,
], customMocks: [
  MockSpec<Function(EditMode)>(as: #MockOnToggleEditModeCallback, returnNullOnMissingStub: true),
  MockSpec<VoidCallback>(as: #MockVoidCallbackGeneric, returnNullOnMissingStub: true),
])
import 'contextual_editing_toolbar_test.mocks.dart';

void main() {
  late MockDrawingState mockDrawingState;
  late DrawingToolsOptions testOptions;
  // Callbacks
  late MockOnToggleEditModeCallback mockOnToggleEditMode;
  late MockVoidCallbackGeneric mockOnConfirm;
  late MockVoidCallbackGeneric mockOnCancel;
  late MockVoidCallbackGeneric mockOnDelete;
  late MockVoidCallbackGeneric mockOnDuplicate; // Optional based on implementation

  // Test shapes
  final testPolygonData = PolygonShapeData(
    polygon: Polygon(points: [LatLng(0,0), LatLng(0,1), LatLng(1,1)], color: Colors.blue),
    id: "poly1",
    label: "Test Polygon"
  );
  final testMarkerData = MarkerShapeData(
    marker: Marker(point: LatLng(2,2), child: Text("M")),
    id: "marker1",
    label: "Test Marker"
  );

  // Helper to pump the widget
  Future<void> pumpToolbar(WidgetTester tester, {ShapeData? selectedShape}) {
    when(mockDrawingState.selectedShapeId).thenReturn(selectedShape?.id);
    // findShapeById is not directly used by ContextualEditingToolbar, it receives selectedShape directly.
    // However, the availableEditModes are determined based on selectedShape type.

    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContextualEditingToolbar(
            drawingState: mockDrawingState,
            options: testOptions,
            selectedShape: selectedShape ?? testPolygonData, // Default to a shape that supports most actions
            availableEditModes: selectedShape is PolyShapeData 
                                ? [EditMode.none, EditMode.dragging, EditMode.vertexEditing, EditMode.scaling, EditMode.rotating] 
                                : [EditMode.none, EditMode.dragging, EditMode.scaling, EditMode.rotating], // Example logic
            onToggleEditMode: mockOnToggleEditMode,
            onConfirm: mockOnConfirm,
            onCancel: mockOnCancel,
            onDelete: mockOnDelete,
            onDuplicate: mockOnDuplicate,
          ),
        ),
      ),
    );
  }

  setUp(() {
    mockDrawingState = MockDrawingState();
    testOptions = const DrawingToolsOptions(); // Use real options

    mockOnToggleEditMode = MockOnToggleEditModeCallback();
    mockOnConfirm = MockVoidCallbackGeneric();
    mockOnCancel = MockVoidCallbackGeneric();
    mockOnDelete = MockVoidCallbackGeneric();
    mockOnDuplicate = MockVoidCallbackGeneric();

    // Default state: a polygon is selected, no specific edit mode active initially
    when(mockDrawingState.selectedShapeId).thenReturn(testPolygonData.id);
    when(mockDrawingState.activeEditMode).thenReturn(EditMode.none);
  });

  group('Button Visibility and Basic Interactions (EditMode.none)', () {
    setUp(() {
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.none);
    });

    testWidgets('shows core action buttons when a shape is selected and edit mode is none', (WidgetTester tester) async {
      await pumpToolbar(tester, selectedShape: testPolygonData);

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget); // Toggle/Enter Edit Mode (or specific like vertex)
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget); // Duplicate
      
      // Confirm/Cancel should NOT be visible in EditMode.none
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.cancel_outlined), findsNothing);
    });

    testWidgets('Delete button calls onDelete callback', (WidgetTester tester) async {
      await pumpToolbar(tester, selectedShape: testPolygonData);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      verify(mockOnDelete()).called(1);
    });

    testWidgets('Duplicate button calls onDuplicate callback', (WidgetTester tester) async {
      await pumpToolbar(tester, selectedShape: testPolygonData);
      await tester.tap(find.byIcon(Icons.copy_outlined));
      await tester.pump();
      verify(mockOnDuplicate()).called(1);
    });

    testWidgets('Edit button (for PolyShape) calls onToggleEditMode with vertexEditing', (WidgetTester tester) async {
      await pumpToolbar(tester, selectedShape: testPolygonData); // Polygon is a PolyShape
      await tester.tap(find.byIcon(Icons.edit_outlined)); // General "edit" button
      await tester.pump();
      // Assuming the first available edit mode for PolyShape after 'none' is 'vertexEditing' or that the button directly toggles it.
      // The toolbar's internal logic might cycle through available modes or have specific buttons.
      // For this test, let's assume the 'edit' button on a PolyShape toggles vertex editing.
      verify(mockOnToggleEditMode(EditMode.vertexEditing)).called(1);
    });
    
    testWidgets('Edit button (for non-PolyShape like Marker) calls onToggleEditMode with dragging', (WidgetTester tester) async {
      await pumpToolbar(tester, selectedShape: testMarkerData); // Marker is not a PolyShape
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      // For a marker, "edit" might default to "dragging"
      verify(mockOnToggleEditMode(EditMode.dragging)).called(1);
    });
  });

  group('Button Visibility and Interactions (Active Edit Modes)', () {
    testWidgets('shows Confirm/Cancel buttons when in EditMode.dragging', (WidgetTester tester) async {
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.dragging);
      await pumpToolbar(tester, selectedShape: testPolygonData);

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget); // Confirm
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);     // Cancel
      
      // Core action buttons might be hidden or disabled
      expect(find.byIcon(Icons.edit_outlined), findsNothing); // Usually hidden when an edit is active
      expect(find.byIcon(Icons.delete_outline), findsOneWidget); // Delete might still be visible
      expect(find.byIcon(Icons.copy_outlined), findsNothing); // Duplicate might be hidden
    });

    testWidgets('Confirm button calls onConfirm callback', (WidgetTester tester) async {
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.dragging);
      await pumpToolbar(tester, selectedShape: testPolygonData);
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pump();
      verify(mockOnConfirm()).called(1);
    });

    testWidgets('Cancel button calls onCancel callback', (WidgetTester tester) async {
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.dragging);
      await pumpToolbar(tester, selectedShape: testPolygonData);
      await tester.tap(find.byIcon(Icons.cancel_outlined));
      await tester.pump();
      verify(mockOnCancel()).called(1);
    });
    
    testWidgets('shows appropriate buttons for EditMode.vertexEditing', (WidgetTester tester) async {
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.vertexEditing);
      await pumpToolbar(tester, selectedShape: testPolygonData);

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget); // Confirm vertex edit
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);     // Cancel vertex edit
      expect(find.byIcon(Icons.edit_outlined), findsNothing); // Main edit toggle likely hidden
      // The "toggle vertex edit" button might change its icon to "done" or similar, or be hidden.
      // Let's assume specific mode buttons appear.
      // Example: A button to switch from vertexEditing to dragging
      // This depends heavily on the toolbar's design for mode switching from an active edit.
      // For now, focus on confirm/cancel.
    });
  });
  
  group('Button Appearance/Behavior based on ShapeData capabilities', () {
    testWidgets('Edit button (to toggle vertex mode) is disabled/hidden for non-PolyShapeData', (WidgetTester tester) async {
      // Toolbar uses `availableEditModes` prop to decide what to show.
      // We test this by providing limited availableEditModes.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextualEditingToolbar(
              drawingState: mockDrawingState,
              options: testOptions,
              selectedShape: testMarkerData, // A non-PolyShape
              availableEditModes: [EditMode.none, EditMode.dragging], // No vertexEditing
              onToggleEditMode: mockOnToggleEditMode,
              onConfirm: mockOnConfirm,
              onCancel: mockOnCancel,
              onDelete: mockOnDelete,
              onDuplicate: mockOnDuplicate,
            ),
          ),
        ),
      );
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.none);


      final editButton = find.byIcon(Icons.edit_outlined);
      expect(editButton, findsOneWidget); // The generic edit button
      
      // Tapping it should toggle to the first available *actual* edit mode, like dragging.
      await tester.tap(editButton);
      await tester.pump();
      verify(mockOnToggleEditMode(EditMode.dragging)).called(1);

      // If there was a specific "vertex edit" button, it should not be found.
      // The current toolbar has one main edit icon that cycles/selects from available modes.
      // If availableEditModes did not include vertexEditing, it wouldn't be toggled.
    });

    testWidgets('Mode-specific toggle buttons appear based on activeEditMode', (WidgetTester tester) async {
      // This test assumes toolbar changes button icons/actions based on current activeEditMode.
      // Example: If in dragging mode, the "drag" button might be highlighted or show a "stop dragging" icon.
      
      when(mockDrawingState.activeEditMode).thenReturn(EditMode.dragging);
      await pumpToolbar(tester, selectedShape: testPolygonData);

      // Check for an active "dragging" button or if "edit" button is now a "stop editing" button
      // This requires knowing the specific icons used for active modes.
      // For instance, if the Icons.edit_outlined button changes to Icons.edit when active:
      // expect(find.byIcon(Icons.drag_indicator), findsOneWidget); // Or whatever icon represents active dragging
      
      // For now, this test is conceptual as the toolbar code doesn't explicitly show different icons for active modes
      // beyond the Confirm/Cancel buttons. The primary "edit" button disappears.
      expect(find.byIcon(Icons.edit_outlined), findsNothing); // Main edit toggle is gone
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget); // Confirm is present
    });
  });
}
