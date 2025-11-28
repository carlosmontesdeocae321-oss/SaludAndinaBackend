import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/paciente.dart';
import '../../models/consulta.dart';
import '../../services/api_services.dart';

class AgregarEditarConsultaScreen extends StatefulWidget {
  final Paciente? paciente;
  final String? pacienteId;
  final Consulta? consulta; // si es null -> agregar, si no -> editar

  const AgregarEditarConsultaScreen({
    super.key,
    this.paciente,
    this.pacienteId,
    this.consulta,
  });

  @override
  State<AgregarEditarConsultaScreen> createState() =>
      _AgregarEditarConsultaScreenState();
}

class _AgregarEditarConsultaScreenState
    extends State<AgregarEditarConsultaScreen> {
  final _formKey = GlobalKey<FormState>();

  // Campos de la consulta
  late TextEditingController motivoCtrl;
  late TextEditingController diagnosticoCtrl;
  late TextEditingController tratamientoCtrl;
  late TextEditingController recetaCtrl;
  late TextEditingController fechaCtrl;
  late TextEditingController pesoCtrl;
  late TextEditingController estaturaCtrl;
  late TextEditingController imcCtrl;
  late TextEditingController presionCtrl;
  late TextEditingController frecuenciaCardiacaCtrl;
  late TextEditingController frecuenciaRespiratoriaCtrl;
  late TextEditingController temperaturaCtrl;

  bool cargando = false;
  final ImagePicker _picker = ImagePicker();
  List<XFile> nuevasImagenes = [];
  List<String> imagenesExistentes = [];

  @override
  void initState() {
    super.initState();
    final c = widget.consulta;
    motivoCtrl = TextEditingController(text: c?.motivo ?? '');
    fechaCtrl = TextEditingController(
        text: c != null ? (c.fecha.toIso8601String().split('T')[0]) : '');
    diagnosticoCtrl = TextEditingController(text: c?.diagnostico ?? '');
    tratamientoCtrl = TextEditingController(text: c?.tratamiento ?? '');
    recetaCtrl = TextEditingController(text: c?.receta ?? '');
    pesoCtrl = TextEditingController(text: c?.peso.toString() ?? '');
    estaturaCtrl = TextEditingController(text: c?.estatura.toString() ?? '');
    imcCtrl = TextEditingController(text: c?.imc.toString() ?? '');
    presionCtrl = TextEditingController(text: c?.presion ?? '');
    frecuenciaCardiacaCtrl =
        TextEditingController(text: c?.frecuenciaCardiaca.toString() ?? '');
    frecuenciaRespiratoriaCtrl =
        TextEditingController(text: c?.frecuenciaRespiratoria.toString() ?? '');
    temperaturaCtrl =
        TextEditingController(text: c?.temperatura.toString() ?? '');
    imagenesExistentes = c?.imagenes ?? [];
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = fechaCtrl.text.isNotEmpty
        ? DateTime.tryParse(fechaCtrl.text) ?? now
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      fechaCtrl.text = picked.toIso8601String().split('T')[0];
      setState(() {});
    }
  }

  Future<void> guardarConsulta() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => cargando = true);

    final pacienteId = widget.paciente?.id ?? widget.pacienteId ?? '';

    // Normalizar campos numéricos: si vienen vacíos enviarlos como números válidos.
    String asDecimal(String s) {
      final t = s.trim();
      if (t.isEmpty) return '0.0';
      final parsed = double.tryParse(t.replaceAll(',', '.'));
      if (parsed == null) return '0.0';
      return parsed.toString();
    }

    String asInt(String s) {
      final t = s.trim();
      if (t.isEmpty) return '0';
      final parsed = int.tryParse(t);
      if (parsed != null) return parsed.toString();
      final parsedD = double.tryParse(t.replaceAll(',', '.'));
      if (parsedD != null) return parsedD.toInt().toString();
      return '0';
    }

    final peso = asDecimal(pesoCtrl.text);
    final estatura = asDecimal(estaturaCtrl.text);
    final imc = asDecimal(imcCtrl.text);
    final frecuenciaCardiaca = asInt(frecuenciaCardiacaCtrl.text);
    final frecuenciaRespiratoria = asInt(frecuenciaRespiratoriaCtrl.text);
    final temperatura = asDecimal(temperaturaCtrl.text);

    final data = {
      'paciente_id': pacienteId,
      'motivo': motivoCtrl.text,
      'diagnostico': diagnosticoCtrl.text,
      'tratamiento': tratamientoCtrl.text,
      'receta': recetaCtrl.text,
      'peso': peso,
      'estatura': estatura,
      'imc': imc,
      'presion': presionCtrl.text.trim(),
      'frecuencia_cardiaca': frecuenciaCardiaca,
      'frecuencia_respiratoria': frecuenciaRespiratoria,
      'temperatura': temperatura,
    };

    // Usar la fecha seleccionada por el usuario si existe, si no usar la actual.
    data['fecha'] = fechaCtrl.text.isNotEmpty
        ? fechaCtrl.text
        : DateTime.now().toIso8601String().split('T')[0];

    // Preparar listas de imágenes: enviar nuevas como archivos y
    // las existentes (si las hay) como campo 'imagenes' en formato JSON
    final nuevasPaths = nuevasImagenes.map((e) => e.path).toList();

    bool exito;
    if (widget.consulta == null) {
      exito = await ApiService.crearHistorial(data, nuevasPaths);
    } else {
      // Incluir imagenes existentes para que el backend las conserve
      data['imagenes'] = jsonEncode(imagenesExistentes);
      exito = await ApiService.editarHistorial(
          widget.consulta!.id, data, nuevasPaths);
    }

    setState(() => cargando = false);

    if (exito) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error al guardar')));
    }
  }

  Future<void> _pickImages() async {
    try {
      final imgs = await _picker.pickMultiImage(imageQuality: 80);
      if (imgs.isNotEmpty) {
        setState(() => nuevasImagenes.addAll(imgs));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionando imágenes: $e')));
    }
  }

  Widget _buildImagenesPreview() {
    final total = imagenesExistentes.length + nuevasImagenes.length;
    if (total == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          if (idx < imagenesExistentes.length) {
            final url = imagenesExistentes[idx];
            final display =
                url.startsWith('/') ? ApiService.baseUrl + url : url;
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(display,
                      width: 140, height: 100, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => imagenesExistentes.removeAt(idx));
                    },
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                )
              ],
            );
          } else {
            final nidx = idx - imagenesExistentes.length;
            final f = nuevasImagenes[nidx];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(f.path),
                      width: 140, height: 100, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => nuevasImagenes.removeAt(nidx)),
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                )
              ],
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.consulta == null ? "Nueva Consulta" : "Editar Consulta"),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Motivo'),
              Tab(text: 'Examen físico'),
              Tab(text: 'Diagnóstico'),
            ],
          ),
        ),
        body: cargando
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1 - Motivo
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: motivoCtrl,
                                  decoration: const InputDecoration(
                                      labelText: "Motivo"),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Ingrese motivo'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: recetaCtrl,
                                  decoration: const InputDecoration(
                                      labelText: "Receta"),
                                ),
                              ],
                            ),
                          ),

                          // Tab 2 - Examen físico
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: pesoCtrl,
                                        decoration: const InputDecoration(
                                            labelText: 'Peso (kg)'),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: estaturaCtrl,
                                        decoration: const InputDecoration(
                                            labelText: 'Estatura (m)'),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: imcCtrl,
                                        decoration: const InputDecoration(
                                            labelText: 'IMC'),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: presionCtrl,
                                        decoration: const InputDecoration(
                                            labelText: 'Presión'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: frecuenciaCardiacaCtrl,
                                        decoration: const InputDecoration(
                                            labelText: 'Frecuencia cardiaca'),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: frecuenciaRespiratoriaCtrl,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Frecuencia respiratoria'),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: temperaturaCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Temperatura (°C)'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              ],
                            ),
                          ),

                          // Tab 3 - Diagnóstico / Tratamiento / Imágenes
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: diagnosticoCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Diagnóstico'),
                                  maxLines: 4,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: tratamientoCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Tratamiento'),
                                  maxLines: 4,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _pickImages,
                                      icon: const Icon(Icons.photo_library),
                                      label: const Text('Agregar imágenes'),
                                    ),
                                    const SizedBox(width: 12),
                                    if (imagenesExistentes.isNotEmpty ||
                                        nuevasImagenes.isNotEmpty)
                                      Text(
                                          '${imagenesExistentes.length + nuevasImagenes.length} imágenes'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildImagenesPreview(),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: guardarConsulta,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12.0, horizontal: 24.0),
                                    child: Text(widget.consulta == null
                                        ? 'Guardar consulta'
                                        : 'Guardar cambios'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
