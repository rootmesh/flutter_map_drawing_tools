import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map_drawing_tools/src/models/drawing_tool.dart';
import 'package:flutter_map_drawing_tools/src/models/shape_data_models.dart';
import 'package:flutter_map_drawing_tools/src/models/dimension_display_model.dart';

class NumericalRescaleInputSheet extends StatefulWidget {
  final DimensionDisplayModel dimensionModel;
  final ShapeData shapeData; // To determine which fields to show
  final Function(Map<String, double> newDimensions) onApply;
  final VoidCallback? onClose;

  const NumericalRescaleInputSheet({
    super.key,
    required this.dimensionModel,
    required this.shapeData,
    required this.onApply,
    this.onClose,
  });

  @override
  State<NumericalRescaleInputSheet> createState() => _NumericalRescaleInputSheetState();
}

class _NumericalRescaleInputSheetState extends State<NumericalRescaleInputSheet> {
  late TextEditingController _radiusController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;

  bool _isCircle = false;
  bool _isRectangle = false; // Assuming a way to identify rectangles

  @override
  void initState() {
    super.initState();

    _isCircle = widget.shapeData is CircleShapeData;
    // Placeholder: In a real scenario, rectangles might have their own ShapeData type
    // or PolygonShapeData would have metadata. For now, assume a simple polygon is a rectangle.
    _isRectangle = widget.shapeData is PolygonShapeData && (widget.shapeData as PolygonShapeData).polygon.points.length == 5;


    _radiusController = TextEditingController(text: _formatDimension(widget.dimensionModel.radius));
    _widthController = TextEditingController(text: _formatDimension(widget.dimensionModel.width));
    _heightController = TextEditingController(text: _formatDimension(widget.dimensionModel.height));

    widget.dimensionModel.addListener(_updateTextControllers);
  }

  @override
  void dispose() {
    widget.dimensionModel.removeListener(_updateTextControllers);
    _radiusController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _updateTextControllers() {
    if (!mounted) return;
    // Only update if the text field doesn't have focus, to avoid disrupting user input.
    // This is a basic check; more sophisticated focus handling might be needed.
    if (!FocusScope.of(context).hasFocus) {
      if (_isCircle) {
        _radiusController.text = _formatDimension(widget.dimensionModel.radius);
      }
      if (_isRectangle) {
        _widthController.text = _formatDimension(widget.dimensionModel.width);
        _heightController.text = _formatDimension(widget.dimensionModel.height);
      }
    }
  }

  String _formatDimension(double? value) {
    if (value == null) return '';
    // Format to a reasonable number of decimal places, e.g., 2
    return value.toStringAsFixed(2);
  }

  void _handleApply() {
    Map<String, double> newDimensions = {};
    if (_isCircle) {
      final radius = double.tryParse(_radiusController.text);
      if (radius != null && radius > 0) {
        newDimensions['radius'] = radius;
      }
    }
    if (_isRectangle) {
      final width = double.tryParse(_widthController.text);
      if (width != null && width > 0) {
        newDimensions['width'] = width;
      }
      final height = double.tryParse(_heightController.text);
      if (height != null && height > 0) {
        newDimensions['height'] = height;
      }
    }

    if (newDimensions.isNotEmpty) {
      widget.onApply(newDimensions);
    }
    if (widget.onClose != null) {
       widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> fields = [];

    if (_isCircle) {
      fields.add(
        _DimensionTextField(
          controller: _radiusController,
          label: 'Radius (meters)',
        ),
      );
    }

    if (_isRectangle) {
      fields.add(
        _DimensionTextField(
          controller: _widthController,
          label: 'Width (meters)', // Assuming meters for now
        ),
      );
      fields.add(
        _DimensionTextField(
          controller: _heightController,
          label: 'Height (meters)', // Assuming meters for now
        ),
      );
    }
    
    if (fields.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Numerical input not available for this shape type.'),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit Dimensions',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ...fields,
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleApply,
            child: const Text('Apply'),
          ),
          TextButton(
            onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }
}

class _DimensionTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _DimensionTextField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
      ),
    );
  }
}
