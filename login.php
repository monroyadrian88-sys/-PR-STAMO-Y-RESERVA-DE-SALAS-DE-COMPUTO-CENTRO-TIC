
<?php

require_once __DIR__ . '/auth/seguridad.php';
require_once __DIR__ . '/conexion.php';

// Si ya inició sesión, enviarlo al panel correspondiente.
if (isset($_SESSION['id_usuario'])) {

    if (($_SESSION['rol'] ?? '') === 'ADMINISTRADOR') {
        header('Location: admin/panel.php');
    } elseif (($_SESSION['rol'] ?? '') === 'USUARIO') {
        header('Location: usuario/panel.php');
    } else {
        // Si la sesión no tiene un rol válido, cerrarla.
        $_SESSION = [];
        session_destroy();

        header('Location: login.php');
    }

    exit;
}

$mensaje = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    $nombre_usuario = trim($_POST['nombre_usuario'] ?? '');
    $contrasena = $_POST['contrasena'] ?? '';

    if ($nombre_usuario === '' || $contrasena === '') {

        $mensaje = 'Ingresa tu usuario y contraseña.';

    } else {

        try {

            // Buscar la cuenta y los datos de la persona.
            $consulta = $conexion->prepare(
                'SELECT
                    u.id_usuario,
                    u.id_persona,
                    u.nombre_usuario,
                    u.contrasena_hash,
                    u.rol,
                    u.activo,
                    p.nombres,
                    p.apellidos
                 FROM gestion.usuario AS u
                 INNER JOIN gestion.persona AS p
                    ON p.id_persona = u.id_persona
                 WHERE LOWER(u.nombre_usuario) = LOWER(:usuario)
                 LIMIT 1'
            );

            $consulta->execute([
                'usuario' => $nombre_usuario
            ]);

            $usuario = $consulta->fetch();

            // Verificar que la cuenta esté activa y la contraseña sea correcta.
            if (
                $usuario &&
                in_array(
                    $usuario['rol'],
                    ['ADMINISTRADOR', 'USUARIO'],
                    true
                ) &&
                in_array(
                    $usuario['activo'],
                    [true, 1, '1', 't', 'true'],
                    true
                ) &&
                password_verify(
                    $contrasena,
                    $usuario['contrasena_hash']
                )
            ) {

                // Generar un nuevo identificador de sesión.
                session_regenerate_id(true);

                // Guardar los datos necesarios para identificar al usuario.
                $_SESSION['id_usuario'] = $usuario['id_usuario'];
                $_SESSION['id_persona'] = $usuario['id_persona'];
                $_SESSION['nombre_usuario'] = $usuario['nombre_usuario'];
                $_SESSION['nombre_completo'] =
                    $usuario['nombres'] . ' ' . $usuario['apellidos'];
                $_SESSION['rol'] = $usuario['rol'];

                // Redirigir según el rol.
                if ($usuario['rol'] === 'ADMINISTRADOR') {
                    header('Location: admin/panel.php');
                } else {
                    header('Location: usuario/panel.php');
                }

                exit;

            } else {

                $mensaje = 'Usuario o contraseña incorrectos.';

            }

        } catch (PDOException $e) {

            // Guardar detalles técnicos solo en el registro del servidor.
            error_log($e->getMessage());

            $mensaje =
                'No se pudo iniciar sesión. Inténtalo más tarde.';
        }
    }
}
?>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <title>Iniciar sesión - Centro TIC</title>

    <link rel="stylesheet" href="css/estilos.css">
</head>
<body>

    <h1>Iniciar sesión</h1>

    <p>Ingresa tus credenciales para acceder al Centro TIC.</p>

    <?php if ($mensaje !== ''): ?>
        <p role="alert">
            <?= htmlspecialchars(
                $mensaje,
                ENT_QUOTES,
                'UTF-8'
            ) ?>
        </p>
    <?php endif; ?>

    <form action="" method="POST">

        <label for="nombre_usuario">
            Nombre de usuario:
        </label>

        <input
            type="text"
            id="nombre_usuario"
            name="nombre_usuario"
            maxlength="50"
            autocomplete="username"
            required
        >

        <label for="contrasena">
            Contraseña:
        </label>

        <input
            type="password"
            id="contrasena"
            name="contrasena"
            autocomplete="current-password"
            required
        >

        <button type="submit">
            Ingresar
        </button>

    </form>

    <p>
        ¿No tienes cuenta?
        <a href="registro.php">Regístrate aquí</a>
    </p>

    <p>
        <a href="index.php">Volver al inicio</a>
    </p>

</body>
</html>
