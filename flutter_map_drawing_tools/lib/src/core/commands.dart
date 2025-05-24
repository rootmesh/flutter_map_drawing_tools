import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';

// Abstract Command interface
abstract class Command {
  void execute();
  void undo();
  String get description; // For debugging or UI
}

// --- Concrete Commands ---

// Command for creating a new shape
class CreateShapeCommand implements Command {
  final DrawingState _drawingState;
  final ShapeData _shapeData;

  CreateShapeCommand(this._drawingState, this._shapeData);

  @override
  void execute() {
    _drawingState.addShape(_shapeData);
  }

  @override
  void undo() {
    _drawingState.removeShapeById(_shapeData.id);
  }

  @override
  String get description => 'Create shape (${_shapeData.id})';
}

// Command for deleting a shape
class DeleteShapeCommand implements Command {
  final DrawingState _drawingState;
  final ShapeData _shapeData; // Store the whole shape to re-add it on undo

  DeleteShapeCommand(this._drawingState, this._shapeData);

  @override
  void execute() {
    _drawingState.removeShapeById(_shapeData.id);
  }

  @override
  void undo() {
    _drawingState.addShape(_shapeData); // Re-add the original shape
  }

  @override
  String get description => 'Delete shape (${_shapeData.id})';
}

// Command for transforming a shape (move, scale, rotate)
// Also handles vertex edits if we treat the result as a new version of the shape.
class UpdateShapeCommand implements Command {
  final DrawingState _drawingState;
  final ShapeData _newShapeData;
  final ShapeData _originalShapeData; // Shape before this specific transformation

  UpdateShapeCommand(this._drawingState, this._originalShapeData, this._newShapeData)
      : assert(_originalShapeData.id == _newShapeData.id);

  @override
  void execute() {
    _drawingState.updateShape(_newShapeData);
  }

  @override
  void undo() {
    _drawingState.updateShape(_originalShapeData);
  }

  @override
  String get description => 'Update shape (${_newShapeData.id})';
}

// TODO: Add commands for multi-part drawing steps if needed
// e.g., AddPointToActivePartCommand, CompletePartCommand
// These might be complex if each point drag in PolyEditor is a command.
// Simpler: commands for "Complete Part" and "Finalize Multi-Part Shape".

// Command for completing a part in a multi-part drawing
class CompletePartCommand implements Command {
  final DrawingState _drawingState;
  
  // State before the operation
  late List<List<LatLng>> _partsBeforeExecute;
  late DrawingTool? _toolBeforeExecute;
  
  // State after the operation (captured on first execute for redo)
  late List<List<LatLng>> _partsAfterExecute;
  late DrawingTool? _toolAfterExecute;

  CompletePartCommand(this._drawingState) {
    // Capture state immediately before this command is potentially executed
    _partsBeforeExecute = List.unmodifiable(_drawingState.currentDrawingParts.map((part) => List.unmodifiable(part)));
    _toolBeforeExecute = _drawingState.activeMultiPartTool;
  }

  @override
  void execute() {
    // If _partsAfterExecute is already populated, it means this is a "redo" operation.
    // In this case, we restore the state to what it was after the initial "execute".
    if (_partsAfterExecute != null) {
      _drawingState.dangerouslySetCurrentDrawingParts(_partsAfterExecute, _toolAfterExecute);
    } else {
      // This is the first time execute is called (not a redo).
      // The current state in _drawingState is what _partsBeforeExecute captured.
      // Now, perform the action.
      _drawingState.completeCurrentPart(); // This modifies the state in _drawingState
      
      // Capture the state *after* the operation for potential redo.
      _partsAfterExecute = List.unmodifiable(_drawingState.currentDrawingParts.map((part) => List.unmodifiable(part)));
      _toolAfterExecute = _drawingState.activeMultiPartTool;
    }
  }

  @override
  void undo() {
    // Restore the state to what it was before execute was first called.
    _drawingState.dangerouslySetCurrentDrawingParts(_partsBeforeExecute, _toolBeforeExecute);
  }

  @override
  String get description => 'Complete drawing part';
}

