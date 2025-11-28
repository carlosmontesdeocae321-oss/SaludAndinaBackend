function filtroClinica(req, res, next) {
    if (!req.user) {
        return res.status(403).json({ message: 'Acceso no permitido' });
    }
    // Si el usuario es admin global, permite clinica_id del body para POST /usuarios
    if (req.user.rol === 'admin' && req.method === 'POST' && req.path === '/') {
        req.clinica_id = req.body.clinica_id || req.user.clinica_id;
    } else {
        // Permitir doctores individuales sin clinica_id: asignamos null y dejamos que los controladores manejen la lógica
        if (!req.user.clinica_id) {
            if (req.user.rol === 'doctor') {
                req.clinica_id = null;
            } else {
                return res.status(403).json({ message: 'Acceso no permitido' });
            }
        } else {
            req.clinica_id = req.user.clinica_id;
        }
    }
    next();
}

module.exports = filtroClinica;
