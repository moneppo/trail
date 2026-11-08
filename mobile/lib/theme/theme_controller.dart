import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Set once in main() before the app starts.
late final ThemeController themeController;

/// The chosen appearance: light, dark, or following the device. Remembered
/// between launches.
class ThemeController extends ChangeNotifier {
  static const _key = 'trail-theme';

  ThemeMode _mode;
  final SharedPreferences? _prefs;

  ThemeController._(this._mode, this._prefs);

  static Future<ThemeController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = switch (prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      return ThemeController._(mode, prefs);
    } catch (_) {
      // Storage unavailable: start on the device setting and don't persist.
      return ThemeController._(ThemeMode.system, null);
    }
  }

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _prefs?.setString(_key, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }
}
