const pool = require('../config/db');

async function crearDocumento(userId, data) {
  const { filename, path: filePath, url } = data;
  const [res] = await pool.query(
    'INSERT INTO doctor_documents (user_id, filename, path, url, creado_en) VALUES (?, ?, ?, ?, NOW())',
    [userId, filename, filePath, url]
  );
  return res.insertId;
}

async function listarDocumentosPorUsuario(userId) {
  const [rows] = await pool.query('SELECT id, filename, path, url, creado_en FROM doctor_documents WHERE user_id = ? ORDER BY creado_en DESC', [userId]);
  return rows;
}

module.exports = {
  crearDocumento,
  listarDocumentosPorUsuario
};
