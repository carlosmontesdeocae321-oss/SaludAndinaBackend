import 'package:flutter/material.dart';
import '../../services/api_services.dart';
import '../../refresh_notifier.dart';

class PromocionesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> promociones = [
    {
      'titulo': 'Doctor Individual (Freemium)',
      'precio': 'Gratis',
      'detalles': [
        'Hasta 20 pacientes y 1 doctor',
        'Paciente extra: \$1 (pago único)',
        'Todas las funciones disponibles excepto soporte premium',
      ],
    },
    {
      'titulo': 'Clínica Pequeña',
      'precio': '\$20/mes',
      'detalles': [
        '165 pacientes y 2 doctores',
        'Paciente extra: \$1 (pago único)',
        'Doctor extra: \$5 (pago único)',
        'Todas las funciones disponibles',
      ],
    },
    {
      'titulo': 'Clínica Mediana',
      'precio': '\$40/mes',
      'detalles': [
        '300 pacientes y 5 doctores',
        'Paciente extra: \$1 (pago único)',
        'Doctor extra: \$5 (pago único)',
        'Todas las funciones disponibles',
      ],
    },
    {
      'titulo': 'Clínica Grande',
      'precio': '\$100/mes',
      'detalles': [
        'Pacientes y doctores ilimitados',
        'Todas las funciones y soporte premium',
      ],
    },
    {
      'titulo': 'Combo VIP Multi-Sucursal',
      'precio': '\$150/mes',
      'detalles': [
        'Incluye 2 clínicas vinculadas (sucursales)',
        'Pacientes compartidos entre sucursales',
        'Agregar más sucursales por \$50 cada una (solo con Combo VIP)',
        'Pacientes y doctores ilimitados',
        'Prioridad en soporte',
        'Todas las funciones sin límites',
      ],
    },
  ];

  PromocionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promociones y Combos')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: promociones.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
          final promo = promociones[i];
          return Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_offer,
                          color: Colors.orange, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          promo['titulo'] ?? '',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        promo['precio'] ?? '',
                        style: const TextStyle(
                            fontSize: 18,
                            color: Colors.green,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...List<Widget>.from(
                      (promo['detalles'] as List).map((d) => Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.blue, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(d,
                                      style: const TextStyle(fontSize: 16))),
                            ],
                          ))),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text('Contratar'),
                          onPressed: () async {
                            if (promo['titulo'] ==
                                'Doctor Individual (Freemium)') {
                              await showDialog(
                                context: context,
                                builder: (ctx) => _DoctorIndividualDialog(),
                              );
                            } else {
                              // Iniciar compra (mock) usando ApiService
                              final titulo = promo['titulo'] as String;
                              final precioRaw = promo['precio'] as String;
                              // Extraer número si existe, ejemplo: "\$20/mes" -> 20.0
                              double monto = 0.0;
                              final regex = RegExp(r"\d+(?:\.\d+)?");
                              final m = regex.firstMatch(precioRaw);
                              if (m != null) {
                                monto =
                                    double.tryParse(m.group(0) ?? '0') ?? 0.0;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Iniciando compra...')),
                              );

                              final res = await ApiService.comprarPromocion(
                                  titulo: titulo, monto: monto);
                              if (res['ok']) {
                                final data = res['data'];
                                final paymentUrl = data['payment_url'];
                                final compraId = data['compraId'].toString();

                                // Mostrar diálogo con opción para simular pago
                                final paid = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => _MockPagoDialog(
                                        paymentUrl: paymentUrl,
                                        compraId: compraId));

                                // Si el pago fue exitoso y la promoción es una clínica,
                                // abrir formulario para crear la clínica y usuario admin.
                                if (paid == true &&
                                    titulo.toLowerCase().contains('clínica')) {
                                  // Abrir diálogo para crear clínica + usuario admin
                                  final created = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => _CrearClinicaDialog());
                                  if (created == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Clínica creada y usuario dueño generado')));
                                  }
                                }
                              } else {
                                final err = (res['error'] ?? '').toString();
                                // Si el servidor responde que faltan credenciales,
                                // permitimos el flujo alternativo: crear la clínica
                                // directamente (formulario que pide nombre/dirección
                                // y usuario/clave para el admin).
                                if (err.toLowerCase().contains('credencial') ||
                                    err.toLowerCase().contains('faltan')) {
                                  final created = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => _CrearClinicaDialog());
                                  if (created == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Clínica creada y usuario dueño generado')));
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Error: ${res['error']}')));
                                }
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CrearClinicaDialog extends StatefulWidget {
  @override
  State<_CrearClinicaDialog> createState() => _CrearClinicaDialogState();
}

class _CrearClinicaDialogState extends State<_CrearClinicaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  bool cargando = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear clínica y usuario admin'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre clínica'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 12),
              const Text('Usuario administrador'),
              TextFormField(
                controller: _usuarioCtrl,
                decoration: const InputDecoration(labelText: 'Usuario'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _claveCtrl,
                decoration: const InputDecoration(labelText: 'Clave'),
                obscureText: true,
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: cargando
                ? null
                : () async {
                    if (_formKey.currentState?.validate() != true) return;
                    setState(() => cargando = true);

                    final res = await ApiService.crearClinicaConAdmin(
                        nombre: _nombreCtrl.text.trim(),
                        direccion: _direccionCtrl.text.trim(),
                        usuario: _usuarioCtrl.text.trim(),
                        clave: _claveCtrl.text.trim());
                    setState(() => cargando = false);
                    if (!(res['ok'] ?? false)) {
                      // Mostrar mensaje amigable proveniente del servidor si existe
                      final msg = res['error'] ??
                          res['message'] ??
                          'No se pudo crear la clínica';
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg.toString())));
                      return;
                    }

                    Navigator.pop(context, true);
                  },
            child: cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Crear'))
      ],
    );
  }
}

