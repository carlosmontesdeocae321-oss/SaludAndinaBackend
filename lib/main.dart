import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/inicio_screen.dart';
import 'screens/admin/promociones_screen.dart';
import 'route_observer.dart';

void main() => runApp(const ClinicaApp());

class ClinicaApp extends StatelessWidget {
  const ClinicaApp({super.key});

  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final usuario = prefs.getString('usuario') ?? '';
    final clave = prefs.getString('clave') ?? '';
    return usuario.isNotEmpty && clave.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SaludAndina',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF006D5B),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal)
            .copyWith(secondary: const Color(0xFF06B6D4)),
      ),
      home: const InicioScreen(),
      navigatorObservers: [routeObserver],
      // Añadir un logo centrado en el AppBar para usuarios autenticados
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            // Top-center logo visible sólo si hay sesión
            FutureBuilder<bool>(
              future: _isLoggedIn(),
              builder: (context, snap) {
                final logged = snap.data == true;
                if (!logged) return const SizedBox.shrink();
                return SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Image.asset('assets/images/logo.png',
                            fit: BoxFit.contain),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
      routes: {
        '/promociones': (context) => PromocionesScreen(),
      },
    );
  }
}
