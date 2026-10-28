
<?php

if (session_status() !== PHP_SESSION_ACTIVE) {
    // Configurar la cookie de sesión antes de iniciarla.
    ini_set('session.use_strict_mode', '1');

    session_set_cookie_params([
        'httponly' => true,
        'secure' => !empty($_SERVER['HTTPS'])
            && $_SERVER['HTTPS'] !== 'off',
        'samesite' => 'Lax',
        'path' => '/'
    ]);

    session_start();
}

/**
 * Comprueba que el usuario haya iniciado sesión.
 */
function exigirLogin(): void
{
    if (empty($_SESSION['id_usuario'])) {
        header('Location: /centro_tic/login.php');
        exit;
    }
}

/**
 * Comprueba que el usuario tenga uno de los roles permitidos.
 */
function exigirRol(string ...$rolesPermitidos): void
{
    exigirLogin();

    $rol = $_SESSION['rol'] ?? '';

    if (!in_array($rol, $rolesPermitidos, true)) {
        http_response_code(403);
        exit('403 - No tienes permiso para acceder a esta página.');
    }
}
