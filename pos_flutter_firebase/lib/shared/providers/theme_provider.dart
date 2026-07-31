import 'package:flutter/material.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setDark(bool dark) {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

enum FontSizeLevel { small, medium, large }

class FontSizeNotifier extends ChangeNotifier {
  FontSizeLevel _level = FontSizeLevel.medium;
  FontSizeLevel get level => _level;

  double get textScaleFactor {
    switch (_level) {
      case FontSizeLevel.small:
        return 0.85;
      case FontSizeLevel.medium:
        return 1.0;
      case FontSizeLevel.large:
        return 1.2;
    }
  }

  void setLevel(FontSizeLevel level) {
    _level = level;
    notifyListeners();
  }
}
