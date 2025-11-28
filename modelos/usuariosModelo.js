// Vincular doctor individual como dueño de clínica
async function vincularDoctorComoDueno(doctorId, clinicaId) {
    const [result] = await pool.query(
        'UPDATE usuarios SET clinica_id=?, dueno=1 WHERE id=?',
        [clinicaId, doctorId]
    );
    return result.affectedRows;
}
const pool = require('../config/db');

// Obtener todos los usuarios de la clínica
async function obtenerUsuariosPorClinica(clinica_id) {
    const [rows] = await pool.query(
        'SELECT id, usuario, rol, creado_en, clinica_id FROM usuarios WHERE clinica_id = ? ORDER BY usuario',
        [clinica_id]
    );
    return rows;
}

// Obtener un usuario por id y clínica
async function obtenerUsuarioPorId(id, clinica_id) {
    const [rows] = await pool.query(
        'SELECT id, usuario, rol, creado_en, clinica_id FROM usuarios WHERE id = ? AND clinica_id = ?',
        [id, clinica_id]
    );
    return rows[0];
}

// Crear usuario
async function crearUsuario(usuario) {
    const { usuario: nombre, clave, rol, clinica_id, dueno } = usuario;
    if (rol === 'doctor' && !clinica_id) {
        // Doctor individual sin clínica
        const [result] = await pool.query(
            'INSERT INTO usuarios (usuario, clave, rol, dueno) VALUES (?, ?, ?, ?)',
            [nombre, clave, rol, dueno ? 1 : 0]
        );
        return result.insertId;
    } else {
        // Usuario de clínica (requiere clinica_id)
        // Forzar que los usuarios creados por una clínica no sean dueños
        const duenoValue = 0;
        const [result] = await pool.query(
            'INSERT INTO usuarios (usuario, clave, rol, clinica_id, dueno) VALUES (?, ?, ?, ?, ?)',
            [nombre, clave, rol, clinica_id, duenoValue]
        );
        return result.insertId;
    }
}

async function obtenerUsuarioPorCredenciales(usuario, clave) {
    try {
        console.log('===> Query obtenerUsuarioPorCredenciales args:', { usuario, clave });
        const [rows] = await pool.query(
            'SELECT id, usuario, rol, clinica_id, dueno, clave FROM usuarios WHERE usuario=? LIMIT 1',
            [usuario]
        );
        console.log('===> Filas encontradas:', rows);
        if (!rows || rows.length === 0) return undefined;
        // Verificamos la clave aquí para poder loguear diferencias
        const row = rows[0];
        if (row.clave !== clave) {
            console.log('===> Clave no coincide. almacenada:', row.clave, 'recibida:', clave);
            return undefined;
        }
        // Devolver sin la clave
        delete row.clave;
        return row;
    } catch (err) {
        console.error('Error en obtenerUsuarioPorCredenciales:', err);
        throw err;
    }
}


// Actualizar usuario
async function actualizarUsuario(id, usuario, clinica_id) {
    const { usuario: nombre, clave, rol } = usuario;
    const [result] = await pool.query(
        'UPDATE usuarios SET usuario=?, clave=?, rol=? WHERE id=? AND clinica_id=?',
        [nombre, clave, rol, id, clinica_id]
    );
    return result.affectedRows;
}

// Eliminar usuario
async function eliminarUsuario(id, clinica_id) {
    const [result] = await pool.query(
        'DELETE FROM usuarios WHERE id=? AND clinica_id=?',
        [id, clinica_id]
    );
    return result.affectedRows;
}

module.exports = {
    obtenerUsuariosPorClinica,
    obtenerUsuarioPorId,
    crearUsuario,
    actualizarUsuario,
    eliminarUsuario,
    obtenerUsuarioPorCredenciales,
    vincularDoctorComoDueno
};
