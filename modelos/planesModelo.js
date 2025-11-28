const pool = require('../config/db');

async function obtenerPlanes() {
  const [rows] = await pool.query('SELECT * FROM planes ORDER BY precio');
  return rows;
}

async function crearPlan(plan) {
  const { nombre, precio, pacientes_max, doctores_max, sucursales_incluidas, descripcion } = plan;
  const [result] = await pool.query(
    'INSERT INTO planes (nombre, precio, pacientes_max, doctores_max, sucursales_incluidas, descripcion) VALUES (?, ?, ?, ?, ?, ?)',
    [nombre, precio, pacientes_max, doctores_max, sucursales_incluidas, descripcion]
  );
  return result.insertId;
}

module.exports = {
  obtenerPlanes,
  crearPlan,
};
