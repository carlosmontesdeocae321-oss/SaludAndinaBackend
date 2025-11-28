const pool = require('../config/db');

// 🔹 Middleware de autenticación
async function auth(req, res, next) {
    const usuario = req.headers['x-usuario'];
    const clave = req.headers['x-clave'];

    if (!usuario || !clave) {
        console.warn('[auth] Faltan credenciales - path:', req.path, 'method:', req.method, 'headers:', {
            // mostrar solo nombres de headers para evitar filtrar secretos en logs
            keys: Object.keys(req.headers)
        });
        return res.status(401).json({ message: 'Faltan credenciales' });
    }

    try {
        const [rows] = await pool.query(
            'SELECT * FROM usuarios WHERE usuario = ? LIMIT 1',
            [usuario]
        );

        const user = rows[0];
        if (!user || user.clave !== clave) {
            console.warn('[auth] Credenciales fallaron para usuario:', usuario, 'path:', req.path);
            return res.status(401).json({ message: 'Usuario o clave incorrecta' });
        }

        req.user = {
            id: user.id,
            rol: user.rol,
            clinica_id: user.clinica_id,
            dueno: user.dueno === 1 || user.dueno === true
        };

        next();
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

// 🔹 Middleware para filtrar por clínica
function filtroClinica(req, res, next) {
    if (!req.user || !req.user.clinica_id) {
        return res.status(403).json({ message: 'Acceso no permitido' });
    }

    req.clinica_id = req.user.clinica_id;
    next();
}

module.exports = {
    auth,
    filtroClinica
};
