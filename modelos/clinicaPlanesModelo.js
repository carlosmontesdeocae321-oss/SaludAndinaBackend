const pool = require('../config/db');

async function asignarPlanAClinica({ clinica_id, plan_id, fecha_inicio, fecha_fin }) {
  const [result] = await pool.query(
    'INSERT INTO clinica_planes (clinica_id, plan_id, fecha_inicio, fecha_fin, activo) VALUES (?, ?, ?, ?, ?)',
    [clinica_id, plan_id, fecha_inicio, fecha_fin, true]
  );
  return result.insertId;
}

async function obtenerPlanDeClinica(clinica_id) {
  const [rows] = await pool.query(
    'SELECT cp.*, p.nombre, p.precio, p.pacientes_max, p.doctores_max, p.sucursales_incluidas FROM clinica_planes cp JOIN planes p ON cp.plan_id = p.id WHERE cp.clinica_id = ? AND cp.activo = true',
    [clinica_id]
  );
  return rows[0];
}

module.exports = {
  asignarPlanAClinica,
  obtenerPlanDeClinica,
};
