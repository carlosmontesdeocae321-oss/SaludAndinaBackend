const express = require('express');
const router = express.Router();
const pagosService = require('../servicios/pagosService');
const { auth } = require('../middlewares/auth');
const pool = require('../config/db');

// Crear una compra de promoción (permitir anónimo: no requiere auth)
router.post('/crear', async (req, res) => {
  try {
    const usuarioId = req.user?.id;
    const clinicaId = req.user?.clinica_id || req.body.clinica_id || null;
    const { titulo, monto, provider } = req.body;
    if (!titulo || monto == null) return res.status(400).json({ message: 'titulo y monto requeridos' });

    const compra = await pagosService.crearCompraPromocion({
      titulo,
      monto,
      clinica_id: clinicaId,
      usuario_id: usuarioId,
      provider: provider || 'mock'
    });

    // Devolver la url de pago (para mock abrir la ruta interna)
    res.status(201).json({ compraId: compra.id, payment_url: compra.payment_url });
  } catch (err) {
    console.error('Error crear compra promocion:', err);
    res.status(500).json({ message: err.message });
  }
});

// Endpoint que simula la página de checkout del provider (solo para pruebas)
router.get('/mock-pay/:id', async (req, res) => {
  const compraId = req.params.id;
  // Página mínima que simula pagar y llama al backend para confirmar
  const html = `
    <html>
      <body style="font-family: Arial; padding: 20px;">
        <h2>Simulación de pago (Mock)</h2>
        <p>Compra ID: ${compraId}</p>
        <form method="post" action="/api/compras_promociones/confirmar">
          <input type="hidden" name="compraId" value="${compraId}" />
          <button type="submit" style="padding:10px 20px;">Simular pago exitoso</button>
        </form>
      </body>
    </html>
  `;
  res.send(html);
});

// Confirmar compra (webhook o llamada del frontend después del pago)
router.post('/confirmar', async (req, res) => {
  try {
    const { compraId, provider_txn_id } = req.body;
    if (!compraId) return res.status(400).json({ message: 'compraId requerido' });
    const ok = await pagosService.confirmarCompra({ compraId, provider_txn_id });
    if (!ok) return res.status(404).json({ message: 'Compra no encontrada' });
    res.json({ message: 'Compra confirmada' });
  } catch (err) {
    console.error('Error confirmar compra:', err);
    res.status(500).json({ message: err.message });
  }
});

// Obtener estado de compra
router.get('/:id', auth, async (req, res) => {
  try {
    const compra = await pagosService.obtenerCompra(req.params.id);
    if (!compra) return res.status(404).json({ message: 'Compra no encontrada' });
    res.json(compra);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Crear clínica y usuario admin tras compra (permitir anónimo: no requiere auth)
router.post('/crear-clinica', async (req, res) => {
  const { nombre, direccion, usuario, clave } = req.body;
  if (!nombre || !usuario || !clave) return res.status(400).json({ message: 'Faltan datos' });
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [cRes] = await conn.query('INSERT INTO clinicas (nombre, direccion) VALUES (?, ?)', [nombre, direccion || '']);
    const clinicaId = cRes.insertId;
    // Crear el usuario con rol 'doctor' y marcarlo como dueño (dueno=1).
    // Así evitamos valores inesperados en la columna `rol` y mantenemos la distinción
    // de dueño mediante el flag `dueno`.
    const [uRes] = await conn.query('INSERT INTO usuarios (usuario, clave, rol, clinica_id, dueno) VALUES (?, ?, ?, ?, 1)', [usuario, clave, 'doctor', clinicaId]);
    // Intentar asignar un plan por defecto a la clínica para que tenga límites iniciales.
    // POR QUÉ: usamos la misma conexión `conn` dentro de la transacción para evitar bloqueos
    // causados por mezclar la transacción con consultas que abren nuevas conexiones.
    // Buscamos un plan "Clínica Pequeña" en la tabla `planes` usando la misma conexión.
    let planId = null;
    const [pRows] = await conn.query('SELECT id, nombre, pacientes_max, doctores_max FROM planes');
    let found = null;
    if (pRows && pRows.length > 0) {
      found = pRows.find(p => (p.nombre || '').toLowerCase().includes('peque') || (p.nombre || '').toLowerCase().includes('pequeña'));
    }
    if (found) {
      planId = found.id;
    } else {
      const [pIns] = await conn.query(
        'INSERT INTO planes (nombre, precio, pacientes_max, doctores_max, sucursales_incluidas, descripcion) VALUES (?, ?, ?, ?, ?, ?)',
        ['Clínica Pequeña', 20.0, 100, 2, 0, 'Plan por defecto creado automáticamente (100 pacientes, 2 doctores)']
      );
      planId = pIns.insertId;
    }
    // Insertar registro en clinica_planes usando la misma conexión/tx
    await conn.query(
      'INSERT INTO clinica_planes (clinica_id, plan_id, fecha_inicio, fecha_fin, activo) VALUES (?, ?, ?, ?, ?)',
      [clinicaId, planId, new Date(), null, 1]
    );
    await conn.commit();
    res.status(201).json({ clinicaId, usuarioId: uRes.insertId });
  } catch (err) {
    await conn.rollback();
    console.error('Error crear clinica+usuario:', err);
    res.status(500).json({ message: err.message });
  } finally {
    conn.release();
  }
});

module.exports = router;
