const express = require('express');
const router = express.Router();
const doctorProfilesControlador = require('../controladores/doctorProfilesControlador');
const doctorProfilesModelo = require('../modelos/doctorProfilesModelo');
const { auth } = require('../middlewares/auth');
const filtroClinica = require('../middlewares/clinica');
const multer = require('multer');
const path = require('path');

// Guardar avatars en uploads/avatars
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, path.join(__dirname, '..', 'uploads', 'avatars'));
  },
  filename: function (req, file, cb) {
    const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  }
});
const upload = multer({ storage });

// Storage para documentos (certificados, títulos)
const storageDocs = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, path.join(__dirname, '..', 'uploads', 'documents'));
  },
  filename: function (req, file, cb) {
    const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  }
});
const uploadDocs = multer({ storage: storageDocs });

// Ruta pública para leer información básica del perfil extendido
router.get('/:userId/public', async (req, res) => {
  try {
    const perfil = await doctorProfilesModelo.obtenerPerfilPorUsuario(req.params.userId);
    if (!perfil) return res.status(404).json({ error: 'Perfil no encontrado' });
    res.json(perfil);
  } catch (err) {
    console.error('Error en GET /api/doctor_profiles/:userId/public', err);
    res.status(500).json({ error: 'Error al obtener perfil público del doctor' });
  }
});

// Rutas protegidas por auth (y filtroClinica para consistencia)
router.use(auth);
router.use(filtroClinica);

router.get('/:userId', doctorProfilesControlador.verPerfil);
router.put('/:userId', doctorProfilesControlador.crearOActualizarPerfil);
router.post('/:userId/avatar', upload.single('avatar'), doctorProfilesControlador.subirAvatar);
// Subir múltiples documentos (protegido)
router.post('/:userId/documents', uploadDocs.array('files', 20), doctorProfilesControlador.subirDocumentos);
router.post('/:userId/photos', uploadDocs.array('files', 20), doctorProfilesControlador.subirDocumentos);

module.exports = router;
