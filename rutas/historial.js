const express = require('express');
const router = express.Router();
const historialControlador = require('../controladores/historialControlador');
const { auth } = require('../middlewares/auth');
const filtroClinica = require('../middlewares/clinica');
const multer = require('multer');
const path = require('path');

// Configuración de multer: guardar en uploads/historial
const os = require('os');
// Use system temp dir for initial storage to avoid ENOENT when uploads/ is not writable
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const tmpDir = path.join(os.tmpdir(), 'clinica_uploads');
        try {
            const fs = require('fs');
            if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir, { recursive: true });
        } catch (e) {
            console.warn('Could not create tmp upload dir:', e);
        }
        cb(null, tmpDir);
    },
    filename: function (req, file, cb) {
        const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, unique + path.extname(file.originalname));
    }
});
const upload = multer({ storage });

router.use(auth);
router.use(filtroClinica);

router.get('/', historialControlador.listarHistorial);
router.get('/:id', historialControlador.verHistorial);
router.get('/paciente/:id', historialControlador.listarHistorialPorPaciente);
// Aceptar múltiples imágenes en campo 'imagenes'
router.post('/', upload.array('imagenes', 20), historialControlador.crearHistorial);
router.put('/:id', upload.array('imagenes', 20), historialControlador.actualizarHistorial);
router.delete('/:id', historialControlador.eliminarHistorial);

module.exports = router;
