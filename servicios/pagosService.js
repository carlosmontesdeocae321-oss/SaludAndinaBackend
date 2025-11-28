const pool = require('../config/db');

// Servicio de pagos modular: actualmente soporta provider 'mock'.
// La idea es centralizar la integración con Stripe/PayU/MercadoPago en este archivo.

async function ensureTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS compras_promociones (
      id INT AUTO_INCREMENT PRIMARY KEY,
      titulo VARCHAR(255),
      monto DECIMAL(10,2),
      clinica_id INT DEFAULT NULL,
      usuario_id INT DEFAULT NULL,
      status VARCHAR(32) DEFAULT 'pending',
      provider VARCHAR(64),
      provider_txn_id VARCHAR(255) DEFAULT NULL,
      creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;
  `);
}

// Crear compra en DB
async function crearCompraPromocion({ titulo, monto, clinica_id, usuario_id, provider = 'mock' }) {
  await ensureTable();
  const [result] = await pool.query(
    'INSERT INTO compras_promociones (titulo, monto, clinica_id, usuario_id, provider) VALUES (?, ?, ?, ?, ?)',
    [titulo, monto, clinica_id || null, usuario_id || null, provider]
  );
  const compraId = result.insertId;

  // Para provider mock devolvemos una url donde el usuario puede 'pagar'
  if (provider === 'mock') {
    return {
      id: compraId,
      status: 'pending',
      payment_url: `/api/compras_promociones/mock-pay/${compraId}`
    };
  }

  // Aquí se podrían implementar otros providers
  throw new Error('Provider no soportado: ' + provider);
}

// Confirmar compra (por webhook o llamada directa)
async function confirmarCompra({ compraId, provider_txn_id }) {
  await ensureTable();
  // Marcar como completed
  const [res] = await pool.query(
    'UPDATE compras_promociones SET status = ?, provider_txn_id = ? WHERE id = ?',
    ['completed', provider_txn_id || null, compraId]
  );
  return res.affectedRows > 0;
}

async function obtenerCompra(compraId) {
  await ensureTable();
  const [rows] = await pool.query('SELECT * FROM compras_promociones WHERE id = ? LIMIT 1', [compraId]);
  return rows[0];
}

async function listarComprasPendientes({ clinica_id = null } = {}) {
  await ensureTable();
  if (clinica_id) {
    const [rows] = await pool.query('SELECT * FROM compras_promociones WHERE status = ? AND clinica_id = ? ORDER BY creado_en DESC', ['pending', clinica_id]);
    return rows;
  }
  const [rows] = await pool.query('SELECT * FROM compras_promociones WHERE status = ? ORDER BY creado_en DESC', ['pending']);
  return rows;
}

module.exports = {
  crearCompraPromocion,
  confirmarCompra,
  obtenerCompra
};

// Export adicional
module.exports.listarComprasPendientes = listarComprasPendientes;

