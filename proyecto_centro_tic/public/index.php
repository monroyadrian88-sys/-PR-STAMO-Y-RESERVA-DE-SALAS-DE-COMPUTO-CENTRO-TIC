<?php
require_once __DIR__ . '/../vendor/autoload.php';

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

echo "<h1>Bienvenido al Sistema Centro TIC</h1>";
echo "<p>Ruta actual: " . htmlspecialchars($uri) . "</p>";
