
<?php
require_once __DIR__ . '/../auth/seguridad.php';

exigirRol('USUARIO');
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Panel de usuario - Centro TIC</title>
    <link rel="stylesheet" href="../css/estilos.css">
</head>
<body>

    <h1>Panel de usuario</h1>

    <p>
        Bienvenido,
        <?= htmlspecialchars(
            $_SESSION['nombre_completo'] ?? '',
            ENT_QUOTES,
            'UTF-8'
        ) ?>
    </p>

    <p>Desde aquí podrás consultar los servicios del Centro TIC.</p>

    <ul>
        <li><a href="../salas/listar.php">Consultar salas</a></li>
    </ul>

    <a href="../logout.php">Cerrar sesión</a>

</body>
</html>
