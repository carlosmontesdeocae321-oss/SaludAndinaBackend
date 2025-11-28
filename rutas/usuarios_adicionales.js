const express = require('express');
const router = express.Router();
const usuariosModelo = require('../modelos/usuariosModelo');
const { auth } = require('../middlewares/auth');

// Endpoint para que el usuario (doctor) vea sus datos: número de pacientes y límite
// Protegemos sólo esta ruta con el middleware `auth` para evitar que el router
// en su conjunto requiera autenticación (esto interfería con /login cuando
// usuariosAdicionales se montaba antes que el router principal de usuarios).
router.get('/mis-datos', auth, async (req, res) => {
  try {
    if (!req.user) return res.status(401).json({ message: 'No autenticado' });
    const db = require('../config/db');
    const userInfo = { usuario: null, clinica: null, rol: req.user.rol, dueno: req.user.dueno === true, is_app_admin: false };

    // Obtener nombre de usuario
    const [urows] = await db.query('SELECT usuario FROM usuarios WHERE id = ? LIMIT 1', [req.user.id]);
    if (urows && urows[0]) userInfo.usuario = urows[0].usuario;

    // Determinar si este usuario es el administrador global de la app.
    // Se pueden configurar `APP_ADMIN_USER` (nombre de usuario) o `APP_ADMIN_ID` (id numérico)
    try {
      const envAdminUser = process.env.APP_ADMIN_USER;
      const envAdminId = process.env.APP_ADMIN_ID ? parseInt(process.env.APP_ADMIN_ID, 10) : null;
      if ((envAdminId && req.user.id === envAdminId) || (envAdminUser && userInfo.usuario === envAdminUser)) {
        userInfo.is_app_admin = true;
      }
    } catch (e) {
      // Ignore env parsing errors and keep is_app_admin false
    }

    if (req.user.rol === 'doctor' && !req.user.clinica_id) {
      // Doctor individual -> contar pacientes por doctor y considerar compras individuales
      const [rows] = await db.query('SELECT COUNT(*) AS c FROM pacientes WHERE doctor_id = ?', [req.user.id]);
      const totalPacientes = rows[0] ? rows[0].c : 0;
      const comprasInd = require('../modelos/comprasPacientesIndividualModelo');
      const extra = await comprasInd.obtenerPacientesCompradosIndividual(req.user.id);
      const base = 20;
      const limite = Math.min(base + (extra || 0), 80);
      // Determinar si el doctor fue vinculado mediante compra (puede existir registro en compras_doctores)
      let esVinculado = false;
      try {
        const [prow] = await db.query('SELECT COUNT(*) AS c FROM compras_doctores WHERE usuario_id = ?', [req.user.id]);
        esVinculado = prow && prow[0] && prow[0].c > 0;
      } catch (e) {
        esVinculado = false;
      }
      // Devolver estructura consistente con la rama de clínica (incluye id/esVinculado)
      return res.json({ ...userInfo, id: req.user.id, rol: req.user.rol, clinicaId: req.user.clinica_id, totalPacientes, limite, plan: null, extra, doctores: [], esVinculado });
    }

    // Para usuarios asociados a clínica (incluye owners), devolver info de plan y límites
    const plan = await require('../modelos/clinicaPlanesModelo').obtenerPlanDeClinica(req.user.clinica_id);
    const [rows] = await db.query('SELECT COUNT(*) AS c FROM pacientes WHERE clinica_id = ?', [req.user.clinica_id]);
    const totalPacientes = rows[0] ? rows[0].c : 0;
    const extra = await require('../modelos/comprasPacientesModelo').obtenerPacientesComprados(req.user.clinica_id);
    const limite = (plan?.pacientes_max || 0) + (extra || 0);

    // Obtener nombre de la clínica si existe
    if (req.user.clinica_id) {
      const [crows] = await db.query('SELECT nombre FROM clinicas WHERE id = ? LIMIT 1', [req.user.clinica_id]);
      if (crows && crows[0]) userInfo.clinica = crows[0].nombre;
    }

    // Obtener lista de doctores de la clínica (nombre y flags)
    let doctores = [];
    if (req.user.clinica_id) {
      const [drows] = await db.query('SELECT id, usuario, dueno FROM usuarios WHERE clinica_id = ?', [req.user.clinica_id]);
      doctores = (drows || []).map(d => ({ id: d.id, usuario: d.usuario, dueno: d.dueno === 1 || d.dueno === true }));
    }

    // Determinar si el usuario fue vinculado mediante una compra de vinculación
    let esVinculado = false;
    try {
      const [prow] = await db.query('SELECT COUNT(*) AS c FROM compras_doctores WHERE usuario_id = ?', [req.user.id]);
      esVinculado = prow && prow[0] && prow[0].c > 0;
    } catch (e) {
      // ignorar error y asumir false
      esVinculado = false;
    }

    res.json({ ...userInfo, id: req.user.id, rol: req.user.rol, clinicaId: req.user.clinica_id, totalPacientes, limite, plan, extra, doctores, esVinculado });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
