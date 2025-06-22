import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveFcmToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('fcm_token', token);
}

Future<String?> getFcmToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('fcm_token');
}
