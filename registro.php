
<?php
session_start();
require_once __DIR__ . '/conexion.php';

$mensaje = '';
$tipo_mensaje = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    $tipo = $_POST['tipo'] ?? '';
    $nombres = trim($_POST['nombres'] ?? '');
    $apellidos = trim($_POST['apellidos'] ?? '');
    $correo = trim($_POST['correo'] ?? '');
    $codigo_estudiante = trim($_POST['codigo_estudiante'] ?? '');
    $codigo_docente = trim($_POST['codigo_docente'] ?? '');
    $telefono = trim($_POST['telefono'] ?? '');
    $nombre_usuario = trim($_POST['nombre_usuario'] ?? '');
    $contrasena = $_POST['contrasena'] ?? '';
    $confirmar = $_POST['confirmar_contrasena'] ?? '';

    // 1. Validar los datos recibidos
    if (!in_array($tipo, ['ESTUDIANTE', 'DOCENTE'], true)) {
        $mensaje = 'Selecciona un perfil válido.';
    } elseif (
        $nombres === '' ||
        $apellidos === '' ||
        $correo === '' ||
        $nombre_usuario === '' ||
        $contrasena === ''
    ) {
        $mensaje = 'Completa todos los campos obligatorios.';
    } elseif (!filter_var($correo, FILTER_VALIDATE_EMAIL)) {
        $mensaje = 'El correo electrónico no es válido.';
    } elseif (strlen($contrasena) < 8) {
        $mensaje = 'La contraseña debe tener al menos 8 caracteres.';
    } elseif ($contrasena !== $confirmar) {
        $mensaje = 'Las contraseñas no coinciden.';
    } elseif (strlen($nombre_usuario) > 50) {
        $mensaje = 'El nombre de usuario admite máximo 50 caracteres.';
    } elseif (
        ($tipo === 'ESTUDIANTE' && $codigo_estudiante === '') ||
        ($tipo === 'DOCENTE' && $codigo_docente === '')
    ) {
        $mensaje = 'Debes ingresar el código correspondiente a tu perfil.';
    } else {
        try {
            $conexion->beginTransaction();

            // 2. Comprobar que no exista el correo
            $consulta = $conexion->prepare(
                'SELECT 1
                 FROM gestion.persona
                 WHERE LOWER(correo) = LOWER(:correo)'
            );
            $consulta->execute(['correo' => $correo]);

            if ($consulta->fetchColumn()) {
                throw new DomainException(
                    'Ya existe una persona registrada con ese correo.'
                );
            }

            // 3. Comprobar que el usuario esté disponible
            $consulta = $conexion->prepare(
                'SELECT 1
                 FROM gestion.usuario
                 WHERE LOWER(nombre_usuario) = LOWER(:usuario)'
            );
            $consulta->execute(['usuario' => $nombre_usuario]);

            if ($consulta->fetchColumn()) {
                throw new DomainException(
                    'Ese nombre de usuario ya está ocupado.'
                );
            }

            // 4. Comprobar que el código institucional no esté repetido
            if ($tipo === 'ESTUDIANTE') {
                $consulta = $conexion->prepare(
                    'SELECT 1
                     FROM gestion.estudiante
                     WHERE codigo_estudiante = :codigo'
                );
                $consulta->execute([
                    'codigo' => $codigo_estudiante
                ]);
            } else {
                $consulta = $conexion->prepare(
                    'SELECT 1
                     FROM gestion.docente
                     WHERE codigo_docente = :codigo'
                );
                $consulta->execute([
                    'codigo' => $codigo_docente
                ]);
            }

            if ($consulta->fetchColumn()) {
                throw new DomainException(
                    'El código institucional ya está registrado.'
                );
            }

            // 5. Crear la persona
            $consulta = $conexion->prepare(
                'INSERT INTO gestion.persona
                    (nombres, apellidos, correo)
                 VALUES
                    (:nombres, :apellidos, :correo)
                 RETURNING id_persona'
            );

            $consulta->execute([
                'nombres' => $nombres,
                'apellidos' => $apellidos,
                'correo' => $correo
            ]);

            $id_persona = $consulta->fetchColumn();

            // 6. Crear el perfil académico seleccionado
            if ($tipo === 'ESTUDIANTE') {
                $consulta = $conexion->prepare(
                    'INSERT INTO gestion.estudiante
                        (id_persona, codigo_estudiante)
                     VALUES
                        (:id_persona, :codigo)'
                );

                $consulta->execute([
                    'id_persona' => $id_persona,
                    'codigo' => $codigo_estudiante
                ]);
            } else {
                $consulta = $conexion->prepare(
                    'INSERT INTO gestion.docente
                        (id_persona, codigo_docente, telefono)
                     VALUES
                        (:id_persona, :codigo, :telefono)'
                );

                $consulta->execute([
                    'id_persona' => $id_persona,
                    'codigo' => $codigo_docente,
                    'telefono' => $telefono !== '' ? $telefono : null
                ]);
            }

            // 7. Proteger la contraseña
            $contrasena_hash = password_hash(
                $contrasena,
                PASSWORD_DEFAULT
            );

            // 8. Crear la cuenta con rol fijo USUARIO
            $consulta = $conexion->prepare(
                "INSERT INTO gestion.usuario
                    (id_persona, nombre_usuario, contrasena_hash, rol)
                 VALUES
                    (:id_persona, :usuario, :hash, 'USUARIO')"
            );

            $consulta->execute([
                'id_persona' => $id_persona,
                'usuario' => $nombre_usuario,
                'hash' => $contrasena_hash
            ]);

            // 9. Confirmar todas las inserciones
            $conexion->commit();

            $mensaje = '¡Registro exitoso! Ya puedes iniciar sesión.';
            $tipo_mensaje = 'exito';

            $_POST = [];

        } catch (DomainException $e) {
            if ($conexion->inTransaction()) {
                $conexion->rollBack();
            }

            $mensaje = $e->getMessage();

        } catch (PDOException $e) {
            if ($conexion->inTransaction()) {
                $conexion->rollBack();
            }

            // Registrar el error real en el log del servidor
            error_log($e->getMessage());

            if ($e->getCode() === '23505') {
                $mensaje =
                    'Uno de los datos ingresados ya está registrado.';
            } else {
                $mensaje =
                    'No fue posible completar el registro. Revisa la configuración de la base de datos.';
            }
        }
    }
}
?>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Registro - Centro TIC</title>
    <link rel="stylesheet" href="css/estilos.css">
