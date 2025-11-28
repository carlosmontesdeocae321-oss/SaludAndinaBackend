import 'package:flutter/material.dart';
import '../../services/api_services.dart';
import '../../route_refresh_mixin.dart';
import '../admin/buy_doctor_slot_dialog.dart';
import '../../utils/formato_fecha.dart';
import '../../models/paciente.dart';
import '../paciente/agregar_editar_paciente_screen.dart';
import '../paciente/consultas_screen.dart';
import '../paciente/agendar_cita_screen.dart';
import '../login/login_screen.dart';
import '../citas/citas_screen.dart';
import '../doctor/profile_screen.dart';
import '../dueno/dashboard_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../services/auth_servicios.dart';
import '../inicio_screen.dart';

class MenuPrincipalScreen extends StatefulWidget {
  const MenuPrincipalScreen({super.key});

  @override
  State<MenuPrincipalScreen> createState() => _MenuPrincipalScreenState();
}

class _MenuPrincipalScreenState extends State<MenuPrincipalScreen>
    with RouteRefreshMixin<MenuPrincipalScreen> {
  bool cargando = true;
  int totalPacientes = 0;
  int limitePacientes = 0;
  String? clinicaNombre;
  String? usuarioNombre;
  bool esDueno = false;
  bool esVinculado = false; // true si el doctor fue vinculado mediante compra
  List<Map<String, dynamic>> doctores = [];
  bool isDoctor = false;
  int? doctorIdState;
  String selectedView = 'clinica'; // 'individual' | 'clinica' | 'both'
  int? clinicaIdState;

  @override
  void initState() {
    super.initState();
    _initDatos();
  }

  @override
  void onRouteRefreshed() {
    try {
      _initDatos();
    } catch (_) {}
  }

  Future<void> _mostrarEquipoDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Equipo'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (doctores.isEmpty)
                  const Text('No hay doctores registrados.'),
                if (doctores.isNotEmpty)
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: doctores.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final d = doctores[i];
                        final displayName = d['nombre'] ??
                            d['usuario'] ??
                            d['name'] ??
                            'Doctor';
                        final specialty =
                            d['especialidad'] ?? d['especialidad_medica'] ?? '';
                        final email = d['email'] ?? d['correo'] ?? '';
                        final clinicName = d['clinica'] ??
                            d['clinica_nombre'] ??
                            d['clinic_name'];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: d['avatar_url'] != null
                                ? NetworkImage(d['avatar_url']) as ImageProvider
                                : null,
                            child: d['avatar_url'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(displayName.toString()),
                          subtitle: Text(specialty?.toString() ?? ''),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // Mostrar tarjeta con detalles del doctor
                            showDialog<void>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(displayName.toString()),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: CircleAvatar(
                                          radius: 48,
                                          backgroundImage: d['avatar_url'] !=
                                                  null
                                              ? NetworkImage(d['avatar_url'])
                                                  as ImageProvider
                                              : null,
                                          child: d['avatar_url'] == null
                                              ? const Icon(Icons.person,
                                                  size: 48)
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (specialty != null &&
                                          specialty.toString().isNotEmpty)
                                        Text(
                                            'Especialidad: ${specialty.toString()}'),
                                      const SizedBox(height: 6),
                                      if (email != null &&
                                          email.toString().isNotEmpty)
                                        Text('Correo: ${email.toString()}'),
                                      const SizedBox(height: 6),
                                      if (clinicName != null &&
                                          clinicName.toString().isNotEmpty)
                                        Text(
                                            'Clínica: ${clinicName.toString()}'),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cerrar')),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar')),
            // Nota: el botón para crear/compra de doctor fue movido fuera del diálogo
            // y permanece disponible en la pestaña 'Clínica'. No mostramos aquí el control.
          ],
        );
      },
    );
  }

  Future<void> _initDatos() async {
    await cargarMisDatos();
    setState(() {
      cargando = false;
    });
  }

  Future<void> cargarMisDatos() async {
    final datos = await ApiService.obtenerMisDatos();
    if (datos != null) {
      setState(() {
        totalPacientes = (datos['totalPacientes'] is int)
            ? datos['totalPacientes']
            : int.tryParse('${datos['totalPacientes']}') ?? 0;
        limitePacientes = (datos['limite'] is int)
            ? datos['limite']
            : int.tryParse('${datos['limite']}') ?? 0;
        clinicaNombre = datos['clinica']?.toString();
        usuarioNombre = datos['usuario']?.toString();
        esDueno = datos['dueno'] == true;
        final rawClinica = datos['clinicaId'] ?? datos['clinica_id'];
        if (rawClinica == null) {
          clinicaIdState = null;
        } else if (rawClinica is int) {
          clinicaIdState = rawClinica;
        } else {
          clinicaIdState = int.tryParse(rawClinica.toString());
        }
        if (datos['doctores'] is List) {
          doctores = List<Map<String, dynamic>>.from(datos['doctores']);
        } else {
          doctores = [];
        }
        esVinculado = datos['esVinculado'] == true;
        // Resolver doctorId: puede venir como doctorId/doctor_id/id
        var potentialDoctorId =
            datos['doctorId'] ?? datos['doctor_id'] ?? datos['id'];
        // Si el usuario está en una clínica y mis-datos incluye 'doctores' y el nombre de usuario,
        // intentar localizar el id del doctor actual mediante el usuario (username).
        if (potentialDoctorId == null) {
          try {
            final usuarioActual = datos['usuario']?.toString();
            final listaDoctores = datos['doctores'];
            if (usuarioActual != null && listaDoctores is List) {
              for (final d in listaDoctores) {
                try {
                  if (d != null && d['usuario'] == usuarioActual) {
                    potentialDoctorId = d['id'];
                    break;
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
        // Guardar en estado el doctorId si se resolvió
        if (potentialDoctorId != null) {
          if (potentialDoctorId is int) {
            doctorIdState = potentialDoctorId;
          } else {
            doctorIdState = int.tryParse(potentialDoctorId.toString());
          }
        } else {
          doctorIdState = null;
        }
        // Guardar si el usuario autenticado es doctor
        isDoctor = (datos['rol'] == 'doctor');
      });
    }
  }

  void cerrarSesion(BuildContext context) {
    // Clear stored credentials and navigate to the public inicio screen
    AuthService.logout().then((_) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const InicioScreen()),
          (route) => false);
    });
  }

  int _tabIndexFromView(String view) {
    switch (view) {
      case 'individual':
        return 0;
      case 'both':
        return 2;
      case 'clinica':
      default:
        return 1;
    }
  }

  Widget _buildPacienteListForView(String view) {
    final viewToSend =
        (clinicaIdState == null && view != 'individual') ? 'individual' : view;
    return FutureBuilder<List<Paciente>>(
      future: ApiService.obtenerPacientesPorClinica(view: viewToSend),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No hay pacientes registrados'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            await cargarMisDatos();
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final p = items[index];
              return GestureDetector(
                onLongPress: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Eliminar paciente'),
                      content: Text(
                          '¿Seguro que deseas eliminar a ${p.nombres} ${p.apellidos}?'),
                      actions: [
                        TextButton(
                            child: const Text('Cancelar'),
                            onPressed: () => Navigator.pop(context, false)),
                        TextButton(
                            child: const Text('Eliminar',
                                style: TextStyle(color: Colors.red)),
                            onPressed: () => Navigator.pop(context, true)),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final ok =
                        await ApiService.eliminarPaciente(p.id.toString());
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Paciente eliminado')));
                      setState(() {});
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Error al eliminar paciente')));
                    }
                  }
                },
                child: Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p.nombres} ${p.apellidos}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            'Cédula: ${p.cedula.isEmpty ? 'No registrada' : p.cedula}'),
                        Text(
                            'Teléfono: ${p.telefono.isEmpty ? 'No registrado' : p.telefono}'),
                        Text(
                            'Dirección: ${p.direccion.isEmpty ? 'No registrada' : p.direccion}'),
                        const SizedBox(height: 6),
                        Text('Nacimiento: ${fechaConEdad(p.fechaNacimiento)}',
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.calendar_today),
                              label: const Text('Agendar cita'),
                              onPressed: () async {
                                final added = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AgendarCitaScreen(
                                      pacienteId: p.id,
                                    ),
                                  ),
                                );
                                if (added == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Cita agendada')),
                                  );
                                }
                              },
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.medical_information),
                              label: const Text('Consultas'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ConsultasScreen(
                                      pacienteId: p.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar'),
                              onPressed: () async {
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AgregarEditarPacienteScreen(
                                      paciente: p,
                                    ),
                                  ),
                                );
                                if (updated == true) setState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showActionsDialog(BuildContext context) async {
    final view = selectedView;
    final isClinicView = view == 'clinica' || view == 'both';
    final isIndividualView = view == 'individual';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Acciones disponibles'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Individual
                if (isIndividualView) ...[
                  ListTile(
                    leading: const Icon(Icons.person_add),
                    title: const Text('Agregar paciente individual'),
                    subtitle: const Text(
                        'Crear y registrar un paciente para este doctor'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final datos = await ApiService.obtenerMisDatos();
                      if ((datos?['totalPacientes'] ?? 0) >=
                          (datos?['limite'] ?? 0)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Límite de pacientes alcanzado. Debe comprar cupos extra.')));
                        return;
                      }
                      // Resolver doctorId similar a la acción principal
                      var dlgDoctorId = datos?['doctorId'] ??
                          datos?['doctor_id'] ??
                          datos?['id'];
                      if (dlgDoctorId == null && datos != null) {
                        try {
                          final usuarioActual = datos['usuario']?.toString();
                          final listaDoctores = datos['doctores'];
                          if (usuarioActual != null && listaDoctores is List) {
                            for (final d in listaDoctores) {
                              try {
                                if (d != null &&
                                    d['usuario'] == usuarioActual) {
                                  dlgDoctorId = d['id'];
                                  break;
                                }
                              } catch (_) {}
                            }
                          }
                        } catch (_) {}
                      }
                      final added = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AgregarEditarPacienteScreen(
                                    paciente: null,
                                    doctorId: dlgDoctorId is int
                                        ? dlgDoctorId
                                        : (int.tryParse(
                                            dlgDoctorId?.toString() ?? '')),
                                    clinicaId: null,
                                  )));
                      if (added == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Paciente agregado')));
                        await cargarMisDatos();
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1),
                    title: const Text('Comprar cupo de paciente (4)'),
                    subtitle: const Text(
                        'Comprar un cupo extra para paciente individual'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      // Simular pago de $1 antes de llamar al endpoint
                      final paid = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Simulación de pago'),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Simular pago de \$1 por cupo de paciente'),
                            ],
                          ),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Procesando compra...')));
                      final compra = await ApiService.comprarPacienteExtra();
                      if ((compra['ok'] ?? false)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Paciente extra comprado')));
                        await cargarMisDatos();
                      } else {
                        final msg = compra['error'] ??
                            compra['message'] ??
                            'No se pudo completar la compra';
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg.toString())));
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Vincular paciente'),
                    subtitle: const Text(
                        'Vincular un paciente existente (pago único)'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Funcionalidad de vinculación de paciente pendiente de implementar.')));
                    },
                  ),
                ],
                // Clínica (dueño o doctor vinculado)
                if (clinicaIdState != null && isClinicView) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text('Estás operando en la clínica: $clinicaNombre',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1),
                    title: const Text('Agregar paciente a la clínica'),
                    subtitle: const Text(
                        'Crear y registrar un paciente para la clínica'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final datos = await ApiService.obtenerMisDatos();
                      if ((datos?['totalPacientes'] ?? 0) >=
                          (datos?['limite'] ?? 0)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Límite de pacientes alcanzado. Debe comprar cupos extra.')));
                        return;
                      }
                      final clinicaToPass =
                          datos?['clinicaId'] ?? datos?['clinica_id'];
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AgregarEditarPacienteScreen(
                                  paciente: null,
                                  doctorId: null,
                                  clinicaId: clinicaToPass is int
                                      ? clinicaToPass
                                      : (int.tryParse(
                                          clinicaToPass?.toString() ?? '')))));
                      await cargarMisDatos();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1),
                    title: const Text('Comprar cupo de paciente'),
                    subtitle:
                        const Text('Comprar un cupo extra para la clínica'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final paid = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Simulación de pago'),
                          content: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    'Simular pago de \$1 por cupo de paciente (clínica)')
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Procesando compra...')));
                      final compra = await ApiService.comprarPacienteExtra();
                      if ((compra['ok'] ?? false)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Paciente extra comprado para la clínica')));
                        await cargarMisDatos();
                      } else {
                        final msg = compra['error'] ??
                            compra['message'] ??
                            'No se pudo completar la compra';
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg.toString())));
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.medical_services),
                    title: const Text('Comprar doctor para la clínica'),
                    subtitle:
                        const Text('Comprar y crear un doctor para la clínica'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final nameCtrl = TextEditingController();
                      final passCtrl = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Crear doctor (compra)'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: nameCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Usuario'),
                              ),
                              TextField(
                                controller: passCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Contraseña'),
                                obscureText: true,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Comprar y crear'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        final nombre = nameCtrl.text.trim();
                        final clave = passCtrl.text.trim();
                        if (nombre.isEmpty || clave.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Debe ingresar usuario y contraseña')),
                          );
                          return;
                        }

                        // Simular pago antes de crear
                        final paid = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Simulación de pago'),
                            content: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    'Simular pago de \$5 por creación y asignación de doctor'),
                              ],
                            ),
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

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Procesando compra...')),
                        );
                        final datos = await ApiService.obtenerMisDatos();
                        final clinicaId =
                            datos?['clinicaId'] ?? datos?['clinica_id'];
                        if (clinicaId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('No se encontró la clínica')),
                          );
                          return;
                        }
                        final compra = await ApiService.comprarDoctorExtra(
                          clinicaId: clinicaId as int,
                          usuario: nombre,
                          clave: clave,
                        );
                        if ((compra['ok'] ?? false)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Doctor comprado y creado')),
                          );
                          await cargarMisDatos();
                        } else {
                          final msg = compra['error'] ??
                              compra['message'] ??
                              'No se pudo completar la compra';
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg.toString())));
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Vincular doctor'),
                    subtitle: const Text(
                        'Vincular un doctor existente a la clínica (pago único)'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final txt = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Vincular doctor a la clínica'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: txt,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'ID del doctor'),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                  'Costo de vinculación: \$10 (pago único)'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Comprar y vincular'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        final doctorId = int.tryParse(txt.text.trim());
                        if (doctorId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID inválido')),
                          );
                          return;
                        }

                        // Ejecutar flujo: validar si la clínica tiene espacio
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Verificando espacio para vinculación...')),
                        );
                        final datos = await ApiService.obtenerMisDatos();
                        final clinicaId =
                            datos?['clinicaId'] ?? datos?['clinica_id'];
                        if (clinicaId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('No se encontró la clínica')),
                          );
                          return;
                        }

                        final validation =
                            await ApiService.validarAgregarDoctor(
                                clinicaId as int);
                        final permitido = validation['permitido'] == true;

                        if (!permitido) {
                          // Mostrar motivo ofrecido por el servidor (si existe)
                          final motivo = validation['message'] ??
                              validation['error'] ??
                              validation['reason'];
                          if (motivo != null && motivo.toString().isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(motivo.toString())));
                          }
                          final precio = (validation['precioDoctorSlot'] is num)
                              ? (validation['precioDoctorSlot'] as num)
                                  .toDouble()
                              : 5.0;
                          // Abrir diálogo modal de compra con pestañas (Vincular / Crear)
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (_) => BuyDoctorSlotDialog(
                              clinicaId: clinicaId,
                              precio: precio,
                              initialTab: 'vincular',
                              doctorId: doctorId,
                            ),
                          );
                          if (result == true) await cargarMisDatos();
                          return;
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1),
                    title: const Text('Comprar slot de doctor'),
                    subtitle: const Text(
                        'Comprar 1 cupo para añadir o vincular doctor'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final datos = await ApiService.obtenerMisDatos();
                      final clinicaId =
                          datos?['clinicaId'] ?? datos?['clinica_id'];
                      if (clinicaId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('No se encontró la clínica')),
                        );
                        return;
                      }
                      double precio = 5.0;
                      try {
                        final v = await ApiService.validarAgregarDoctor(
                            clinicaId as int);
                        if (v['precioDoctorSlot'] != null) {
                          final p = v['precioDoctorSlot'];
                          if (p is num) precio = p.toDouble();
                        }
                      } catch (_) {}

                      final result = await showDialog<bool>(
                        context: context,
                        builder: (_) => BuyDoctorSlotDialog(
                            clinicaId: clinicaId as int, precio: precio),
                      );
                      if (result == true) await cargarMisDatos();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Decidir si se muestran las vistas
    // Un doctor individual (sin `clinicaId`) NO debe ver la pestaña 'Clínica'.
    // Un doctor vinculado (`esVinculado == true`) ve ambas pestañas.
    // Un doctor creado por la clínica (tiene `clinicaId` y `esVinculado == false`) ve solo 'Clínica'.
    final bool showIndividual = (clinicaIdState == null) || esVinculado == true;
    // Mostrar vista clínica solo si el usuario aún pertenece a una clínica o es dueño.
    // No forzar la vista clínica solo por el flag `esVinculado` cuando `clinicaIdState` ya es null.
    final bool showClinica = (clinicaIdState != null) || esDueno == true;
    // Ajustar selectedView si una vista no está disponible
    if (!showIndividual && selectedView == 'individual') {
      selectedView = showClinica ? 'clinica' : 'individual';
    }
    if (!showClinica && selectedView == 'clinica') {
      selectedView = showIndividual ? 'individual' : 'clinica';
    }

    // Preparar stacks reutilizables
    final individualStack = Stack(
      children: [
        Positioned.fill(child: _buildPacienteListForView('individual')),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Agregar paciente individual'),
              onPressed: () async {
                final datos = await ApiService.obtenerMisDatos();
                // Debug: mostrar qué retorna mis-datos y qué id de doctor vamos a pasar
                final potentialDoctorId =
                    datos?['doctorId'] ?? datos?['doctor_id'] ?? datos?['id'];
                print('DEBUG before add individual - obtenerMisDatos: $datos');
                print(
                    'DEBUG before add individual - resolved doctorId: $potentialDoctorId');
                if ((datos?['totalPacientes'] ?? 0) >=
                    (datos?['limite'] ?? 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Límite de pacientes alcanzado. Debe comprar cupos extra.')));
                  return;
                }
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgregarEditarPacienteScreen(
                      paciente: null,
                      doctorId: potentialDoctorId is int
                          ? potentialDoctorId
                          : (int.tryParse(potentialDoctorId?.toString() ?? '')),
                      clinicaId: null,
                    ),
                  ),
                );
                if (added == true) await cargarMisDatos();
              },
            ),
          ),
        ),
      ],
    );

    final clinicStack = Stack(
      children: [
        Positioned.fill(child: _buildPacienteListForView('clinica')),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Agregar paciente a la clínica'),
                  onPressed: () async {
                    final datos = await ApiService.obtenerMisDatos();
                    if ((datos?['totalPacientes'] ?? 0) >=
                        (datos?['limite'] ?? 0)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Límite de pacientes alcanzado. Debe comprar cupos extra.')));
                      return;
                    }
                    final added = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AgregarEditarPacienteScreen(
                          paciente: null,
                          doctorId: null,
                          clinicaId:
                              datos?['clinicaId'] ?? datos?['clinica_id'],
                        ),
                      ),
                    );
                    if (added == true) await cargarMisDatos();
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                    icon: const Icon(Icons.medical_services),
                    label: const Text('Agregar doctor'),
                    onPressed: esDueno
                        ? () async {
                            // Flujo: validar si la clínica puede agregar de forma gratuita.
                            final datos = await ApiService.obtenerMisDatos();
                            final clinicaId = clinicaIdState ??
                                datos?['clinicaId'] ??
                                datos?['clinica_id'];
                            if (clinicaId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('No se encontró la clínica')));
                              return;
                            }
                            final valid = await ApiService.validarAgregarDoctor(
                                clinicaId as int);
                            print('DEBUG validarAgregarDoctor: $valid');
                            if ((valid['permitido'] ?? false) == true) {
                              // Puede agregar sin compra: crear usuario de clínica directamente
                              final nameCtrl = TextEditingController();
                              final passCtrl = TextEditingController();
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title:
                                      const Text('Crear doctor en la clínica'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                          controller: nameCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'Usuario')),
                                      TextField(
                                          controller: passCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'Contraseña'),
                                          obscureText: true),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancelar')),
                                    ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Crear')),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                final nombre = nameCtrl.text.trim();
                                final clave = passCtrl.text.trim();
                                if (nombre.isEmpty || clave.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Debe ingresar usuario y contraseña')));
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Creando doctor...')));
                                final resp =
                                    await ApiService.crearUsuarioClinica(
                                        usuario: nombre,
                                        clave: clave,
                                        rol: 'doctor',
                                        clinicaId: clinicaId);
                                print('DEBUG crearUsuarioClinica resp: $resp');
                                if ((resp['ok'] ?? false)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Doctor creado correctamente')));
                                  await cargarMisDatos();
                                } else {
                                  final msg = resp['error'] ??
                                      resp['message'] ??
                                      'No se pudo completar la operación';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg.toString())));
                                }
                              }
                            } else {
                              // No puede agregar sin compra -> mostrar motivo y abrir diálogo de compra con pestañas (crear)
                              final motivo = valid['message'] ??
                                  valid['error'] ??
                                  valid['reason'];
                              if (motivo != null &&
                                  motivo.toString().isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(motivo.toString())));
                              }
                              // No puede agregar sin compra -> abrir pantalla de compra con pestañas (crear)
                              double precio = 5.0;
                              try {
                                final v = await ApiService.validarAgregarDoctor(
                                    clinicaId);
                                if (v['precioDoctorSlot'] != null) {
                                  final p = v['precioDoctorSlot'];
                                  if (p is num) precio = p.toDouble();
                                }
                              } catch (_) {}

                              final result = await showDialog<bool>(
                                context: context,
                                builder: (_) => BuyDoctorSlotDialog(
                                    clinicaId: clinicaId,
                                    precio: precio,
                                    initialTab: 'crear'),
                              );
                              if (result == true) await cargarMisDatos();
                            }
                          }
                        : null),
                const SizedBox(width: 12),
                // Botón para comprar cupo para paciente de la clínica (visible para dueños y doctores vinculados)
                if (clinicaIdState != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.apartment),
                    label: const Text('Cupo para paciente clínica'),
                    onPressed: () async {
                      // Asegurar que el usuario está autenticado y obtener clinicaId
                      final datos = await ApiService.obtenerMisDatos();
                      if (datos == null) {
                        // Probablemente 401: sugerir login
                        final goLogin = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Necesita iniciar sesión'),
                            content: const Text(
                                'Para comprar cupos para la clínica debe iniciar sesión.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar')),
                              ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Iniciar sesión')),
                            ],
                          ),
                        );
                        if (goLogin == true) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()));
                        }
                        return;
                      }

                      final clinicaId =
                          datos['clinicaId'] ?? datos['clinica_id'];
                      if (clinicaId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'No se encontró la clínica asociada')));
                        return;
                      }

                      final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                                title:
                                    const Text('Comprar cupo para la clínica'),
                                content: const Text(
                                    'Comprar 1 cupo para paciente de la clínica por \$1.00'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar')),
                                  ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Comprar')),
                                ],
                              ));
                      if (confirm != true) return;

                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Procesando compra...')));
                      final resp = await ApiService.comprarPacienteExtra();
                      if ((resp['ok'] ?? false) == true) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Cupo para paciente de la clínica comprado')));
                        await cargarMisDatos();
                      } else {
                        final msg = resp['error'] ??
                            resp['message'] ??
                            'No se pudo completar la compra';
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg.toString())));
                      }
                    },
                  ),
                const SizedBox(width: 12),
                // Botón para vincular doctor (visible para dueños de la clínica)
                if (esDueno)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('Vincular doctor'),
                    onPressed: () async {
                      final txt = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Vincular doctor a la clínica'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: txt,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'ID del doctor'),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                  'Costo de vinculación: \$10 (pago único)'),
                            ],
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar')),
                            ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Comprar y vincular')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        final doctorId = int.tryParse(txt.text.trim());
                        if (doctorId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ID inválido')));
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Procesando vinculación...')));
                        final datos = await ApiService.obtenerMisDatos();
                        final clinicaId =
                            datos?['clinicaId'] ?? datos?['clinica_id'];
                        if (clinicaId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('No se encontró la clínica')));
                          return;
                        }
                        final linkRes =
                            await ApiService.vincularDoctorConCompra(
                                doctorId, clinicaId as int);
                        if ((linkRes['ok'] ?? false) == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Doctor vinculado correctamente')));
                          await cargarMisDatos();
                        } else {
                          final msg = linkRes['error'] ??
                              'No se pudo vincular el doctor. Intenta nuevamente.';
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(msg)));
                        }
                      }
                    },
                  ),
                // Desvincular solo para doctores vinculados (no aplicable a doctores creados por la clínica)
                if (!esDueno && esVinculado == true) const SizedBox(width: 12),
                if (!esDueno && esVinculado == true)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.link_off),
                    label: const Text('Desvincularme de la clínica'),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                                title: const Text('Desvincularme'),
                                content: const Text(
                                    '¿Estás seguro que deseas desvincularte de la clínica? Tus pacientes permanecerán en la clínica.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar')),
                                  ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Desvincular')),
                                ],
                              ));
                      if (confirm != true) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Procesando desvinculación...')));
                      final ok = await ApiService.desvincularDoctor();
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Desvinculación realizada')));
                        await cargarMisDatos();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Error al desvincularse')));
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    List<Tab> tabsList = [];
    List<Widget> views = [];
    if (showIndividual && showClinica) {
      tabsList = const [Tab(text: 'Individual'), Tab(text: 'Clínica')];
      views = [individualStack, clinicStack];
    } else if (showIndividual && !showClinica) {
      tabsList = const [Tab(text: 'Individual')];
      views = [individualStack];
    } else if (!showIndividual && showClinica) {
      tabsList = const [Tab(text: 'Clínica')];
      views = [clinicStack];
    } else {
      // Fallback: mostrar clínica
      tabsList = const [Tab(text: 'Clínica')];
      views = [clinicStack];
    }

    final initialIndex = (showIndividual && showClinica)
        ? (selectedView == 'clinica' ? 1 : 0)
        : 0;

    return DefaultTabController(
      length: tabsList.length,
      initialIndex: initialIndex,
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Menú Principal'),
              if (clinicaNombre != null && selectedView == 'clinica')
                Text('Clínica: $clinicaNombre',
                    style: const TextStyle(fontSize: 14)),
              if (usuarioNombre != null && selectedView == 'individual')
                Text('Doctor: $usuarioNombre',
                    style: const TextStyle(fontSize: 14)),
            ],
          ),
          actions: [
            // Botón Equipo: muestra lista de doctores y opción para agregar (si es dueño)
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Equipo',
              onPressed: () async {
                await _mostrarEquipoDialog(context);
              },
            ),
            // Mostrar botón de perfil del doctor cuando estemos en vista individual
            if (selectedView == 'individual')
              IconButton(
                icon: const Icon(Icons.person),
                tooltip: 'Perfil',
                onPressed: () async {
                  // Intentar resolver el doctorId desde mis-datos
                  final datos = await ApiService.obtenerMisDatos();
                  var doctorId =
                      datos?['doctorId'] ?? datos?['doctor_id'] ?? datos?['id'];
                  if (doctorId == null) {
                    // intentar buscar en la lista de doctores por usuario
                    try {
                      final usuarioActual = datos?['usuario']?.toString();
                      final lista = datos?['doctores'];
                      if (usuarioActual != null && lista is List) {
                        for (final d in lista) {
                          if (d != null && d['usuario'] == usuarioActual) {
                            doctorId = d['id'];
                            break;
                          }
                        }
                      }
                    } catch (_) {}
                  }
                  if (doctorId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('No se pudo resolver el ID del doctor')));
                    return;
                  }
                  final id = doctorId is int
                      ? doctorId
                      : int.tryParse(doctorId.toString());
                  if (id == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID de doctor inválido')));
                    return;
                  }
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PerfilDoctorScreen(doctorId: id)));
                },
              ),
            // Comprar cupo individual (visible en pestaña 'individual' si es doctor)
            if (selectedView == 'individual' && isDoctor)
              IconButton(
                icon: const Icon(Icons.person_add_alt_1),
                tooltip: 'Comprar cupo individual',
                onPressed: () async {
                  // confirmar compra
                  final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                            title: const Text('Comprar cupo individual'),
                            content: const Text(
                                'Comprar 1 cupo individual por \$1.00'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar')),
                              ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Comprar'))
                            ],
                          ));
                  if (confirm != true) return;
                  if (doctorIdState == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('No se pudo resolver el ID del doctor')));
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Procesando compra...')));
                  final res = await ApiService.comprarPacienteIndividual(
                      doctorIdState!);
                  if ((res['ok'] ?? false)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Cupo individual comprado')));
                    await cargarMisDatos();
                  } else {
                    final msg =
                        res['error'] ?? res['message'] ?? 'No se pudo comprar';
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(msg.toString())));
                  }
                },
              ),
            // (Removed AppBar clinic purchase button — purchases should be performed
            // from the 'Clínica' tab controls next to 'Agregar doctor')
            // Botón para acceder al dashboard del dueño (visible solo si es dueño)
            if (esDueno)
              IconButton(
                icon: const Icon(Icons.dashboard),
                tooltip: 'Dashboard',
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DashboardDuenoScreen()));
                },
              ),
            IconButton(
              icon: const Icon(Icons.event),
              tooltip: 'Ver citas',
              onPressed: () {
                // Asegúrate de importar CitasScreen correctamente
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CitasScreen()));
              },
            ),
            // Logout button removed from AppBar per user request.
          ],
          bottom: TabBar(
              tabs: tabsList,
              onTap: (i) {
                setState(() {
                  if (showIndividual && showClinica) {
                    selectedView = i == 0 ? 'individual' : 'clinica';
                  } else if (showIndividual) {
                    selectedView = 'individual';
                  } else {
                    selectedView = 'clinica';
                  }
                });
              }),
        ),
        body: TabBarView(children: views),
      ),
    );
  }
}
