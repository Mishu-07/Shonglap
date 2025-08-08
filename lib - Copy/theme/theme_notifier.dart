import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  final String key = "theme_color";
  SharedPreferences? _prefs;
  late Color _primaryColor;

  Color get primaryColor => _primaryColor;

  ThemeNotifier() {
    // This is the default color of the app.
    _primaryColor = const Color(0xFF4A3AFF);
    _loadFromPrefs();
  }

  _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  _loadFromPrefs() async {
    await _initPrefs();
    // Get the saved color value, or null if it's the first time.
    int? colorValue = _prefs!.getInt(key);
    if (colorValue != null) {
      _primaryColor = Color(colorValue);
    }
    // Notify listeners to rebuild the UI with the loaded color.
    notifyListeners();
  }

  _saveToPrefs(int colorValue) async {
    await _initPrefs();
    _prefs!.setInt(key, colorValue);
  }

  /// Sets a new primary color for the app theme.
  void setPrimaryColor(Color color) {
    _primaryColor = color;
    _saveToPrefs(color.value);
    notifyListeners();
  }
}
