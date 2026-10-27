<?php
namespace App\Repositories;

use Database;
use PDO;

class ReservaRepository {
    private PDO $db;

    public function __construct() {
        $this->db = \Database::getConnection();
    }

    public function obtenerReservas(): array {
        $sql = "SELECT * FROM v_reserva_estado ORDER BY fecha_reserva DESC, hora_inicio ASC";
        return $this->db->query($sql)->fetchAll();
    }
}
