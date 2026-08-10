import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _currencyKey = 'currency_symbol';
  static const _ocrModeKey = 'ocr_mode';
  static const _themeKey = 'theme_mode';
  static const _showOcrDebugKey = 'show_ocr_debug';

  static const supportedSymbols = ['\$', 'Rp', '€', '£', '¥'];
  static const ocrModes = ['auto', 'gemini', 'ocrspace'];

  Future<String> getCurrencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyKey) ?? '\$';
  }

  Future<void> setCurrencySymbol(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, symbol);
  }

  Future<String> getOcrMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ocrModeKey) ?? 'auto';
  }

  Future<void> setOcrMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ocrModeKey, mode);
  }

  Future<String> getThemeModePref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  Future<void> setThemeModePref(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  Future<bool> getShowOcrDebug() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showOcrDebugKey) ?? false;
  }

  Future<void> setShowOcrDebug(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showOcrDebugKey, value);
  }
}
