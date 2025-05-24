import 'package:flutter/foundation.dart';

class DimensionDisplayModel extends ChangeNotifier {
  double? _width;
  double? _height;
  double? _radius;

  double? get width => _width;
  double? get height => _height;
  double? get radius => _radius;

  void updateDimensions({double? width, double? height, double? radius, bool notify = true}) {
    bool changed = false;
    if (width != null && _width != width) {
      _width = width;
      changed = true;
    }
    if (height != null && _height != height) {
      _height = height;
      changed = true;
    }
    if (radius != null && _radius != radius) {
      _radius = radius;
      changed = true;
    }

    if (changed && notify) {
      notifyListeners();
    }
  }

  void clear({bool notify = true}) {
    _width = null;
    _height = null;
    _radius = null;
    if (notify) {
      notifyListeners();
    }
  }
}
