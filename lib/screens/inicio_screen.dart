import 'package:flutter/material.dart';
// svg import removed (no central logo in InicioScreen)
import 'paciente/ingreso_paciente_screen.dart';
import 'login/login_screen.dart';
import '../widgets/app_drawer.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C2C),
        elevation: 0,
        title: const Text('Inicio'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/promociones');
            },
            child: const Text(
              'Ver promociones',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F1C2C), Color(0xFF1A2A44)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mostrar el logo principal centrado
                Image.asset(
                  'assets/images/logo.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const IngresoPacienteScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 14)),
                  child: const Text("Paciente"),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 14)),
                  child: const Text("Clínica"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
