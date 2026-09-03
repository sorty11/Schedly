import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'visual_theme.dart';

class ThemeController extends ChangeNotifier {
  static const String _themePrefKey = 'theme_preference';
  static const String _visualThemePrefKey = 'visual_theme_preference';

  late ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  late SchedlyVisualTheme _visualTheme;
  SchedlyVisualTheme get visualTheme => _visualTheme;

  final SharedPreferences prefs;

  ThemeController(this.prefs) {
    _loadTheme();
  }

  void _loadTheme() {
    final savedTheme = prefs.getString(_themePrefKey);

    if (savedTheme != null) {
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    } else {
      _themeMode = ThemeMode.system;
    }

    final savedVisualTheme = prefs.getString(_visualThemePrefKey);
    _visualTheme = SchedlyVisualTheme.fromId(savedVisualTheme);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    String saveVal = 'system';
    if (mode == ThemeMode.light) saveVal = 'light';
    if (mode == ThemeMode.dark) saveVal = 'dark';

    await prefs.setString(_themePrefKey, saveVal);
  }

  Future<void> setVisualTheme(SchedlyVisualTheme theme) async {
    if (_visualTheme == theme) return;

    _visualTheme = theme;
    notifyListeners();

    await prefs.setString(_visualThemePrefKey, theme.id);
  }
}
