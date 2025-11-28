const pool = require('../config/db');

async function comprarDoctorExtra({ clinica_id, usuario_id, fecha_compra, monto }) {
  const [result] = await pool.query(
    'INSERT INTO compras_doctores (clinica_id, usuario_id, fecha_compra, monto) VALUES (?, ?, ?, ?)',
    [clinica_id, usuario_id, fecha_compra, monto]
  );
  return result.insertId;
}

async function obtenerDoctoresComprados(clinica_id) {
  const [rows] = await pool.query(
    'SELECT COUNT(*) as total FROM compras_doctores WHERE clinica_id = ?',
    [clinica_id]
  );
  return rows[0].total;
}

async function obtenerUsuariosCompradosPorClinica(clinica_id) {
  const [rows] = await pool.query(
    'SELECT usuario_id FROM compras_doctores WHERE clinica_id = ?',
    [clinica_id]
  );
  return rows.map(r => r.usuario_id);
}

module.exports = {
  comprarDoctorExtra,
  obtenerDoctoresComprados,
};

// Exportar la nueva función para obtener los usuario_ids comprados
module.exports.obtenerUsuariosCompradosPorClinica = obtenerUsuariosCompradosPorClinica;
