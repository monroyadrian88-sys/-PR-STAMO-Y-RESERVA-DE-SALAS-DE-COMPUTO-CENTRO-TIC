<?php
require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/../auth/seguridad.php';

exigirRol('ADMINISTRADOR', 'USUARIO');

require_once __DIR__ . '/../conexion.php';
try {
    $consulta = $conexion->query('SELECT * FROM gestion.sala');
    $salas = $consulta->fetchAll();
} catch (PDOException $e) {
    error_log($e->getMessage());
    exit('No se pudieron consultar las salas. Revisa la tabla gestion.sala.');
}
?>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Salas - Centro TIC</title>
    <link rel="stylesheet" href="../css/estilos.css">
</head>
<body>
    <header>
        <h1>Centro TIC</h1>
        <p>Consulta de salas</p>
    </header>

    <main>
        <h2>Salas registradas</h2>

        <p>
            <a href="../index.php">Volver al inicio</a>
        </p>

        <?php if (count($salas) > 0): ?>
            <table>
                <thead>
                    <tr>
                        <?php foreach (array_keys($salas[0]) as $columna): ?>
                            <th>
                                <?= htmlspecialchars((string) $columna) ?>
                            </th>
                        <?php endforeach; ?>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($salas as $sala): ?>
                        <tr>
                            <?php foreach ($sala as $valor): ?>
                                <td>
                                    <?= htmlspecialchars((string) ($valor ?? '—')) ?>
                                </td>
                            <?php endforeach; ?>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php else: ?>
            <p>No hay salas registradas todavía.</p>
        <?php endif; ?>
    </main>
</body>
</html>