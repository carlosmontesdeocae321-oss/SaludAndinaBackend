import 'package:flutter/material.dart';
import '../../services/api_services.dart';
import '../../refresh_notifier.dart';

class CrearUsuarioScreen extends StatefulWidget {
  final int clinicaId;
  const CrearUsuarioScreen({super.key, required this.clinicaId});

  @override
  State<CrearUsuarioScreen> createState() => _CrearUsuarioScreenState();
}

class _CrearUsuarioScreenState extends State<CrearUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  String nombre = '';
  String password = '';
  late int clinicaId;
  // Rol fijo: doctor
  final String rol = 'doctor';
  String error = '';
  bool cargando = false;

  @override
  void initState() {
    super.initState();
    clinicaId = widget.clinicaId;
  }

  Future<void> guardarUsuario() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => cargando = true);
    // Verificar disponibilidad del nombre
    final disponible = await ApiService.verificarUsuarioDisponible(nombre);
    if (!disponible) {
      setState(() => cargando = false);
      setState(() => error = 'El nombre de usuario ya está en uso');
      return;
    }

    final res = await ApiService.crearUsuarioClinica(
      usuario: nombre,
      clave: password,
      rol: rol,
      clinicaId: clinicaId,
    );
    setState(() {
      cargando = false;
    });
    if ((res['ok'] ?? false) == true) {
      // notify global listeners
      globalRefreshNotifier.value = globalRefreshNotifier.value + 1;
      Navigator.pop(context, true);
    } else {
      final err = res['error']?.toString() ?? 'Error al crear el usuario';
      // Si el servidor indica que el límite fue alcanzado, ofrecer compra de slot ($5)
      if (err.toLowerCase().contains('límite') ||
          err.toLowerCase().contains('limite')) {
        final aceptar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Límite alcanzado'),
            content: const Text(
                'El límite de doctores para su plan fue alcanzado. Comprar un espacio extra por \$5?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('No')),
              ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Comprar')),
            ],
          ),
        );
        if (aceptar == true) {
          // Simular pago antes de realizar la compra real
          final paid = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Simulación de pago'),
              content: const Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Simular pago de \$5 por espacio extra de doctor')
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Simular pago exitoso')),
              ],
            ),
          );
          if (paid != true) return;

          setState(() => cargando = true);
          final compra = await ApiService.comprarDoctorExtra(
            clinicaId: clinicaId,
            usuario: nombre,
            clave: password,
          );
          setState(() => cargando = false);
          if ((compra['ok'] ?? false) == true) {
            Navigator.pop(context, true);
            return;
          } else {
            setState(() => error =
                compra['error']?.toString() ?? 'Error al comprar espacio');
            return;
          }
        }
      }
      setState(() {
        error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Doctor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nombre'),
                onChanged: (v) => nombre = v,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese el nombre' : null,
              ),
              // No se pide email: no necesario para creación de doctor en la clínica
              TextFormField(
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                onChanged: (v) => password = v,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese la contraseña' : null,
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 24),
              if (error.isNotEmpty)
                Text(error, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: cargando ? null : guardarUsuario,
                child: cargando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
