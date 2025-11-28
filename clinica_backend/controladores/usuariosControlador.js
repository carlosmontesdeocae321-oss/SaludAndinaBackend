// Vincular doctor individual como dueño de clínica
async function vincularDoctorComoDueno(req, res) {
    const { doctorId, clinicaId } = req.body;
    if (!doctorId || !clinicaId) {
        return res.status(400).json({ message: 'doctorId y clinicaId son requeridos' });
    }
    try {
        const updated = await usuariosModelo.vincularDoctorComoDueno(doctorId, clinicaId);
        if (updated === 0) return res.status(404).json({ message: 'Doctor no encontrado' });
        res.json({ message: 'Doctor vinculado como dueño de clínica' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}
const usuariosModelo = require('../modelos/usuariosModelo');

// === LOGIN ===
async function login(req, res) {
    const { usuario, clave } = req.body;

    if (!usuario || !clave) 
        return res.status(400).json({ message: 'Usuario y clave requeridos' });

    try {
        console.log('===> Login request recibida:', { usuario, clave });
        const user = await usuariosModelo.obtenerUsuarioPorCredenciales(usuario, clave);
        console.log('===> Resultado obtenerUsuarioPorCredenciales:', user);
        if (!user) return res.status(401).json({ message: 'Credenciales incorrectas' });

        res.json({
            id: user.id,
            usuario: user.usuario,
            rol: user.rol,
            clinicaId: user.clinica_id,
            dueno: user.dueno === 1 || user.dueno === true
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Error en el servidor' });
    }
}

// === LISTAR USUARIOS ===
async function listarUsuarios(req, res) {
    try {
        const usuarios = await usuariosModelo.obtenerUsuariosPorClinica(req.clinica_id);
        res.json(usuarios);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

// === VER USUARIO ===
async function verUsuario(req, res) {
    try {
        const usuario = await usuariosModelo.obtenerUsuarioPorId(req.params.id, req.clinica_id);
        if (!usuario) return res.status(404).json({ message: 'Usuario no encontrado' });
        res.json(usuario);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

// === CREAR USUARIO ===
async function crearUsuario(req, res) {
    try {
        console.log('===> Intentando crear usuario:', req.body);
        let clinica_id = req.clinica_id;
        if (req.user && req.user.rol === 'admin' && req.body.clinica_id) {
            clinica_id = req.body.clinica_id;
        }
        // Validar límite de doctores si el rol es doctor y tiene clínica
        if (req.body.rol === 'doctor' && clinica_id) {
            const { validarLimiteDoctores } = require('../utils/validacionLimites');
            const { cambiarPlanAClinicaVIP } = require('../utils/cambioPlanVIP');
            const validacion = await validarLimiteDoctores(clinica_id);
            console.log('===> Validación límite doctores:', validacion);
            if (!validacion.permitido) {
                const planBaseLimite = (validacion.plan?.doctores_max || 0);
                if (validacion.totalDoctores >= planBaseLimite) {
                    await cambiarPlanAClinicaVIP(clinica_id);
                    const nuevaValidacion = await validarLimiteDoctores(clinica_id);
                    console.log('===> Nueva validación VIP:', nuevaValidacion);
                    if (!nuevaValidacion.permitido) {
                        return res.status(403).json({ message: 'Límite de doctores alcanzado incluso en VIP. Compre más extras.' });
                    }
                } else {
                    return res.status(403).json({ message: 'Límite de doctores alcanzado para su plan. Compre más extras o cambie de plan.' });
                }
            }
        }
        // Si es doctor individual (sin clínica), no validar límite
        const nuevoId = await usuariosModelo.crearUsuario({ ...req.body, clinica_id, dueno: req.body.dueno });
        console.log('===> Usuario creado con ID:', nuevoId);
        res.status(201).json({ id: nuevoId });
    } catch (err) {
        console.error('===> Error al crear usuario:', err);
        if (err.code === 'ER_DUP_ENTRY') {
            return res.status(400).json({ message: 'El usuario ya existe' });
        }
        res.status(500).json({ message: 'Error al crear usuario: ' + err.message });
    }
}

// === ACTUALIZAR USUARIO ===
async function actualizarUsuario(req, res) {
    try {
        const filas = await usuariosModelo.actualizarUsuario(req.params.id, req.body, req.clinica_id);
        if (filas === 0) return res.status(404).json({ message: 'Usuario no encontrado o sin permiso' });
        res.json({ message: 'Usuario actualizado' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

// === ELIMINAR USUARIO ===
async function eliminarUsuario(req, res) {
    try {
        const filas = await usuariosModelo.eliminarUsuario(req.params.id, req.clinica_id);
        if (filas === 0) return res.status(404).json({ message: 'Usuario no encontrado o sin permiso' });
        res.json({ message: 'Usuario eliminado' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

module.exports = {
    login,
    listarUsuarios,
    verUsuario,
    crearUsuario,
    actualizarUsuario,
    eliminarUsuario,
    vincularDoctorComoDueno
};
