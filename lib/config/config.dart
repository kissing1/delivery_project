import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class Configuration {
  static Future<Map<String, dynamic>> getConfig() async {
    final txt = await rootBundle.loadString('assets/config/config.json');
    return jsonDecode(txt) as Map<String, dynamic>;
  }
}
