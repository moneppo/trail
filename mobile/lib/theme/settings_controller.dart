import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which unit distances are shown in.
enum DistanceUnit { km, mi }

/// Set once in main() before the app starts.
late final SettingsController settings;

/// The person's settings: light, dark or follow-the-device appearance, and
/// kilometers or miles. Remembered between launches.
class SettingsController extends ChangeNotifier {
  static const _themeKey = 'trail-theme';
  static const _unitsKey = 'trail-units';

  ThemeMode _mode;
  DistanceUnit _units;
  final SharedPreferences? _prefs;

  SettingsController._(this._mode, this._units, this._prefs);

  static Future<SettingsController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = switch (prefs.getString(_themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      final units = prefs.getString(_unitsKey) == 'mi'
          ? DistanceUnit.mi
          : DistanceUnit.km;
      return SettingsController._(mode, units, prefs);
    } catch (_) {
      // Storage unavailable: start on the defaults and don't persist.
      return SettingsController._(ThemeMode.system, DistanceUnit.km, null);
    }
  }

  ThemeMode get mode => _mode;
  DistanceUnit get units => _units;

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _prefs?.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  void setUnits(DistanceUnit units) {
    if (units == _units) return;
    _units = units;
    _prefs?.setString(_unitsKey, units.name);
    notifyListeners();
  }
}
