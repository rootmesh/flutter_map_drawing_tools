import 'package:flutter/material.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart'; 
import 'package:provider/provider.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_state.dart';

/// {@template drawing_tool_callback}
/// Callback signature for when a drawing tool is selected from the toolbar.
///
/// - `tool`: The [DrawingTool] that was selected.
/// {@endtemplate}
typedef DrawingToolCallback = void Function(DrawingTool tool);

/// {@template drawing_toolbar}
/// A floating action button (FAB) based toolbar for selecting drawing tools and actions.
///
/// Displays a main FAB that expands to show available drawing tools like polygon,
/// polyline, circle, point, etc., as well as actions like "Complete Part" and
/// "Finalize Multi-Part Drawing" when in a multi-part drawing context.
///
/// It interacts with [DrawingState] (typically via `Provider`) to determine
/// which buttons to show based on the current drawing progress (e.g., multi-part drawing).
/// The actual tool activation and state changes are handled by the `onToolSelected` callback,
/// which should update the [DrawingState].
/// {@endtemplate}
class DrawingToolbar extends StatefulWidget {
  /// {@macro drawing_toolbar}
  const DrawingToolbar({
    super.key,
    required this.onToolSelected,
    this.activeTool = DrawingTool.none,
    this.availableTools = const [
      DrawingTool.polygon,
      DrawingTool.multiPolyline, 
      DrawingTool.multiPolygon,  
      DrawingTool.rectangle,
      DrawingTool.pentagon,
      DrawingTool.hexagon,
      DrawingTool.octagon,
      DrawingTool.circle,
      DrawingTool.point,
      DrawingTool.edit,
      DrawingTool.delete,
      // Undo and Redo are not general "available tools" but fixed actions.
      // They will be added separately if canUndo/canRedo is true.
    ],
    this.canUndo = false,
    this.canRedo = false,
  });

  /// {@macro drawing_tool_callback}
  /// Called when a tool or action button is tapped.
  final DrawingToolCallback onToolSelected;

  /// The currently active drawing tool, as determined by the host application.
  /// This is used to visually highlight the active tool button in the toolbar.
  /// Defaults to [DrawingTool.none].
  final DrawingTool activeTool;
  
  /// Flag indicating if an undo operation is currently possible.
  final bool canUndo;

  /// Flag indicating if a redo operation is currently possible.
  final bool canRedo;

  /// A list of [DrawingTool]s that should be available in the toolbar.
  /// This allows customization of which drawing tools are presented to the user.
  /// Tools related to multi-part drawing ([DrawingTool.completePart], [DrawingTool.finalizeMultiPart])
  /// and cancellation ([DrawingTool.cancel]) are handled internally based on context
  /// and do not need to be included in this list.
  final List<DrawingTool> availableTools;

  @override
  State<DrawingToolbar> createState() => _DrawingToolbarState();
}

