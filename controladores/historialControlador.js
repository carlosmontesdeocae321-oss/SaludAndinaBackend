const historialModelo = require('../modelos/historialModelo');
const path = require('path');
const fs = require('fs');
const os = require('os');

async function listarHistorial(req, res) {
    try {
        if (req.clinica_id === null && req.user && req.user.rol === 'doctor') {
            const registros = await historialModelo.obtenerHistorialPorDoctor(req.user.id);
            // Filter imagenes arrays for existing files
            for (const r of registros) {
                try {
                    if (Array.isArray(r.imagenes)) {
                        r.imagenes = r.imagenes.filter(img => {
                            if (!img) return false;
                            const rel = img.startsWith('/') ? img.slice(1) : img;
                            const full = path.join(__dirname, '..', rel);
                            const ok = fs.existsSync(full);
                            if (!ok) console.warn('Historial imagen faltante:', full);
                            return ok;
                        });
                    }
                } catch (e) {
                    // ignore
                }
            }
            return res.json(registros);
        }
        const registros = await historialModelo.obtenerHistorialPorClinica(req.clinica_id);
        for (const r of registros) {
            try {
                if (Array.isArray(r.imagenes)) {
                    r.imagenes = r.imagenes.filter(img => {
                        if (!img) return false;
                        const rel = img.startsWith('/') ? img.slice(1) : img;
                        const full = path.join(__dirname, '..', rel);
                        const ok = fs.existsSync(full);
                        if (!ok) console.warn('Historial imagen faltante:', full);
                        return ok;
                    });
                }
            } catch (e) {}
        }
        res.json(registros);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function listarHistorialPorPaciente(req, res) {
    try {
        const pacienteId = req.params.id;
        const registros = await historialModelo.obtenerHistorialPorPaciente(pacienteId);
        res.json(registros);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function verHistorial(req, res) {
    try {
        const registro = await historialModelo.obtenerHistorialPorId(req.params.id, req.clinica_id);
        if (!registro) return res.status(404).json({ message: 'Registro no encontrado' });
        if (req.clinica_id === null && req.user && req.user.rol === 'doctor') {
            if (registro.doctor_id && registro.doctor_id !== req.user.id) {
                return res.status(403).json({ message: 'Acceso no permitido' });
            }
        }
        // Filter registro.imagenes for existing files
        try {
            if (Array.isArray(registro.imagenes)) {
                registro.imagenes = registro.imagenes.filter(img => {
                    if (!img) return false;
                    const rel = img.startsWith('/') ? img.slice(1) : img;
                    const full = path.join(__dirname, '..', rel);
                    const ok = fs.existsSync(full);
                    if (!ok) console.warn('Historial imagen faltante (ver):', full);
                    return ok;
                });
            }
        } catch (e) {}

        res.json(registro);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function crearHistorial(req, res) {
    try {
        // Depuración: imprimir body y files
        console.log('🔔 crearHistorial - req.body:', req.body);
        console.log('🔔 crearHistorial - files:', (req.files || []).length);

        // Si se subieron archivos con multer, construir array de rutas públicas
        const files = req.files || [];
        const imagenes = [];
        // Attempt to move files from tmp to uploads/historial. If move fails, fall back to /uploads/tmp
        for (const f of files) {
            const tmpFull = f.path; // path on disk (in tmp)
            const uploadsDir = path.join(__dirname, '..', 'uploads', 'historial');
            try {
                if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });
                const destFull = path.join(uploadsDir, f.filename);
                try {
                    fs.renameSync(tmpFull, destFull);
                    imagenes.push('/uploads/historial/' + f.filename);
                    continue;
                } catch (e) {
                    // rename failed, try copy
                    try {
                        const data = fs.readFileSync(tmpFull);
                        fs.writeFileSync(destFull, data);
                        try { fs.unlinkSync(tmpFull); } catch (_) {}
                        imagenes.push('/uploads/historial/' + f.filename);
                        continue;
                    } catch (ee) {
                        console.warn('Could not move upload to uploads/historial, keeping in tmp:', ee);
                    }
                }
            } catch (e) {
                console.warn('Uploads dir not writable or creation failed:', e);
            }
            // Fallback: keep in tmp and expose via /uploads/tmp
            const basename = path.basename(f.path);
            imagenes.push('/uploads/tmp/' + basename);
        }

        // req.body contiene los campos de texto (multer los conserva)
        const payload = Object.assign({}, req.body);
        // Normalizar nombres: si cliente usó 'motivo' o 'motivo_consulta'
        if (payload.motivo && !payload.motivo_consulta) payload.motivo_consulta = payload.motivo;
        // Asegurar campos numéricos/strings estén presentes; imagenes como array
        payload.imagenes = imagenes;

        console.log('🔔 crearHistorial - payload final para BD:', payload);

        const nuevoId = await historialModelo.crearHistorial(payload);
        console.log('🔔 crearHistorial - insertId:', nuevoId);
        res.status(201).json({ id: nuevoId });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function actualizarHistorial(req, res) {
    try {
        console.log('🔔 actualizarHistorial - req.body:', req.body);
        console.log('🔔 actualizarHistorial - files:', (req.files || []).length);

        const files = req.files || [];
        const imagenesNuevas = files.map(f => '/uploads/historial/' + f.filename);

        const body = Object.assign({}, req.body);
        if (body.motivo && !body.motivo_consulta) body.motivo_consulta = body.motivo;

        // Si el cliente envió imagenes existentes en body.imagenes (JSON), concatenarlas
        let imagenesExistentes = [];
        if (body.imagenes) {
            try {
                imagenesExistentes = typeof body.imagenes === 'string' ? JSON.parse(body.imagenes) : body.imagenes;
            } catch (e) {
                imagenesExistentes = [];
            }
        }
        body.imagenes = [...imagenesExistentes, ...imagenesNuevas];

        console.log('🔔 actualizarHistorial - payload final:', body);

        const doctor_id = req.user && req.user.rol === 'doctor' ? req.user.id : null;
        const filas = await historialModelo.actualizarHistorial(req.params.id, body, req.clinica_id, doctor_id);
        if (filas === 0) return res.status(404).json({ message: 'Registro no encontrado o sin permiso' });
        res.json({ message: 'Registro actualizado' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function eliminarHistorial(req, res) {
    try {
        const doctor_id = req.user && req.user.rol === 'doctor' ? req.user.id : null;
        const filas = await historialModelo.eliminarHistorial(req.params.id, req.clinica_id, doctor_id);
        if (filas === 0) return res.status(404).json({ message: 'Registro no encontrado o sin permiso' });
        res.json({ message: 'Registro eliminado' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

module.exports = {
    listarHistorial,
    listarHistorialPorPaciente,
    verHistorial,
    crearHistorial,
    actualizarHistorial,
    eliminarHistorial
};
