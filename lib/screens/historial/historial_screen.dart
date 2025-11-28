import 'package:flutter/material.dart';
import '../../models/paciente.dart';
import '../../models/consulta.dart';
import '../../services/api_services.dart';
import '../../route_refresh_mixin.dart';
import 'agregar_editar_consulta_screen.dart';

class HistorialScreen extends StatefulWidget {
  final Paciente paciente;
  const HistorialScreen({super.key, required this.paciente});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen>
    with RouteRefreshMixin<HistorialScreen> {
  List<Consulta> consultas = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarConsultas();
  }

  @override
  void onRouteRefreshed() {
    try {
      cargarConsultas();
    } catch (_) {}
  }

  Future<void> cargarConsultas() async {
    setState(() => cargando = true);

    final data = await ApiService.obtenerConsultasPaciente(widget.paciente.id);
    setState(() {
      // ApiService already devuelve List<Consulta>
      consultas = data;
      cargando = false;
    });
  }

  void irAgregarConsulta() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarEditarConsultaScreen(paciente: widget.paciente),
      ),
    );
    if (resultado == true) cargarConsultas();
  }

  void irEditarConsulta(Consulta c) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarEditarConsultaScreen(
          paciente: widget.paciente,
          consulta: c,
        ),
      ),
    );
    if (resultado == true) cargarConsultas();
  }

  void eliminarConsulta(Consulta c) async {
    final ok = await ApiService.eliminarHistorial(c.id);
    if (ok) cargarConsultas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Historial de ${widget.paciente.nombres}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: irAgregarConsulta,
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : consultas.isEmpty
              ? const Center(child: Text("No hay consultas registradas"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: consultas.length,
                  itemBuilder: (_, index) {
                    final c = consultas[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(c.motivo),
                        subtitle: Text("Diagnóstico: ${c.diagnostico}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => irEditarConsulta(c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => eliminarConsulta(c),
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
