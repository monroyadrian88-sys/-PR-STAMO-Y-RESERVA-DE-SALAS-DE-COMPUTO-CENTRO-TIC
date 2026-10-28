<?php

session_start();

?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Centro TIC</title>
    <link rel="stylesheet" href="css/estilos.css">
</head>
<body>
    <?php if (isset($_SESSION['id_usuario'])): ?>

    <p>
        Bienvenido,
        <?= htmlspecialchars(
            $_SESSION['nombre_completo'],
            ENT_QUOTES,
            'UTF-8'
        ) ?>
    </p>

    <p>
        Rol:
        <?= htmlspecialchars(
            $_SESSION['rol'],
            ENT_QUOTES,
            'UTF-8'
        ) ?>
    </p>

    <a href="logout.php">Cerrar sesión</a>

<?php else: ?>

    <p>No has iniciado sesión.</p>
    <a href="login.php">Iniciar sesión</a>
    <a href="registro.php">Registrarse</a>

<?php endif; ?>
    <header>
        <h1>Centro TIC</h1>
        <p>Sistema de gestión académica y reservas de salas</p>
    </header>

    <main>
        <h2>Panel principal</h2>
        <p>Bienvenido al sistema de gestión del Centro TIC.</p>

        <nav>
            <a href="salas/listar.php">Consultar salas</a>
        </nav>
    </main>
</body>
</html>