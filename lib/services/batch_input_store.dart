import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the pasted list of sites between runs.
class BatchInputStore {
  static const key = 'batch_urls';

  Future<String> load() async {
    try {
      return (await SharedPreferences.getInstance()).getString(key) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> save(String text) async {
    try {
      await (await SharedPreferences.getInstance()).setString(key, text);
    } catch (_) {
      // Not remembering the list is not worth an error.
    }
  }
}
