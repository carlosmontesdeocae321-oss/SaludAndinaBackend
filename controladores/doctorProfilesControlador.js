const doctorProfilesModelo = require('../modelos/doctorProfilesModelo');
const doctorDocumentsModelo = require('../modelos/doctorDocumentsModelo');
const path = require('path');

async function verPerfil(req, res) {
  try {
    const userId = req.params.userId || req.user && req.user.id;
    if (!userId) return res.status(400).json({ message: 'userId es requerido' });
    const perfil = await doctorProfilesModelo.obtenerPerfilPorUsuario(userId);
    if (!perfil) return res.status(404).json({ message: 'Perfil no encontrado' });
    res.json(perfil);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

async function crearOActualizarPerfil(req, res) {
  try {
    const userId = req.params.userId || (req.user && req.user.id);
    if (!userId) return res.status(400).json({ message: 'userId es requerido' });
    const existing = await doctorProfilesModelo.obtenerPerfilPorUsuario(userId);
    // Build payload only with fields explicitly provided to avoid
    // overwriting existing values with undefined/null when the client
    // didn't send them (for example avatar_url when user didn't change image).
    const payload = {};
    // Accept standard fields
    ['nombre','apellido','direccion','telefono','email','bio','avatar_url','especialidad'].forEach((k) => {
      if (Object.prototype.hasOwnProperty.call(req.body, k)) {
        payload[k] = req.body[k];
      }
    });
    // Backwards/forwards compatibility: map alternative keys to `especialidad`
    if (Object.prototype.hasOwnProperty.call(req.body, 'specialty') && !payload.especialidad) {
      payload.especialidad = req.body['specialty'];
    }
    if (Object.prototype.hasOwnProperty.call(req.body, 'profesion') && !payload.especialidad) {
      payload.especialidad = req.body['profesion'];
    }
    if (!existing) {
      const id = await doctorProfilesModelo.crearPerfil(userId, payload);
      const perfil = await doctorProfilesModelo.obtenerPerfilPorUsuario(userId);
      return res.status(201).json(perfil);
    } else {
      await doctorProfilesModelo.actualizarPerfil(userId, payload);
      const perfil = await doctorProfilesModelo.obtenerPerfilPorUsuario(userId);
      return res.json(perfil);
    }
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

// Subir avatar: multipart field 'avatar'
async function subirAvatar(req, res) {
  try {
    const userId = req.params.userId || (req.user && req.user.id);
    if (!userId) return res.status(400).json({ message: 'userId es requerido' });
    if (!req.file) return res.status(400).json({ message: 'Archivo no recibido en campo avatar' });
    // Guardar ruta pública
    const url = '/uploads/avatars/' + req.file.filename;
    // Crear o actualizar perfil
    const existing = await doctorProfilesModelo.obtenerPerfilPorUsuario(userId);
    if (!existing) {
      await doctorProfilesModelo.crearPerfil(userId, { avatar_url: url });
    } else {
      await doctorProfilesModelo.actualizarPerfil(userId, { avatar_url: url });
    }
    res.json({ ok: true, avatar_url: url });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

// Listar documentos asociados a un doctor (public)
async function listarDocumentos(req, res) {
  try {
    const userId = req.params.userId;
    if (!userId) return res.status(400).json({ message: 'userId es requerido' });
    const docs = await doctorDocumentsModelo.listarDocumentosPorUsuario(userId);
    res.json(docs);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

// Subir múltiples documentos (multipart field 'files')
async function subirDocumentos(req, res) {
  try {
    const userId = req.params.userId || (req.user && req.user.id);
    if (!userId) return res.status(400).json({ message: 'userId es requerido' });
    if (!req.files || req.files.length === 0) return res.status(400).json({ message: 'No se recibieron archivos' });
    const saved = [];
    for (const f of req.files) {
      const url = '/uploads/documents/' + f.filename;
      const filename = f.originalname;
      const filePath = url;
      await doctorDocumentsModelo.crearDocumento(userId, { filename, path: filePath, url });
      saved.push({ filename, url });
    }
    res.status(201).json({ ok: true, saved });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

module.exports = {
  verPerfil,
  crearOActualizarPerfil,
  subirAvatar
  , listarDocumentos, subirDocumentos
};
