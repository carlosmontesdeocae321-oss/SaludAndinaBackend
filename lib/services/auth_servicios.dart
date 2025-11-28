import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Allow overriding baseUrl at build/run time with --dart-define=BASE_URL
  static const String baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'http://127.0.0.1:3000');

  static Future<bool> login(String usuario, String clave) async {
    final url = Uri.parse('$baseUrl/api/usuarios/login');

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usuario': usuario, 'clave': clave}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data['id'] == null || data['rol'] == null) {
          print(
              "❌ Error: respuesta incompleta del backend (id o rol faltante)");
          return false;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', data['id'].toString());
        await prefs.setString('rol', data['rol']);
        // clinicaId puede ser null para doctores individuales -> guardar cadena vacía
        final clinicaId = data['clinicaId'];
        await prefs.setString(
            'clinicaId', clinicaId == null ? '' : clinicaId.toString());
        await prefs.setString('usuario', usuario);
        await prefs.setString('clave', clave);

        print("✅ Usuario logueado, almacenado en SharedPreferences");

        return true;
      }

      print("❌ Error en login: ${res.statusCode} -> ${res.body}");
      return false;
    } catch (e) {
      print("❌ Error en login (excepción): $e");
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
