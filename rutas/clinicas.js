const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const db = require('../config/db');

const uploadsDir = path.join(__dirname, '..', 'uploads', 'clinicas');

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    fs.mkdirSync(uploadsDir, { recursive: true });
    cb(null, uploadsDir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const safeExt = ext && ext.length <= 5 ? ext : '';
    cb(null, `clinic_${Date.now()}${safeExt}`);
  },
});

const upload = multer({ storage });

// Obtener todas las clínicas
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT id, nombre, direccion, imagen_url, telefono_contacto FROM clinicas'
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener clínicas' });
  }
});

// Obtener detalles de una clínica
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const [rows] = await db.query(
      'SELECT id, nombre, direccion, imagen_url, telefono_contacto FROM clinicas WHERE id = ? LIMIT 1',
      [id]
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Clínica no encontrada' });
    }
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener clínica' });
  }
});

// Crear una nueva clínica
router.post('/', async (req, res) => {
  const { nombre, direccion } = req.body;
  if (!nombre) {
    return res.status(400).json({ error: 'El nombre es obligatorio' });
  }
  try {
    const [result] = await db.query(
      'INSERT INTO clinicas (nombre, direccion) VALUES (?, ?)',
      [nombre, direccion || '']
    );
    res.status(201).json({ id: result.insertId, nombre, direccion });
  } catch (err) {
    res.status(500).json({ error: 'Error al crear clínica' });
  }
});

// Eliminar clínica por id
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const [result] = await db.query('DELETE FROM clinicas WHERE id = ?', [id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Clínica no encontrada' });
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Error al eliminar clínica' });
  }
});

// Actualizar datos públicos de la clínica (imagen, dirección, teléfono)
router.put('/:id/perfil', upload.single('imagen'), async (req, res) => {
  const { id } = req.params;
  const {
    direccion,
    telefono_contacto: telefonoContacto,
    imagen_url: imagenUrlField,
  } = req.body;

  const fields = [];
  const values = [];

  if (typeof direccion !== 'undefined') {
    fields.push('direccion = ?');
    values.push(direccion);
  }

  if (typeof telefonoContacto !== 'undefined') {
    fields.push('telefono_contacto = ?');
    values.push(telefonoContacto);
  }

  let finalImageUrl = null;
  if (req.file) {
    finalImageUrl = `/uploads/clinicas/${req.file.filename}`;
  } else if (typeof imagenUrlField !== 'undefined') {
    const trimmed = (imagenUrlField || '').trim();
    if (trimmed.length) {
      finalImageUrl = trimmed;
    } else {
      fields.push('imagen_url = NULL');
    }
  }

  if (finalImageUrl) {
    fields.push('imagen_url = ?');
    values.push(finalImageUrl);
  }

  if (!fields.length) {
    return res
      .status(400)
      .json({ error: 'No se enviaron campos para actualizar la clínica' });
  }

  try {
    values.push(id);
    const sql = `UPDATE clinicas SET ${fields.join(', ')} WHERE id = ?`;
    await db.query(sql, values);

    const [rows] = await db.query(
      'SELECT id, nombre, direccion, imagen_url, telefono_contacto FROM clinicas WHERE id = ? LIMIT 1',
      [id]
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Clínica no encontrada' });
    }
    res.json(rows[0]);
  } catch (err) {
    console.error('Error actualizando clínica', err);
    res.status(500).json({ error: 'Error al actualizar la clínica' });
  }
});

module.exports = router;
