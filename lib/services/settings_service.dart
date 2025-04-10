import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  
  factory SettingsService() => _instance;
  
  SettingsService._internal();
  
  // Cache the preferences for better performance
  SharedPreferences? _prefs;
  bool? _is10SecWarningEnabled;
  
  // Keys for preferences
  static const String _key10SecWarning = 'is_10sec_warning_enabled';
  
  // Initialize the service - call this early in app startup
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _is10SecWarningEnabled = _prefs?.getBool(_key10SecWarning) ?? true; // Default to true
  }
  
  // Get the current state of 10-second warning
  bool get is10SecWarningEnabled {
    return _is10SecWarningEnabled ?? true;
  }
  
  // Toggle the 10-second warning and save to shared preferences
  Future<void> toggle10SecWarning() async {
    _is10SecWarningEnabled = !(_is10SecWarningEnabled ?? true);
    await _prefs?.setBool(_key10SecWarning, _is10SecWarningEnabled!);
  }
  
  // Set the 10-second warning state explicitly
  Future<void> set10SecWarning(bool value) async {
    _is10SecWarningEnabled = value;
    await _prefs?.setBool(_key10SecWarning, value);
  }
} 