</head>
<body>

    <h1>Registro de usuario</h1>
    <p>Crea tu cuenta para utilizar los servicios del Centro TIC.</p>

    <?php if ($mensaje !== ''): ?>
        <p role="status">
            <?= htmlspecialchars($mensaje, ENT_QUOTES, 'UTF-8') ?>
        </p>
    <?php endif; ?>

    <form action="" method="POST">

        <label for="tipo">Tipo de perfil:</label>
        <select name="tipo" id="tipo" required>
            <option value="">Selecciona una opción</option>
            <option value="ESTUDIANTE"
                <?= (($_POST['tipo'] ?? '') === 'ESTUDIANTE') ? 'selected' : '' ?>>
                Estudiante
            </option>
            <option value="DOCENTE"
                <?= (($_POST['tipo'] ?? '') === 'DOCENTE') ? 'selected' : '' ?>>
                Docente
            </option>
        </select>

        <label for="nombres">Nombres:</label>
        <input type="text" id="nombres" name="nombres"
               value="<?= htmlspecialchars($_POST['nombres'] ?? '', ENT_QUOTES, 'UTF-8') ?>"
               required>

        <label for="apellidos">Apellidos:</label>
        <input type="text" id="apellidos" name="apellidos"
               value="<?= htmlspecialchars($_POST['apellidos'] ?? '', ENT_QUOTES, 'UTF-8') ?>"
               required>

        <label for="correo">Correo electrónico:</label>
        <input type="email" id="correo" name="correo"
               value="<?= htmlspecialchars($_POST['correo'] ?? '', ENT_QUOTES, 'UTF-8') ?>"
               required>

        <div id="campo-estudiante" hidden>
            <label for="codigo_estudiante">Código de estudiante:</label>
            <input type="text" id="codigo_estudiante"
                   name="codigo_estudiante"
                   value="<?= htmlspecialchars($_POST['codigo_estudiante'] ?? '', ENT_QUOTES, 'UTF-8') ?>">
        </div>

        <div id="campo-docente" hidden>
            <label for="codigo_docente">Código de docente:</label>
            <input type="text" id="codigo_docente"
                   name="codigo_docente"
                   value="<?= htmlspecialchars($_POST['codigo_docente'] ?? '', ENT_QUOTES, 'UTF-8') ?>">

            <label for="telefono">Teléfono (opcional):</label>
            <input type="tel" id="telefono" name="telefono"
                   value="<?= htmlspecialchars($_POST['telefono'] ?? '', ENT_QUOTES, 'UTF-8') ?>">
        </div>

        <hr>

        <label for="nombre_usuario">Nombre de usuario:</label>
        <input type="text" id="nombre_usuario" name="nombre_usuario"
               maxlength="50"
               value="<?= htmlspecialchars($_POST['nombre_usuario'] ?? '', ENT_QUOTES, 'UTF-8') ?>"
               required>

        <label for="contrasena">Contraseña:</label>
        <input type="password" id="contrasena" name="contrasena"
               minlength="8" required>

        <label for="confirmar_contrasena">Confirmar contraseña:</label>
        <input type="password" id="confirmar_contrasena"
               name="confirmar_contrasena" minlength="8" required>

        <button type="submit">Crear cuenta</button>
    </form>

    <p>¿Ya tienes una cuenta? <a href="login.php">Inicia sesión</a></p>
    <p><a href="index.php">Volver al inicio</a></p>

    <script>
        const tipo = document.getElementById('tipo');
        const campoEstudiante = document.getElementById('campo-estudiante');
        const campoDocente = document.getElementById('campo-docente');
        const codigoEstudiante = document.getElementById('codigo_estudiante');
        const codigoDocente = document.getElementById('codigo_docente');

        function actualizarFormulario() {
            const esEstudiante = tipo.value === 'ESTUDIANTE';
            const esDocente = tipo.value === 'DOCENTE';

            campoEstudiante.hidden = !esEstudiante;
            campoDocente.hidden = !esDocente;

            codigoEstudiante.required = esEstudiante;
            codigoDocente.required = esDocente;
        }

        tipo.addEventListener('change', actualizarFormulario);
        actualizarFormulario();
    </script>

</body>
</html>
