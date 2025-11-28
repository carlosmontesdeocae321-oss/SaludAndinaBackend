import 'package:flutter/material.dart';
import '../../services/api_services.dart';
import 'doctor_public_profile.dart';
import '../../route_observer.dart';
import '../../refresh_notifier.dart';

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> with RouteAware {
  bool loading = true;
  List<Map<String, dynamic>> doctors = [];
  // Full unfiltered user list (used to derive clinic-linked doctors/patients)
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> clinics = [];
  // Set of usuario IDs that were purchased/vinculados a una clínica
  Set<int> _purchasedDoctorUserIds = <int>{};
  // Set of user IDs that are owners (admin_id) of clinics
  Set<int> _clinicOwnerIds = <int>{};
  bool _isAuthenticated = false;
  final Map<int, bool> _detailsLoading = {};
  final Map<int, bool> _detailsFetched = {};
  final Map<int, Map<String, dynamic>> _clinicStats = {};
  final Map<int, bool> _clinicStatsLoading = {};

  @override
  void initState() {
    super.initState();
    _load();
    // Listen to global refresh events (e.g. after creating a doctor)
    globalRefreshNotifier.addListener(_onGlobalRefresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modal = ModalRoute.of(context);
    if (modal != null) {
      routeObserver.subscribe(this, modal);
    }
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    try {
      globalRefreshNotifier.removeListener(_onGlobalRefresh);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didPopNext() {
    // The screen became visible again (returned from another route)
    _load();
  }

  void _onGlobalRefresh() {
    // Debounce slightly by scheduling on next frame to avoid conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didPush() {
    // When first pushed - keep existing behavior (initState already calls _load)
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      _isAuthenticated = await ApiService.isAuthenticated();
      final d = await ApiService.obtenerUsuariosAdmin();
      // Si el backend no devuelve la lista ya ordenada, intentamos respetar
      // el flag `es_de_clinica` cuando esté presente para asegurar que los
      // usuarios de clínica/quienes son dueños queden al final.
      try {
        int flag(Map<String, dynamic> u) {
          final raw =
              u['es_de_clinica'] ?? u['esDeClinica'] ?? u['es_de_clinica'];
          if (raw == null) return 0;
          if (raw is int) return raw != 0 ? 1 : 0;
          if (raw is bool) return raw ? 1 : 0;
          if (raw is String) {
            final s = raw.toLowerCase().trim();
            if (s == '1' || s == 'true' || s == 'si' || s == 'yes') return 1;
            return 0;
          }
          return 0;
        }

        if (d.isNotEmpty) {
          try {
            d.sort((a, b) =>
                flag(Map<String, dynamic>.from(a)) -
                flag(Map<String, dynamic>.from(b)));
          } catch (_) {}
        }
      } catch (_) {}
      // keep a copy of the full user list (unfiltered) so we can compute
      // clinic-linked doctors/patient counts even when `doctors` is filtered
      try {
        _allUsers = d
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
        // Debug: print a sample of what the server returned so we can
        // verify fields used for sorting (clinica_id, dueno, es_de_clinica).
        try {} catch (_) {}
      } catch (_) {
        try {
          _allUsers = List<Map<String, dynamic>>.from(d);
        } catch (_) {
          _allUsers = <Map<String, dynamic>>[];
        }
      }
      final c = await ApiService.obtenerClinicasRaw();
      // Build a set of owner IDs from clinics so we can mark owners as clinic-linked
      final Set<int> ownerIds = <int>{};
      try {
        for (final clItem in c) {
          try {
            final map = clItem;
            final maybe = _asInt(map['admin_id'] ??
                map['adminId'] ??
                map['usuario_admin'] ??
                map['owner_id'] ??
                map['dueno_id'] ??
                map['admin'] ??
                map['owner']);
            if (maybe != null) ownerIds.add(maybe);
          } catch (_) {}
        }
      } catch (_) {}
      // Store owner ids in state so sorting logic can detect them
      _clinicOwnerIds = ownerIds;
      // Clear per-doctor detail caches so newly-fetched base list can re-trigger
      // detail fetches (otherwise _detailsFetched may prevent reloading fields).
      // Before building the visible `doctors` list, fetch purchased doctor
      // IDs for all clinics so we can differentiate linked vs created-by-clinic.
      final Set<int> purchasedIds = <int>{};
      try {
        for (final clItem in c) {
          try {
            final cid = _asInt(
                clItem['id'] ?? clItem['clinica_id'] ?? clItem['clinicaId']);
            if (cid == null) continue;
            final lista =
                await ApiService.obtenerUsuariosCompradosPorClinica(cid);
            for (final v in lista) {
              purchasedIds.add(v);
            }
          } catch (_) {}
        }
      } catch (_) {}
      _purchasedDoctorUserIds = purchasedIds;
      try {} catch (_) {}

      _detailsFetched.clear();
      _detailsLoading.clear();

      setState(() {
        // `d` is List<Map<String,dynamic>>; `c` is List<Clinica>
        // Include all doctor accounts (individual + vinculados). We'll show
        // the clinic in the tile subtitle if present. Build the visible
        // list first and then normalize/deduplicate + sort so that doctors
        // linked or created by a clinic appear at the end.
        final visible = d.where((u) {
          try {
            final roleRaw = (u['rol'] ?? u['role'] ?? u['roles']).toString();
            final r = roleRaw.toLowerCase();

            // Determine if this doctor is linked to a clinic and whether it was
            // created by the clinic. We only exclude doctors that are owners or
            // that are explicitly marked as created-by-clinic.
            final docClinicId = _clinicIdFromDoctor(u);
            // Nota: la detección de `isVinculado` se omitió intencionalmente
            // porque preferimos incluir aquí a todos los usuarios que tengan
            // `clinicaId` y dejar la lógica de ocultar owners/creados al
            // paso de merge/sort más abajo.

            // (Nota: la detección 'createdByClinic' no se usa aquí porque
            // ahora incluimos doctores creados por clínica en la lista visible
            // y los empujamos al final mediante _mergeAndSortDoctors.)

            // Basic exclusions first: exclude non-doctors only. Owners
            // (dueños) previously were excluded; now los incluimos en la
            // lista visible y los empujamos al final mediante el sorting.
            if (!r.contains('doctor')) {
              return false;
            }

            // If doctor is linked to a clinic, include them unless they're
            // explicitly created by the clinic. Preference order:
            // - if isVinculado == true -> include
            // - if isVinculado == false -> exclude
            // - if isVinculado == null (unknown) -> include unless isCreatedByClinic
            if (docClinicId != null) {
              // Si el perfil tiene `clinicaId`, lo incluimos en la lista visible.
              // No excluir aquí si `isVinculado` viene como `false` porque
              // queremos mostrar los doctores individuales que estén
              // vinculados a alguna clínica; la depuración/filtrado de
              // owners/creados-por-clínica se hace más abajo en el merge.
              return true;
            }

            // Individual doctor (no clinicId) -> include
            return true;
          } catch (_) {
            return false;
          }
        }).toList();
        // Normalize (merge duplicates) and ensure linked/clinic-created
        // doctors appear last in the final `doctors` list.
        doctors = _mergeAndSortDoctors(visible);
        clinics = c.map((raw) {
          final Map<String, dynamic> map = raw;
          return {
            'id':
                _asInt(map['id'] ?? map['clinica_id'] ?? map['clinicaId']) ?? 0,
            'nombre': map['nombre'] ?? map['name'] ?? '',
            'direccion': map['direccion'] ?? map['address'] ?? map['ubicacion'],
            'telefono_contacto': map['telefono_contacto'] ??
                map['telefono'] ??
                map['phone'] ??
                map['telefonoClinica'],
            'imagen_url': map['imagen_url'] ??
                map['imagenUrl'] ??
                map['imagen'] ??
                map['logo'] ??
                map['logo_url'],
            'pacientes': _asInt(map['pacientes'] ??
                map['pacientes_count'] ??
                map['patients'] ??
                map['patients_count']),
            'doctores': _asInt(map['doctores'] ??
                map['doctores_count'] ??
                map['doctors'] ??
                map['doctors_count']),
            'slots_total': _asInt(map['slots_total'] ??
                map['capacidad'] ??
                map['capacity'] ??
                map['limite_pacientes']),
          };
        }).toList();
      });
      // Debug: print samples to help diagnose why linked doctors may be hidden
      try {
        final linked =
            _allUsers.where((u) => _clinicIdFromDoctor(u) != null).toList();
        if (linked.isNotEmpty) {}
      } catch (e) {}
    } catch (_) {}
    setState(() => loading = false);
  }

  Widget _doctorTile(Map<String, dynamic> d, int index) {
    final name = d['nombre'] ?? d['usuario'] ?? d['name'] ?? 'Doctor';
    final id = d['id'] ?? d['userId'] ?? d['usuarioId'];
    // plan is intentionally not shown in the list tiles (kept in data for other uses)
    final clinic = d['clinica'] ??
        d['clinica_nombre'] ??
        d['clinic_name'] ??
        d['clinicaId'] ??
        d['clinica_id'];

    // attempt to resolve an avatar image for the tile
    final avatarRaw =
        d['avatar_url'] ?? d['avatar'] ?? d['photo_url'] ?? d['imagen'];
    String? avatarUrl;
    try {
      if (avatarRaw != null) {
        String s = avatarRaw.toString();
        if (s.startsWith('http') || s.startsWith('https')) {
          avatarUrl = s;
        } else if (s.startsWith('/')) {
          avatarUrl = ApiService.baseUrl + s;
        } else if (s.startsWith('file://')) {
          avatarUrl = s.replaceFirst('file://', '');
        } else {
          avatarUrl = ApiService.baseUrl + (s.startsWith('/') ? '' : '/') + s;
        }
      }
    } catch (_) {
      avatarUrl = null;
    }

    // Resolve clinic name from `clinics` if clinic is an id
    String? clinicName;
    try {
      if (clinic != null) {
        if (clinic is int) {
          final found =
              clinics.firstWhere((c) => c['id'] == clinic, orElse: () => {});
          if (found.isNotEmpty) clinicName = found['nombre']?.toString();
        } else if (clinic is String && int.tryParse(clinic) != null) {
          final cid = int.parse(clinic);
          final found =
              clinics.firstWhere((c) => c['id'] == cid, orElse: () => {});
          if (found.isNotEmpty) clinicName = found['nombre']?.toString();
        } else {
          clinicName = clinic.toString();
        }
      }
    } catch (_) {}

    // Resolve patient count from several possible keys
    final patientCount = d['totalPacientes'] ??
        d['patients'] ??
        d['total_pacientes'] ??
        d['pacientes'] ??
        d['total'] ??
        d['totalPatients'];
    final specialty =
        d['especialidad'] ?? d['especialidades'] ?? d['specialty'];

    final idInt = id is int ? id : int.tryParse(id?.toString() ?? '');
    if (idInt != null && (patientCount == null || specialty == null)) {
      _ensureDetails(idInt, index);
    }

    final chipElements = <Widget>[
      _buildInfoChip(Icons.badge_outlined, _formatSpecialtyForTile(specialty)),
      _buildInfoChip(
          Icons.people_alt_outlined, 'Pacientes: ${patientCount ?? '-'}'),
    ];
    // Badge visual: mostrar si el doctor está asociado a una clínica o es dueño
    bool isClinicUser = false;
    bool isOwner = false;
    try {
      final esDeClinicaRaw =
          d['es_de_clinica'] ?? d['esDeClinica'] ?? d['es_de_clinica'];
      if (esDeClinicaRaw != null) {
        if (esDeClinicaRaw is int && esDeClinicaRaw != 0) isClinicUser = true;
        if (esDeClinicaRaw is String) {
          final s = esDeClinicaRaw.toLowerCase().trim();
          if (s == '1' || s == 'true' || s == 'si' || s == 'yes') {
            isClinicUser = true;
          }
        }
      }
      if (!isClinicUser) {
        if (_clinicIdFromDoctor(d) != null) isClinicUser = true;
      }
      final ownerRaw =
          d['dueno'] ?? d['es_dueno'] ?? d['owner'] ?? d['is_owner'];
      if (ownerRaw != null) {
        if (ownerRaw is bool && ownerRaw == true) isOwner = true;
        if (ownerRaw is int && ownerRaw != 0) isOwner = true;
        if (ownerRaw is String) {
          final s = ownerRaw.toLowerCase().trim();
          if (s == '1' || s == 'true' || s == 'si' || s == 'yes') {
            isOwner = true;
          }
        }
      }
    } catch (_) {}
    if (isClinicUser || isOwner) {
      final label = isOwner ? 'Dueño · Clínica' : 'Clínica';
      chipElements.insert(0, _buildInfoChip(Icons.apartment_outlined, label));
    }
    if (clinicName != null && clinicName.isNotEmpty) {
      chipElements.insert(
          0, _buildInfoChip(Icons.local_hospital_outlined, clinicName));
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (idInt == null) return;
          showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                    content: FutureBuilder<Map<String, dynamic>?>(
                      future: _fetchProfileForPreview(idInt),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const SizedBox(
                              height: 120,
                              child:
                                  Center(child: CircularProgressIndicator()));
                        }
                        final p = snap.data;
                        if (p == null) {
                          return const Text('No se pudo cargar el perfil');
                        }
                        final displayName = p['nombre'] ??
                            p['usuario'] ??
                            p['name'] ??
                            'Doctor';
                        final specialty =
                            p['especialidad'] ?? p['especialidad_medica'] ?? '';
                        final email = p['email'] ?? p['correo'] ?? '';
                        final avatarRaw =
                            p['avatar_url'] ?? p['avatar'] ?? p['photo_url'];
                        String? avatar;
                        if (avatarRaw != null &&
                            avatarRaw.toString().isNotEmpty) {
                          final s = avatarRaw.toString();
                          if (s.startsWith('http')) {
                            avatar = s;
                          } else {
                            const prefix = ApiService.baseUrl;
                            avatar =
                                prefix + (s.startsWith('/') ? '' : '/') + s;
                          }
                        }
                        final clinicName = p['clinica'] ??
                            p['clinica_nombre'] ??
                            p['clinic_name'];

                        return SizedBox(
                          width: 340,
                          child: Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  if (avatar != null && avatar.isNotEmpty)
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey[200],
                                      ),
                                      child: ClipOval(
                                        child: Image.network(
                                          avatar,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.person,
                                                  size: 32),
                                        ),
                                      ),
                                    )
                                  else
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundColor: Colors.grey[200],
                                      child: const Icon(Icons.person, size: 32),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(displayName.toString(),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        if (specialty != null &&
                                            specialty.toString().isNotEmpty)
                                          Text(specialty.toString(),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700])),
                                        const SizedBox(height: 6),
                                        if (clinicName != null &&
                                            clinicName.toString().isNotEmpty)
                                          Text(
                                              'Clínica: ${clinicName.toString()}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600])),
                                        const SizedBox(height: 6),
                                        if (email != null &&
                                            email.toString().isNotEmpty)
                                          Row(
                                            children: [
                                              const Icon(Icons.email,
                                                  size: 14, color: Colors.grey),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(email.toString(),
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors.grey[600])),
                                              ),
                                            ],
                                          ),
                                        if (p['telefono'] != null &&
                                            p['telefono'].toString().isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6.0),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.phone,
                                                    size: 14,
                                                    color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text(p['telefono'].toString(),
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors.grey[600])),
                                              ],
                                            ),
                                          ),
                                        if (p['bio'] != null &&
                                            p['bio'].toString().isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              p['bio'].toString(),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700]),
                                            ),
                                          ),
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              try {
                                                Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            DoctorPublicProfile(
                                                                doctorId:
                                                                    idInt)));
                                              } catch (_) {}
                                            },
                                            child: const Text(
                                                'Ver perfil completo'),
                                          ),
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cerrar'))
                    ],
                  ));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.toString(),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('ID: ${id ?? '-'}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chipElements,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl) {
    if (avatarUrl == null) {
      return const CircleAvatar(radius: 26, child: Icon(Icons.person));
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[200],
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.person),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.35),
      labelStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      avatar: CircleAvatar(
        radius: 12,
        backgroundColor: Colors.transparent,
        child: Icon(icon, size: 16, color: scheme.primary),
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<void> _ensureClinicStats(int clinicId) async {
    if (!mounted) return;
    if (_clinicStatsLoading[clinicId] == true) return;

    setState(() {
      _clinicStatsLoading[clinicId] = true;
    });

    Map<String, dynamic> stats = {};
    try {
      final response = await ApiService.obtenerEstadisticasClinica(clinicId);
      if (response != null) {
        stats = Map<String, dynamic>.from(response);
      }
    } catch (_) {}

    final clinicSnapshot = clinics.firstWhere(
      (c) => _asInt(c['id']) == clinicId,
      orElse: () => <String, dynamic>{},
    );

    final Map<String, dynamic> statsClinic =
        stats['clinic'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(stats['clinic'])
            : <String, dynamic>{};

    void mergeInto(Map<String, dynamic> target, Map<String, dynamic> source) {
      source.forEach((key, value) {
        if (value == null) return;
        final str = value.toString();
        if (str.trim().isEmpty) return;
        target.putIfAbsent(key, () => value);
      });
    }

    final mergedClinic = <String, dynamic>{};
    mergeInto(mergedClinic, clinicSnapshot);
    mergeInto(mergedClinic, statsClinic);

    // Debug: report sizes/sample for diagnosis (prints removed)
    try {} catch (_) {}

    final doctorCount = _countDoctorsForClinic(clinicId);
    if (doctorCount != null) {
      stats['doctors'] = doctorCount;
      mergedClinic.putIfAbsent('doctores', () => doctorCount);
    }

    final patientCount = _derivePatientCountForClinic(clinicId, mergedClinic);
    if (patientCount != null) {
      stats['patients'] = patientCount;
      mergedClinic.putIfAbsent('pacientes', () => patientCount);
    }

    // If we couldn't derive patient count from doctor profiles, try deriving
    // it from appointments (unique pacienteId per clinic) as a fallback.
    int existingPatients = 0;
    try {
      existingPatients = _asInt(stats['patients']) ?? 0;
    } catch (_) {
      existingPatients = 0;
    }

    if (existingPatients == 0) {
      try {
        final allCitas = await ApiService.obtenerCitas();

        final pacientes = <String>{};
        // doctor IDs that belong to this clinic
        final clinicDoctorIds = <int>{};
        for (final u in _allUsers) {
          try {
            final did = _asInt(
                u['id'] ?? u['userId'] ?? u['usuarioId'] ?? u['usuario_id']);
            if (did != null && _clinicIdFromDoctor(u) == clinicId) {
              clinicDoctorIds.add(did);
            }
          } catch (_) {}
        }

        if (allCitas.isNotEmpty) {
          try {} catch (_) {}
        }

        for (final c in allCitas) {
          try {
            if ((c.clinicaId != null && c.clinicaId == clinicId) ||
                (c.doctorId != null && clinicDoctorIds.contains(c.doctorId!))) {
              pacientes.add(c.pacienteId);
            }
          } catch (_) {}
        }

        if (pacientes.isNotEmpty) {
          stats['patients'] = pacientes.length;
          mergedClinic.putIfAbsent('pacientes', () => pacientes.length);
        }
      } catch (e) {}
    }

    final capacity = _asInt(
      stats['slots_total'] ??
          stats['capacidad'] ??
          mergedClinic['slots_total'] ??
          mergedClinic['capacidad'],
    );
    if (capacity != null) {
      stats['slots_total'] = capacity;
      mergedClinic.putIfAbsent('slots_total', () => capacity);
      final available =
          stats['availablePatients'] ?? stats['pacientes_disponibles'];
      if (available == null && patientCount != null) {
        stats['availablePatients'] = capacity - patientCount;
      }
    }

    if (mergedClinic.isNotEmpty) {
      stats['clinic'] = mergedClinic;
    }

    if (!mounted) return;
    setState(() {
      _clinicStats[clinicId] = stats;
      _clinicStatsLoading[clinicId] = false;
    });
  }

  void _refreshClinicStats(int clinicId) {
    if (!mounted) return;
    setState(() {
      _clinicStats.remove(clinicId);
      _clinicStatsLoading.remove(clinicId);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureClinicStats(clinicId);
    });
  }

  Widget _buildClinicImage(String? imageUrl) {
    final borderRadius = BorderRadius.circular(16);
    Widget placeholder() => Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          ),
          child: Icon(
            Icons.local_hospital,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
        );

    if (imageUrl == null) {
      return placeholder();
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        imageUrl,
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      ),
    );
  }

  Widget _buildClinicStatChip(IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      backgroundColor: scheme.primary.withOpacity(0.08),
      avatar: Icon(icon, size: 16, color: scheme.primary),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: scheme.onSurface),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String? _resolveClinicImage(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) {
      return '${ApiService.baseUrl}$raw';
    }
    final path = raw.startsWith('uploads') ? raw : 'uploads/clinicas/$raw';
    return '${ApiService.baseUrl}/$path';
  }

  String _formatCount(dynamic value) {
    final intValue = _asInt(value);
    if (intValue != null) return intValue.toString();
    if (value == null) return '-';
    final str = value.toString().trim();
    return str.isEmpty ? '-' : str;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      if (value.trim().isEmpty) return null;
      return int.tryParse(value.trim());
    }
    return int.tryParse(value.toString());
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  int? _countDoctorsForClinic(int clinicId) {
    try {
      // Count using the full unfiltered user list so clinic-linked doctors
      // (which may have been filtered out of `doctors`) are still counted.
      final count = _allUsers.where((doc) {
        final docClinicId = _clinicIdFromDoctor(doc);
        return docClinicId != null && docClinicId == clinicId;
      }).length;
      return count == 0 ? null : count;
    } catch (_) {
      return null;
    }
  }

  int? _derivePatientCountForClinic(int clinicId, Map<String, dynamic> clinic) {
    final direct = _asInt(
      clinic['pacientes'] ??
          clinic['patients'] ??
          clinic['pacientes_count'] ??
          clinic['patients_count'],
    );
    if (direct != null) return direct;

    final candidates = <int>{};
    // Check both the full user list and the currently displayed `doctors`
    // because some profiles may have been enriched with patient counts
    // after fetching details.
    final Iterable<Map<String, dynamic>> sources =
        List<Map<String, dynamic>>.from(_allUsers)..addAll(doctors);
    for (final doc in sources) {
      final docClinicId = _clinicIdFromDoctor(doc);
      if (docClinicId == null || docClinicId != clinicId) continue;
      final values = [
        doc['totalPacientes'],
        doc['total_pacientes'],
        doc['pacientes'],
        doc['patients'],
      ];
      for (final v in values) {
        final parsed = _asInt(v);
        if (parsed != null) candidates.add(parsed);
      }
    }

    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a > b ? a : b);
  }

  int? _clinicIdFromDoctor(Map<String, dynamic> doctor) {
    final raw = doctor['clinica'] ??
        doctor['clinica_id'] ??
        doctor['clinicaId'] ??
        doctor['clinic_id'];
    return _asInt(raw);
  }

  // Merge duplicate doctor entries (by user id when available) and sort so
  // that doctors linked to a clinic or created-by-clinic appear at the end
  // of the visible list. This keeps individual doctors first for users.
  List<Map<String, dynamic>> _mergeAndSortDoctors(Iterable<dynamic> items) {
    final Map<int, Map<String, dynamic>> byId = {};
    final List<Map<String, dynamic>> noId = [];

    for (final raw in items) {
      try {
        final Map<String, dynamic> u = raw is Map<String, dynamic>
            ? Map<String, dynamic>.from(raw)
            : Map<String, dynamic>.from(raw as Map);

        final idVal = u['id'] ??
            u['userId'] ??
            u['usuarioId'] ??
            u['usuario_id'] ??
            u['user_id'];
        final idInt = _asInt(idVal);
        if (idInt != null) {
          if (!byId.containsKey(idInt)) {
            byId[idInt] = u;
          } else {
            final base = byId[idInt]!;
            // merge fields: prefer existing non-empty values, otherwise take new
            for (final entry in u.entries) {
              final k = entry.key;
              final v = entry.value;
              if (v == null) continue;
              final existing = base[k];
              final existingStr = existing?.toString().trim() ?? '';
              if (existing == null || existingStr.isEmpty) {
                base[k] = v;
              }
            }
          }
        } else {
          noId.add(u);
        }
      } catch (_) {}
    }

    final merged = <Map<String, dynamic>>[];
    merged.addAll(byId.values);
    merged.addAll(noId);

    // Only treat owners and doctors created by a clinic as items to be
    // filtered out (not shown). We intentionally keep "vinculados"/
    // purchased doctors visible unless they also match one of these flags.
    bool isOwnerOrCreatedByClinic(Map<String, dynamic> u) {
      try {
        // Owner detection: explicit owner flag or role text or known owner ids
        final ownerRaw =
            u['dueno'] ?? u['es_dueno'] ?? u['owner'] ?? u['is_owner'];
        bool isOwnerFlag = false;
        if (ownerRaw is bool && ownerRaw == true) isOwnerFlag = true;
        if (ownerRaw is int && ownerRaw != 0) isOwnerFlag = true;
        if (ownerRaw is String) {
          final s = ownerRaw.toLowerCase().trim();
          if (s == '1' || s == 'true' || s == 'si' || s == 'yes') {
            isOwnerFlag = true;
          }
        }
        try {
          final roleRaw =
              (u['rol'] ?? u['role'] ?? u['roles'])?.toString() ?? '';
          final rl = roleRaw.toLowerCase();
          if (rl.contains('dueno') ||
              rl.contains('owner') ||
              rl.contains('dueño')) isOwnerFlag = true;
        } catch (_) {}
        final idVal = u['id'] ??
            u['userId'] ??
            u['usuarioId'] ??
            u['usuario_id'] ??
            u['user_id'];
        final idInt = _asInt(idVal);
        if (isOwnerFlag) return true;
        if (idInt != null && _clinicOwnerIds.contains(idInt)) return true;

        // Created-by-clinic detection: explicit server flags like
        // `creado_por_clinica` or `createdByClinic`. We DO NOT treat
        // `es_de_clinica` as 'created-by-clinic' here because that flag is
        // used by the backend in some cases for purchased/vinculated
        // doctors — we want purchased doctors to remain visible.
        final createdFlags = [
          u['creado_por_clinica'],
          u['createdByClinic'],
          u['created_by_clinic'],
          u['creado_por'],
          u['created_by']
        ];
        for (final cf in createdFlags) {
          if (cf == null) continue;
          if (cf is bool && cf) return true;
          if (cf is int && cf != 0) return true;
          if (cf is String) {
            final s = cf.toLowerCase().trim();
            if (s == 'clinica' ||
                s == 'created_by_clinic' ||
                s == 'true' ||
                s == '1' ||
                s == 'si' ||
                s == 'yes') return true;
          }
        }
      } catch (_) {}
      return false;
    }

    // DEBUG: print merged entries and key flags to diagnose ordering issues
    try {} catch (_) {}

    // Filter out owners and doctors created by a clinic. Keep other
    // clinic-linked/purchased doctors visible (unless they match
    // the owner/created criteria above).
    final List<Map<String, dynamic>> kept = [];
    final List<Map<String, dynamic>> removed = [];
    for (final u in merged) {
      try {
        if (isOwnerOrCreatedByClinic(u)) {
          removed.add(u);
        } else {
          kept.add(u);
        }
      } catch (_) {
        kept.add(u);
      }
    }

    String nameKey(Map<String, dynamic> u) {
      final n = u['nombre'] ?? u['usuario'] ?? u['name'] ?? '';
      return n?.toString().toLowerCase() ?? '';
    }

    // Partition kept into individual doctors (no clinic) first and linked
    // doctors (assigned/vinculados) after, then sort alphabetically within
    // each group.
    final individuals = <Map<String, dynamic>>[];
    final linked = <Map<String, dynamic>>[];
    for (final u in kept) {
      try {
        final clinicId = _clinicIdFromDoctor(u);
        // Treat as linked only when a clinic id is present on the profile.
        // Ignore the purchased list here so a user who removed the link
        // (clinicaId == null) becomes an individual immediately.
        if (clinicId != null) {
          linked.add(u);
        } else {
          individuals.add(u);
        }
      } catch (_) {
        individuals.add(u);
      }
    }

    try {
      individuals.sort((a, b) => nameKey(a).compareTo(nameKey(b)));
      linked.sort((a, b) => nameKey(a).compareTo(nameKey(b)));
    } catch (_) {}

    try {} catch (_) {}

    return [...individuals, ...linked];
  }

  Future<void> _ensureDetails(int doctorId, int index) async {
    if (_detailsLoading[doctorId] == true) return;
    if (_detailsFetched[doctorId] == true) return;
    _detailsLoading[doctorId] = true;
    try {
      Map<String, dynamic>? data;
      if (_isAuthenticated) {
        final resp = await ApiService.obtenerPerfilDoctor(doctorId);
        if ((resp['ok'] ?? false) == true &&
            resp['data'] is Map<String, dynamic>) {
          data = Map<String, dynamic>.from(resp['data']);
        }
      } else {
        data = await ApiService.obtenerPerfilDoctorPublic(doctorId);
      }

      if (data != null) {
        final normalized = <String, dynamic>{};
        final spec = _extractSpecialtyFromMap(data);
        if (spec != null) normalized['especialidad'] = spec;
        final patients = _extractPatientCountFromMap(data);
        if (patients != null) normalized['totalPacientes'] = patients;

        setState(() {
          final base = <String, dynamic>{...doctors[index]};
          // Avoid overwriting primary identifier fields returned by the
          // profile endpoint (some DB models use a different `id` for the
          // profile row). Preserve the original user id fields and only
          // merge other profile fields.
          for (final entry in data!.entries) {
            final k = entry.key;
            if (k == 'id' ||
                k == 'userId' ||
                k == 'usuarioId' ||
                k == 'usuario_id' ||
                k == 'user_id') {
              // skip identifier fields to avoid replacing the main user id
              continue;
            }
            base[k] = entry.value;
          }
          // Merge normalized extracted fields (especialidad, totalPacientes)
          base.addAll(normalized);
          doctors[index] = base;
        });
      }
    } catch (_) {}
    _detailsLoading[doctorId] = false;
    _detailsFetched[doctorId] = true;
  }

  String _formatSpecialtyForTile(dynamic sp) {
    if (sp == null) return '-';
    try {
      if (sp is List) {
        return sp
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .join(', ');
      }
      final s = sp.toString();
      if (s.contains(',')) return s.split(',').map((e) => e.trim()).join(', ');
      return s.isNotEmpty ? s : '-';
    } catch (_) {
      return sp.toString();
    }
  }

  String? _extractSpecialtyFromMap(Map<String, dynamic> map) {
    try {
      for (final entry in map.entries) {
        final key = entry.key.toLowerCase();
        final val = entry.value;
        if (val == null) continue;
        if (key.contains('especial') || key.contains('special')) {
          if (val is String && val.trim().isNotEmpty) return val;
          if (val is List) {
            final list = val
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList();
            if (list.isNotEmpty) return list.join(', ');
          }
        }
        if (val is Map<String, dynamic>) {
          final nested = _extractSpecialtyFromMap(val);
          if (nested != null) return nested;
        }
        if (val is List) {
          for (final item in val) {
            if (item is Map<String, dynamic>) {
              final nested = _extractSpecialtyFromMap(item);
              if (nested != null) return nested;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  int? _extractPatientCountFromMap(Map<String, dynamic> map) {
    try {
      for (final entry in map.entries) {
        final key = entry.key.toLowerCase();
        final val = entry.value;
        if (val == null) continue;
        if (key.contains('pacient') ||
            key.contains('patient') ||
            key.contains('total')) {
          if (val is int) return val;
          if (val is double) return val.round();
          if (val is String) {
            final parsed = int.tryParse(val);
            if (parsed != null) return parsed;
          }
        }
        if (val is Map<String, dynamic>) {
          final nested = _extractPatientCountFromMap(val);
          if (nested != null) return nested;
        }
        if (val is List) {
          for (final item in val) {
            if (item is Map<String, dynamic>) {
              final nested = _extractPatientCountFromMap(item);
              if (nested != null) return nested;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // Helper to fetch profile for preview: returns Map or null. Uses public endpoint when unauthenticated.
  Future<Map<String, dynamic>?> _fetchProfileForPreview(int id) async {
    try {
      final auth = await ApiService.isAuthenticated();
      if (auth) {
        final resp = await ApiService.obtenerPerfilDoctor(id);
        if ((resp['ok'] ?? false) == true) {
          final data = resp['data'];
          if (data is Map<String, dynamic>) {
            return Map<String, dynamic>.from(data);
          }
        }
        return null;
      } else {
        return await ApiService.obtenerPerfilDoctorPublic(id);
      }
    } catch (_) {
      return null;
    }
  }

  Widget _clinicTile(Map<String, dynamic> clinic) {
    final rawId = _asInt(clinic['id']);
    final clinicId = rawId != null && rawId > 0 ? rawId : null;
    if (clinicId != null &&
        !_clinicStats.containsKey(clinicId) &&
        !(_clinicStatsLoading[clinicId] ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureClinicStats(clinicId);
      });
    }

    final stats = clinicId != null ? _clinicStats[clinicId] : null;
    final statsClinic = stats != null && stats['clinic'] is Map
        ? Map<String, dynamic>.from(stats['clinic'] as Map)
        : null;

    final merged = <String, dynamic>{};
    void merge(Map<String, dynamic>? source) {
      if (source == null) return;
      source.forEach((key, value) {
        if (value == null) return;
        final str = value.toString();
        if (str.trim().isEmpty) return;
        merged[key] = value;
      });
    }

    merge(clinic);
    merge(statsClinic);

    final name =
        _asString(merged['nombre'] ?? merged['name']) ?? 'Clínica sin nombre';
    final direccion = _asString(merged['direccion'] ?? merged['address']);
    final telefono = _asString(
      merged['telefono_contacto'] ??
          merged['telefono'] ??
          merged['phone'] ??
          merged['telefonoClinica'],
    );
    final imageUrl = _resolveClinicImage(
      merged['imagen_url'] ??
          merged['imagenUrl'] ??
          merged['logo'] ??
          merged['imagen'],
    );

    final doctorCount =
        stats?['doctors'] ?? merged['doctores'] ?? merged['doctors'];
    final patientCount =
        stats?['patients'] ?? merged['pacientes'] ?? merged['patients'];
    final capacity = stats?['slots_total'] ??
        stats?['capacidad'] ??
        merged['slots_total'] ??
        merged['capacidad'];
    final available =
        stats?['availablePatients'] ?? stats?['pacientes_disponibles'];
    final appointmentsToday = stats?['appointments_today'] ??
        stats?['citas_hoy'] ??
        stats?['appointmentsToday'];

    final loadingStats =
        clinicId != null && (_clinicStatsLoading[clinicId] ?? false);

    // Resolve counts: prefer server stats, then merged values, then local derivation
    final resolvedDoctorCount = doctorCount ??
        (clinicId != null ? _countDoctorsForClinic(clinicId) : null);
    final resolvedPatientCount = patientCount ??
        (clinicId != null
            ? _derivePatientCountForClinic(clinicId, merged)
            : null);

    String patientLabel;
    if (resolvedPatientCount != null) {
      patientLabel = 'Pacientes: ${_formatCount(resolvedPatientCount)}';
    } else if (!_isAuthenticated) {
      patientLabel = 'Pacientes: Inicia sesión';
    } else {
      patientLabel = 'Pacientes: ${_formatCount(resolvedPatientCount)}';
    }

    final chips = <Widget>[
      _buildClinicStatChip(Icons.people_alt_outlined, patientLabel),
      _buildClinicStatChip(Icons.medical_information_outlined,
          'Doctores: ${_formatCount(resolvedDoctorCount)}'),
    ];

    if (capacity != null) {
      final capacityLabel = available != null
          ? 'Capacidad: ${_formatCount(capacity)} · Disponibles: ${_formatCount(available)}'
          : 'Capacidad: ${_formatCount(capacity)}';
      chips.add(
        _buildClinicStatChip(Icons.apartment_outlined, capacityLabel),
      );
    }

    if (appointmentsToday != null) {
      chips.add(
        _buildClinicStatChip(Icons.event_available_outlined,
            'Citas hoy: ${_formatCount(appointmentsToday)}'),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showClinicDoctorsDialog(clinic),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClinicImage(imageUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (clinicId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'ID: $clinicId',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.8),
                              ),
                            ),
                          ),
                        if (direccion != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_pin,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    direccion,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (telefono != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.phone,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  telefono,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
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
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ],
              if (loadingStats) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Calculando estadísticas...'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showClinicDoctorsDialog(Map<String, dynamic> clinic) {
    final rawId = _asInt(clinic['id']);
    final clinicId = rawId != null && rawId > 0 ? rawId : null;

    // Find doctors that belong to this clinic (vinculados o creados)
    final linkedDoctors = <Map<String, dynamic>>[];
    if (clinicId != null) {
      for (final d in _allUsers) {
        try {
          final docClinicId = _clinicIdFromDoctor(d);
          if (docClinicId != null && docClinicId == clinicId) {
            linkedDoctors.add(d);
          }
        } catch (_) {}
      }
    }

    final clinicPatientsCount = clinic['pacientes'] ??
        clinic['patients'] ??
        clinic['pacientes_count'] ??
        clinic['patients_count'];
    final resolvedPatientCount = clinicPatientsCount ??
        (clinicId != null
            ? _derivePatientCountForClinic(clinicId, clinic)
            : null);
    final patientCountLabel = _formatCount(resolvedPatientCount);
    final doctorCountLabel = linkedDoctors.isEmpty
        ? (clinicId != null
            ? (_countDoctorsForClinic(clinicId)?.toString() ?? '-')
            : '-')
        : linkedDoctors.length.toString();

    showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title:
                Text(_asString(clinic['nombre']) ?? 'Doctores de la clínica'),
            content: SizedBox(
              width: 360,
              height: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                        'Pacientes: $patientCountLabel · Doctores: $doctorCountLabel',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodySmall?.color)),
                  ),
                  Expanded(
                    child: linkedDoctors.isEmpty
                        ? Center(
                            child: Text(clinicId == null
                                ? 'ID de clínica no disponible'
                                : 'No hay doctores vinculados a esta clínica.'),
                          )
                        : ListView.separated(
                            itemCount: linkedDoctors.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final doc = linkedDoctors[i];
                              final name = doc['nombre'] ??
                                  doc['usuario'] ??
                                  doc['name'] ??
                                  'Doctor';
                              final id = doc['id'] ??
                                  doc['userId'] ??
                                  doc['usuarioId'] ??
                                  doc['usuario_id'];
                              return ListTile(
                                title: Text(name.toString()),
                                subtitle: Text('ID: ${id ?? '-'}'),
                                dense: true,
                              );
                            },
                          ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'))
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Doctores y Clínicas'),
          bottom: const TabBar(
              tabs: [Tab(text: 'Doctores'), Tab(text: 'Clínicas')]),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  doctors.isEmpty
                      ? const Center(child: Text('No se encontraron doctores'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            itemBuilder: (_, i) => _doctorTile(doctors[i], i),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemCount: doctors.length,
                          ),
                        ),
                  clinics.isEmpty
                      ? const Center(child: Text('No se encontraron clínicas'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            itemCount: clinics.length,
                            itemBuilder: (_, i) => _clinicTile(clinics[i]),
                          ),
                        ),
                ],
              ),
      ),
    );
  }
}