class _DrawingToolbarState extends State<DrawingToolbar> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  
  // Defines the default icons for each drawing tool and action.
  static final Map<DrawingTool, IconData> _defaultToolIcons = {
    DrawingTool.polygon: Icons.timeline,
    DrawingTool.multiPolyline: Icons.line_axis, 
    DrawingTool.multiPolygon: Icons.layers_outlined, 
    DrawingTool.rectangle: Icons.crop_square,
    DrawingTool.pentagon: Icons.pentagon_outlined,
    DrawingTool.hexagon: Icons.hexagon_outlined,
    DrawingTool.octagon: Icons.stop_outlined, 
    DrawingTool.circle: Icons.circle_outlined,
    DrawingTool.point: Icons.location_on_outlined,
    DrawingTool.edit: Icons.edit_outlined,
    DrawingTool.delete: Icons.delete_outlined,
    DrawingTool.cancel: Icons.close,
    DrawingTool.none: Icons.draw,
    DrawingTool.completePart: Icons.add_path_outlined,
    DrawingTool.finalizeMultiPart: Icons.done_all,
    DrawingTool.undo: Icons.undo,
    DrawingTool.redo: Icons.redo,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350), 
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Toggles the expansion state of the toolbar.
  // Handles canceling active single-gesture tools if applicable.
  void _toggleExpand() {
    final drawingState = Provider.of<DrawingState>(context, listen: false);
    DrawingTool currentInternalTool = drawingState.currentTool;
    bool isMultiPartActive = drawingState.isMultiPartDrawingInProgress;

    if (currentInternalTool != DrawingTool.none && !isMultiPartActive && currentInternalTool != DrawingTool.edit && !_isExpanded) {
        widget.onToolSelected(DrawingTool.cancel); 
    } else if (isMultiPartActive && !_isExpanded) {
        setState(() { _isExpanded = !_isExpanded; if (_isExpanded) _animationController.forward(); else _animationController.reverse(); });
    }
    else {
      setState(() {
        _isExpanded = !_isExpanded;
        if (_isExpanded) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      });
    }
  }

  // Builds the main FloatingActionButton.
  // Its icon and tooltip change based on the current drawing state.
  Widget _buildMainFab() {
    final drawingState = Provider.of<DrawingState>(context, listen: true); 
    DrawingTool toolForIcon = drawingState.currentTool;
    if (drawingState.isMultiPartDrawingInProgress && drawingState.activeMultiPartTool != null) {
        toolForIcon = drawingState.activeMultiPartTool!;
    } else if (drawingState.selectedShapeId != null && drawingState.currentTool == DrawingTool.edit) {
        toolForIcon = DrawingTool.edit;
    }

    IconData currentIcon = _defaultToolIcons[toolForIcon] ?? _defaultToolIcons[DrawingTool.none]!;
    String tooltip = _isExpanded 
        ? 'Close Tools' 
        : (toolForIcon == DrawingTool.none 
            ? 'Open Drawing Tools' 
            : 'Cancel ${drawingToolDisplayName(toolForIcon)}');
    
    if (drawingState.isMultiPartDrawingInProgress && !_isExpanded) {
        tooltip = 'Open Tools / Manage Multi-Part Drawing';
    }

    return FloatingActionButton(
      onPressed: _toggleExpand,
      tooltip: tooltip,
      child: Icon(currentIcon),
    );
  }

  // Builds the list of secondary tool/action buttons when the toolbar is expanded.
  // Buttons are shown based on context (e.g., multi-part drawing status).
  List<Widget> _buildToolButtons() {
    List<Widget> buttons = [];
    final drawingState = Provider.of<DrawingState>(context, listen: true);

    // Add Undo button if available
    if (widget.canUndo) {
      buttons.add(_buildActionButton(DrawingTool.undo, _defaultToolIcons[DrawingTool.undo]!, 'Undo', null, _animationController));
    }
    // Add Redo button if available
    if (widget.canRedo) {
      buttons.add(_buildActionButton(DrawingTool.redo, _defaultToolIcons[DrawingTool.redo]!, 'Redo', null, _animationController));
    }


    if (drawingState.isMultiPartDrawingInProgress) {
        final currentPartPoints = drawingState.currentDrawingParts.isNotEmpty ? drawingState.currentDrawingParts.last.length : 0;
        bool canCompletePart = false;
        if (drawingState.activeMultiPartTool == DrawingTool.polygon) {
            canCompletePart = currentPartPoints >= 1; 
        } else if (drawingState.activeMultiPartTool == DrawingTool.polyline) {
            canCompletePart = currentPartPoints >= 1; 
        }

        if (canCompletePart) {
          buttons.add(_buildActionButton(
            DrawingTool.completePart, 
            _defaultToolIcons[DrawingTool.completePart]!, 
            drawingToolDisplayName(DrawingTool.completePart), 
            null,
            _animationController
          ));
        }

        if (drawingState.currentDrawingParts.any((part) => part.isNotEmpty)) {
           buttons.add(_buildActionButton(
            DrawingTool.finalizeMultiPart, 
            _defaultToolIcons[DrawingTool.finalizeMultiPart]!, 
            drawingToolDisplayName(DrawingTool.finalizeMultiPart), 
            Colors.green,
            _animationController
          ));
        }
    }

    if (!drawingState.isMultiPartDrawingInProgress) { 
        final toolsToShow = widget.availableTools.where((tool) => 
            tool != DrawingTool.none && tool != DrawingTool.cancel && 
            tool != DrawingTool.undo && tool != DrawingTool.redo && // Exclude undo/redo from this list
            _defaultToolIcons.containsKey(tool)
        ).toList();

        for (int i = 0; i < toolsToShow.length; i++) {
          DrawingTool tool = toolsToShow[i];
          buttons.add(_buildActionButton(
            tool, 
            _defaultToolIcons[tool]!, 
            drawingToolDisplayName(tool), 
            widget.activeTool == tool ? Theme.of(context).primaryColorLight : null,
            _animationController,
            index: i,
            total: toolsToShow.length
          ));
        }
    }
    
    bool anyToolActive = drawingState.currentTool != DrawingTool.none || drawingState.selectedShapeId != null || drawingState.isMultiPartDrawingInProgress;
    if (anyToolActive) { 
        buttons.add(_buildActionButton(
          DrawingTool.cancel, 
          _defaultToolIcons[DrawingTool.cancel]!, 
          drawingToolDisplayName(DrawingTool.cancel), 
          Colors.redAccent,
          _animationController
        ));
    }
    return buttons;
  }

  Widget _buildActionButton(DrawingTool tool, IconData icon, String tooltip, Color? backgroundColor, Animation<double> animation, {int index = 0, int total = 1}) {
    // Determine if the button should be enabled based on canUndo/canRedo for those specific tools
    VoidCallback? onPressedAction = () { if(_isExpanded) _toggleExpand(); widget.onToolSelected(tool); };
    if (tool == DrawingTool.undo && !widget.canUndo) {
      onPressedAction = null;
    }
    if (tool == DrawingTool.redo && !widget.canRedo) {
      onPressedAction = null;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Interval(0.1 * index / total, 0.5 + 0.5 * index / total, curve: Curves.easeOutCubic),
        ),
        child: FloatingActionButton.small(
          heroTag: 'fab_tool_${tool.name}',
          onPressed: onPressedAction,
          tooltip: tooltip,
          backgroundColor: backgroundColor,
          child: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        AnimatedBuilder(
          animation: _animationController, 
          builder: (context, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic),
              child: SizeTransition(
                sizeFactor: CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic),
                axisAlignment: -1.0, 
                child: child,
              ),
            );
          },
          child: Column( 
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _buildToolButtons(),
          ),
        ),
        _buildMainFab(),
      ],
    );
  }
}

// Internal helper widget for toolbar buttons, not part of public API.
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
