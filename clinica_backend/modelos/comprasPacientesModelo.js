const pool = require('../config/db');

async function comprarPacienteExtra({ clinica_id, fecha_compra, monto }) {
  if (!fecha_compra) {
    const [result] = await pool.query(
      'INSERT INTO compras_pacientes (clinica_id, fecha_compra, monto) VALUES (?, NOW(), ?)',
      [clinica_id, monto]
    );
    return result.insertId;
  }
  const [result] = await pool.query(
    'INSERT INTO compras_pacientes (clinica_id, fecha_compra, monto) VALUES (?, ?, ?)',
    [clinica_id, fecha_compra, monto]
  );
  return result.insertId;
}

async function obtenerPacientesComprados(clinica_id) {
  const [rows] = await pool.query(
    'SELECT COUNT(*) as total FROM compras_pacientes WHERE clinica_id = ?',
    [clinica_id]
  );
  return rows[0].total;
}

module.exports = {
  comprarPacienteExtra,
  obtenerPacientesComprados,
};
