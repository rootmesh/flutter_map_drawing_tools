import 'package:flutter/foundation.dart';
import 'commands.dart';

class UndoRedoManager extends ChangeNotifier {
  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void executeCommand(Command command) {
    command.execute();
    _undoStack.add(command);
    _redoStack.clear(); // Clear redo stack whenever a new command is executed
    notifyListeners();
    debugPrint("Executed: ${command.description}, Undo available: $canUndo, Redo available: $canRedo");
  }

  void undo() {
    if (canUndo) {
      final command = _undoStack.removeLast();
      command.undo();
      _redoStack.add(command);
      notifyListeners();
      debugPrint("Undone: ${command.description}, Undo available: $canUndo, Redo available: $canRedo");
    }
  }

  void redo() {
    if (canRedo) {
      final command = _redoStack.removeLast();
      command.execute();
      _undoStack.add(command);
      notifyListeners();
      debugPrint("Redone: ${command.description}, Undo available: $canUndo, Redo available: $canRedo");
    }
  }

  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
    debugPrint("Undo/Redo history cleared.");
  }
}
