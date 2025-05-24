import 'package:flutter/material.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart'; 
import 'package:provider/provider.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';

/// {@template contextual_editing_toolbar}
/// A toolbar that appears near a selected shape, providing editing actions.
///
/// This toolbar displays buttons for operations like moving, rotating, rescaling,
/// deleting, confirming, or canceling edits for the currently selected shape.
/// The visibility of certain buttons (e.g., rotate, rescale) depends on the
/// type of the selected shape, determined by [DrawingState.selectedShapeType].
///
/// It typically relies on `Provider.of<DrawingState>(context)` to access the
/// current selection and editing state. Callbacks for actions are provided by
/// the parent widget (usually [DrawingLayer]).
/// {@endtemplate}
class ContextualEditingToolbar extends StatelessWidget {
  /// {@macro contextual_editing_toolbar}
  const ContextualEditingToolbar({
    super.key,
    this.onMove,
    this.onRotate, 
    this.onRescale, 
    this.onDelete,
    this.onConfirm, 
    this.onCancel,  
  });

  /// Callback invoked when the "Move" button is pressed.
  /// Should typically toggle [EditMode.moving] in [DrawingState].
  final VoidCallback? onMove;

  /// Callback invoked when the "Rotate" button is pressed.
  /// Should typically toggle [EditMode.rotating] in [DrawingState].
  final VoidCallback? onRotate; 
  
  /// Callback invoked when the "Rescale" button is pressed.
  /// Should typically toggle [EditMode.scaling] in [DrawingState].
  final VoidCallback? onRescale; 
  
  /// Callback invoked when the "Delete" button is pressed.
  /// Should handle the deletion of the selected shape.
  final VoidCallback? onDelete;
  
  /// Callback invoked when the "Confirm Edits" button is pressed.
  /// Should finalize any ongoing edits and typically deselect the shape.
  final VoidCallback? onConfirm; 
  
  /// Callback invoked when the "Cancel Edits" button is pressed.
  /// Should discard any ongoing edits and typically deselect the shape.
  final VoidCallback? onCancel;  

  @override
  Widget build(BuildContext context) {
    final drawingState = Provider.of<DrawingState>(context, listen: true); 
    final selectedShapeId = drawingState.selectedShapeId;
    final selectedShapeType = drawingState.selectedShapeType;
    final activeEditMode = drawingState.activeEditMode;

    if (selectedShapeId == null || selectedShapeType == null) {
       return const SizedBox.shrink(); // Hide if no shape is selected
    }

    List<Widget> buttons = [];

    // Move Button
    buttons.add(_ToolbarButton(
      icon: Icons.open_with, 
      tooltip: "Move", 
      isSelected: activeEditMode == EditMode.moving,
      onPressed: onMove 
    ));

    // Rotate Button (conditional display)
    if (selectedShapeType == DrawingTool.polygon ||
        selectedShapeType == DrawingTool.rectangle || 
        selectedShapeType == DrawingTool.pentagon ||
        selectedShapeType == DrawingTool.hexagon ||
        selectedShapeType == DrawingTool.octagon ||
        selectedShapeType == DrawingTool.circle) { 
      buttons.add(_ToolbarButton(
        icon: Icons.rotate_right, 
        tooltip: "Rotate", 
        isSelected: activeEditMode == EditMode.rotating,
        onPressed: onRotate 
      ));
    }
    
    // Rescale Button (conditional display)
    if (selectedShapeType == DrawingTool.rectangle || 
        selectedShapeType == DrawingTool.polygon || // Generic polygons might be selected
        selectedShapeType == DrawingTool.pentagon || // These are specific types of polygons
        selectedShapeType == DrawingTool.hexagon ||
        selectedShapeType == DrawingTool.octagon ||
        selectedShapeType == DrawingTool.circle) {
         buttons.add(_ToolbarButton(
          icon: Icons.aspect_ratio, 
          tooltip: "Rescale", 
          isSelected: activeEditMode == EditMode.scaling,
          onPressed: onRescale 
        ));
    }

    // Delete Button
    buttons.add(_ToolbarButton(icon: Icons.delete_outline, tooltip: "Delete", onPressed: onDelete, color: Colors.redAccent));
    
    // Confirm Button
    buttons.add(_ToolbarButton(
      icon: Icons.check, 
      tooltip: "Confirm Edits", 
      onPressed: onConfirm, 
      color: Colors.green)
    );

    // Cancel Button
    buttons.add(_ToolbarButton(
      icon: Icons.close, 
      tooltip: "Cancel Edits", 
      onPressed: onCancel
    ));


    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Wrap( 
          spacing: 4.0,
          runSpacing: 0.0, 
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: buttons,
        ),
      ),
    );
  }
}

// Internal helper widget for toolbar buttons.
// Not part of the public API, so detailed Dartdoc is not strictly required by the subtask.
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color; 
  final bool isSelected; 

  const _ToolbarButton({
    required this.icon, 
    required this.tooltip, 
    this.onPressed, 
    this.color,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal( 
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: isSelected, 
      iconSize: 20,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(), 
      style: isSelected 
          ? IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primaryContainer) 
          : null,
    );
  }
}
