const express = require('express');
const router = express.Router();
const historialControlador = require('../controladores/historialControlador');
const { auth } = require('../middlewares/auth');
const filtroClinica = require('../middlewares/clinica');
const multer = require('multer');
const path = require('path');

// Configuración de multer: guardar en uploads/historial
const storage = multer.diskStorage({
	destination: function (req, file, cb) {
		const dest = path.join(__dirname, '..', 'uploads', 'historial');
		try {
			const fs = require('fs');
			if (!fs.existsSync(dest)) fs.mkdirSync(dest, { recursive: true });
		} catch (e) {
			console.warn('Could not create uploads/historial dir:', e);
		}
		cb(null, dest);
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