// Command for adding a point to the active part of a multi-part drawing
class AddPointToPartCommand implements Command {
  final DrawingState _drawingState;
  final LatLng _point;
  // No need to store pre-execute state for this simple append/remove_last.
  // Assumes that if a part wasn't started, this command wouldn't be created.

  AddPointToPartCommand(this._drawingState, this._point);

  @override
  void execute() {
    // It's assumed that if isMultiPartDrawingInProgress is false,
    // startNewDrawingPart would have been called (possibly by another command or UI logic)
    // before this command is created/executed for the *first* point of a new shape.
    // If not, addPointToCurrentPart might do nothing if _currentDrawingParts is empty.
    // For robustness, one might consider adding a check or ensuring startNewDrawingPart
    // is always handled before the first AddPointToPartCommand for a new shape.
    _drawingState.addPointToCurrentPart(_point);
  }

  @override
  void undo() {
    // This assumes addPointToCurrentPart only adds to the last list,
    // and that this command is undone in the correct sequence.
    _drawingState.removeLastPointFromCurrentPart();
  }

  @override
  String get description => 'Add point to active part';
}

// Command for starting a new multi-part drawing session (or the first part)
class StartNewPartCommand implements Command {
  final DrawingState _drawingState;
  final DrawingTool _toolToStart; // The tool that initiates this new part (e.g., polygon, polyline)
  
  // State before the operation
  late List<List<LatLng>> _partsBeforeExecute;
  late DrawingTool? _toolBeforeExecute; // activeMultiPartTool before
  late DrawingTool _currentToolBeforeExecute; // currentTool before

  // State after the operation (captured on first execute for redo)
  late List<List<LatLng>> _partsAfterExecute;
  late DrawingTool? _toolAfterExecute;
  late DrawingTool _currentToolAfterExecute;


  StartNewPartCommand(this._drawingState, this._toolToStart) {
    _partsBeforeExecute = List.unmodifiable(_drawingState.currentDrawingParts.map((part) => List.unmodifiable(part)));
    _toolBeforeExecute = _drawingState.activeMultiPartTool;
    _currentToolBeforeExecute = _drawingState.currentTool;
  }

  @override
  void execute() {
    if (_partsAfterExecute != null) { // This is a REDO
      _drawingState.dangerouslySetCurrentDrawingParts(_partsAfterExecute, _toolAfterExecute);
      // Potentially restore currentTool as well if startNewDrawingPart changes it implicitly
      // For now, assume setCurrentTool is handled separately or by the callee of this command.
      // However, DrawingState.startNewDrawingPart *does* set _isDrawing = false and notifies.
      // And the external logic might then set currentTool.
      // For redo, we need to ensure the exact state *after* the first execute.
      // This implies that setCurrentTool might need to be part of this command's scope if not handled by DrawingState.
      // For now, let's assume DrawingState.startNewDrawingPart is the main state changer here for multi-part state.
      // And currentTool is managed externally or by DrawingState.setCurrentTool
    } else { // First execution
      _drawingState.startNewDrawingPart(_toolToStart);
      _partsAfterExecute = List.unmodifiable(_drawingState.currentDrawingParts.map((part) => List.unmodifiable(part)));
      _toolAfterExecute = _drawingState.activeMultiPartTool;
      // _currentToolAfterExecute = _drawingState.currentTool; // Capture if needed
    }
  }

  @override
  void undo() {
    _drawingState.dangerouslySetCurrentDrawingParts(_partsBeforeExecute, _toolBeforeExecute);
    // Potentially restore _drawingState.currentTool to _currentToolBeforeExecute if it was changed
    // by the context that called this command's execution.
    // For instance, if calling setCurrentTool(polygon) then startNewDrawingPart(polygon),
    // undo should perhaps revert currentTool as well.
    // This depends on how setCurrentTool interacts with startNewDrawingPart.
    // DrawingState.startNewDrawingPart mainly affects _activeMultiPartTool and _currentDrawingParts.
  }

  @override
  String get description => 'Start new drawing part with tool: ${_toolToStart.name}';
}
