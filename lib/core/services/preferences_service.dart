import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _currencyKey = 'currency_symbol';
  static const _ocrModeKey = 'ocr_mode';

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
}
