import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _currencyKey = 'currency_symbol';

  static const supportedSymbols = ['\$', 'Rp', '€', '£', '¥'];

  Future<String> getCurrencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyKey) ?? '\$';
  }

  Future<void> setCurrencySymbol(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, symbol);
  }
}
