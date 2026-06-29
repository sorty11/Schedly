import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const String _themePrefKey = 'theme_preference';
  
  late ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

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
}