class _DoctorIndividualDialog extends StatefulWidget {
  @override
  State<_DoctorIndividualDialog> createState() =>
      _DoctorIndividualDialogState();
}

class _DoctorIndividualDialogState extends State<_DoctorIndividualDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  bool cargando = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar Doctor Individual'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _usuarioCtrl,
              decoration: const InputDecoration(labelText: 'Usuario'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Campo requerido' : null,
            ),
            TextFormField(
              controller: _claveCtrl,
              decoration: const InputDecoration(labelText: 'Clave'),
              obscureText: true,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Campo requerido' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: cargando
              ? null
              : () async {
                  if (_formKey.currentState?.validate() != true) return;
                  final username = _usuarioCtrl.text.trim();
                  setState(() => cargando = true);
                  final available =
                      await ApiService.verificarUsuarioDisponible(username);
                  if (!available) {
                    setState(() => cargando = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('El nombre de usuario ya está en uso')));
                    return;
                  }
                  final result = await ApiService.registrarDoctorIndividual(
                    username,
                    _claveCtrl.text.trim(),
                  );
                  setState(() => cargando = false);
                  // Notify global listeners so lists refresh automatically
                  // Increment notifier to signal refresh
                  globalRefreshNotifier.value = globalRefreshNotifier.value + 1;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['ok']
                          ? 'Doctor registrado correctamente'
                          : 'Error: ${result['error']}'),
                    ),
                  );
                },
          child: cargando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Registrar'),
        ),
      ],
    );
  }
}

class _MockPagoDialog extends StatefulWidget {
  final String paymentUrl;
  final String compraId;
  const _MockPagoDialog({required this.paymentUrl, required this.compraId});

  @override
  State<_MockPagoDialog> createState() => _MockPagoDialogState();
}

class _MockPagoDialogState extends State<_MockPagoDialog> {
  bool cargando = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pago (simulado)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('URL de pago: ${widget.paymentUrl}'),
          const SizedBox(height: 12),
          const Text(
              'Presiona "Simular pago" para completar la compra (modo mock).')
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: cargando
                ? null
                : () async {
                    setState(() => cargando = true);
                    final ok = await ApiService.confirmarCompraPromocion(
                        widget.compraId);
                    setState(() => cargando = false);
                    Navigator.pop(context, ok);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Compra completada'
                            : 'Error al confirmar compra')));
                  },
            child: cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simular pago'))
      ],
    );
  }
}
