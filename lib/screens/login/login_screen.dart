import 'package:flutter/material.dart';
// usar imagen PNG para el logo
import '../../services/auth_servicios.dart';
import '../menu/menu_principal_screen.dart';
import '../inicio_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usuarioCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool cargando = false;

  Future<void> login() async {
    setState(() => cargando = true);
    final ok = await AuthService.login(usuarioCtrl.text, passwordCtrl.text);
    setState(() => cargando = false);

    if (ok) {
      // Navigate to main menu for all roles (admin dashboard removed)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MenuPrincipalScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Usuario o contraseña incorrectos")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEFFAF9), Color(0xFFDFF6F2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/logo.png',
                          width: 110, height: 110),
                      const SizedBox(height: 12),
                      Text('Bienvenido a Clinica App',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 20),
                      TextField(
                        controller: usuarioCtrl,
                        decoration: InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: cargando ? null : login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: cargando
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Ingresar',
                                  style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              // Placeholder: implementar recuperación
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Función de recuperación no implementada')));
                            },
                            child: const Text('¿Olvidó su contraseña?'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const InicioScreen())),
                            child: const Text('Volver'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
