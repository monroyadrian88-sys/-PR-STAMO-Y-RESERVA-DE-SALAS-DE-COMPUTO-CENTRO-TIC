-- =====================================================================
-- DATOS DE PRUEBA - PROYECTO CENTRO TIC (PostgreSQL)
-- Ejecutar DESPUES de PROYECTO_CENTRO_TIC.sql
-- ATENCION: la primera instruccion VACIA todas las tablas y reinicia los ids.
-- =====================================================================
SET search_path TO gestion;

TRUNCATE facultad, programa_academico, curso, programa_curso,
         persona, estudiante, docente, matricula, docente_curso,
         sala, equipo, horario, reserva, aplicacion, sala_aplicacion
RESTART IDENTITY CASCADE;

-- ---------------------------------------------------------------------
-- AREA ACADEMICA
-- ---------------------------------------------------------------------
INSERT INTO facultad (nombre) VALUES
    ('Ingenieria'),                 -- 1
    ('Ciencias Economicas'),        -- 2
    ('Ciencias Basicas');           -- 3

INSERT INTO programa_academico (nombre, nivel_academico, id_facultad) VALUES
    ('Ingenieria de Sistemas',     'PREGRADO', 1),   -- 1
    ('Ingenieria Industrial',      'PREGRADO', 1),   -- 2
    ('Administracion de Empresas', 'PREGRADO', 2),   -- 3
    ('Maestria en Ingenieria',     'MAESTRIA', 1);   -- 4

INSERT INTO curso (nombre) VALUES
    ('Bases de Datos'),              -- 1
    ('Programacion I'),              -- 2
    ('Calculo I'),                   -- 3
    ('Estructuras de Datos'),        -- 4
    ('Contabilidad General'),        -- 5
    ('Redes de Computadores');       -- 6

INSERT INTO programa_curso (id_programa, id_curso, semestre) VALUES
    (1, 1, 5), (1, 2, 1), (1, 3, 1), (1, 4, 3), (1, 6, 6),
    (2, 2, 2), (2, 3, 1),
    (3, 5, 1), (3, 3, 2);

-- ---------------------------------------------------------------------
-- PERSONAS
-- ---------------------------------------------------------------------
INSERT INTO persona (nombres, apellidos, correo) VALUES
    ('Ana',      'Gomez',      'ana.gomez@uni.edu.co'),        -- 1 estudiante
    ('Carlos',   'Perez',      'carlos.perez@uni.edu.co'),     -- 2 estudiante
    ('Laura',    'Martinez',   'laura.martinez@uni.edu.co'),   -- 3 estudiante
    ('Juan',     'Rodriguez',  'juan.rodriguez@uni.edu.co'),   -- 4 estudiante
    ('Sofia',    'Herrera',    'sofia.herrera@uni.edu.co'),    -- 5 estudiante
    ('Miguel',   'Torres',     'miguel.torres@uni.edu.co'),    -- 6 docente
    ('Patricia', 'Ruiz',       'patricia.ruiz@uni.edu.co'),    -- 7 docente
    ('Diego',    'Castro',     'diego.castro@uni.edu.co'),     -- 8 estudiante y docente
    ('Luis',     'Mora',       'luis.mora@externo.com');       -- 9 NI estudiante NI docente

INSERT INTO estudiante (id_persona, codigo_estudiante) VALUES
    (1, 'E2026001'), (2, 'E2026002'), (3, 'E2026003'),
    (4, 'E2026004'), (5, 'E2026005'), (8, 'E2026008');

INSERT INTO docente (id_persona, codigo_docente, telefono) VALUES
    (6, 'D001', '3001234567'),
    (7, 'D002', '3109876543'),
    (8, 'D003', '3205557788');

INSERT INTO matricula (id_persona, id_curso) VALUES
    (1, 1), (1, 2), (1, 4),
    (2, 1), (2, 3),
    (3, 1), (3, 2),
    (4, 5), (4, 3),
    (5, 6),
    (8, 1);

INSERT INTO docente_curso (id_persona, id_curso) VALUES
    (6, 1), (6, 4),
    (7, 2), (7, 3), (7, 5),
    (8, 6);

-- ---------------------------------------------------------------------
-- SALAS, EQUIPOS, HORARIOS, APLICACIONES
-- ---------------------------------------------------------------------
INSERT INTO sala (nombre, edificio, capacidad, estado) VALUES
    ('Sala 101',             'Edificio A',  30, 'DISPONIBLE'),      -- 1
    ('Sala 102',             'Edificio A',  25, 'DISPONIBLE'),      -- 2
    ('Laboratorio de Redes', 'Edificio B',  20, 'DISPONIBLE'),      -- 3
    ('Auditorio',            'Edificio C', 120, 'MANTENIMIENTO');   -- 4

INSERT INTO equipo (codigo_inventario, marca, modelo, estado, id_sala) VALUES
    ('EQ-001', 'Dell',  'OptiPlex 7010',  'OPERATIVO',     1),
    ('EQ-002', 'Dell',  'OptiPlex 7010',  'OPERATIVO',     1),
    ('EQ-003', 'Epson', 'PowerLite X49',  'OPERATIVO',     1),
    ('EQ-004', 'HP',    'ProDesk 400 G9', 'OPERATIVO',     2),
    ('EQ-005', 'Cisco', 'Catalyst 2960',  'OPERATIVO',     3),
    ('EQ-006', 'HP',    'ProDesk 400 G9', 'EN_REPARACION', 2);

INSERT INTO horario (dia_semana, hora_inicio, hora_fin, id_sala)
SELECT d, '07:00', '18:00', 1
FROM unnest(ARRAY['LUNES','MARTES','MIERCOLES','JUEVES','VIERNES']) AS d;

INSERT INTO horario (dia_semana, hora_inicio, hora_fin, id_sala)
SELECT d, '08:00', '20:00', 2
FROM unnest(ARRAY['LUNES','MARTES','MIERCOLES','JUEVES','VIERNES']) AS d;

INSERT INTO horario (dia_semana, hora_inicio, hora_fin, id_sala)
SELECT d, '07:00', '17:00', 3
FROM unnest(ARRAY['LUNES','MARTES','MIERCOLES','JUEVES','VIERNES']) AS d;

-- El auditorio tiene horario pero esta en mantenimiento.
INSERT INTO horario (dia_semana, hora_inicio, hora_fin, id_sala)
VALUES ('LUNES', '08:00', '18:00', 4);

INSERT INTO aplicacion (nombre, version, descripcion) VALUES
    ('Visual Studio Code',  '1.95', 'Editor de codigo'),            -- 1
    ('PostgreSQL',          '18',   'Motor de base de datos'),      -- 2
    ('MySQL Workbench',     '8.0',  'Cliente grafico para MySQL'),  -- 3
    ('Cisco Packet Tracer', '8.2',  'Simulador de redes'),          -- 4
    ('Python',              '3.12', 'Lenguaje de programacion');    -- 5

INSERT INTO sala_aplicacion (id_sala, id_aplicacion) VALUES
    (1, 1), (1, 2), (1, 5),
    (2, 1), (2, 3), (2, 5),
    (3, 4), (3, 1);

-- ---------------------------------------------------------------------
-- RESERVAS
-- No se indica el estado: lo decide el sistema.
-- Fechas relativas a hoy:  proximo lunes = date_trunc('week', CURRENT_DATE)::date + 7
--                          martes = +8, miercoles = +9
-- Se insertan una por una y en orden: ese orden es la antiguedad.
-- ---------------------------------------------------------------------
-- 1) Lunes 08-10, sala 1, Miguel (docente)      -> APROBADA (sin conflicto)
INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
VALUES (date_trunc('week', CURRENT_DATE)::date + 7, '08:00', '10:00', 1, 6);

-- 2) Lunes 10-12, sala 1, Ana (estudiante)      -> APROBADA (pegada a la 1, no se cruza)
INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
VALUES (date_trunc('week', CURRENT_DATE)::date + 7, '10:00', '12:00', 1, 1);

-- 3) Lunes 09-11, sala 1, Carlos                -> PENDIENTE (choca con la 1 y la 2)
INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
VALUES (date_trunc('week', CURRENT_DATE)::date + 7, '09:00', '11:00', 1, 2);

-- 4) Lunes 09-10, sala 1, Laura                 -> PENDIENTE (choca con la 1; es mas nueva que la 3)
INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
VALUES (date_trunc('week', CURRENT_DATE)::date + 7, '09:00', '10:00', 1, 3);

-- 5) Martes 14-16, sala 3, Patricia (docente)   -> APROBADA
INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
VALUES (date_trunc('week', CURRENT_DATE)::date + 8, '14:00', '16:00', 3, 7);

-- 6) Miercoles 09-11, sala 2, Diego (ambos)     -> APROBADA
INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
VALUES (date_trunc('week', CURRENT_DATE)::date + 9, '09:00', '11:00', 2, 8);

-- =====================================================================
-- VERIFICACION
-- =====================================================================

-- Conteo por tabla (esperado: 3,4,6,9,9,6,3,11,6,4,6,16,6,5,8)
SELECT 'facultad' AS tabla, count(*) FROM facultad
UNION ALL SELECT 'programa_academico', count(*) FROM programa_academico
UNION ALL SELECT 'curso', count(*) FROM curso
UNION ALL SELECT 'programa_curso', count(*) FROM programa_curso
UNION ALL SELECT 'persona', count(*) FROM persona
UNION ALL SELECT 'estudiante', count(*) FROM estudiante
UNION ALL SELECT 'docente', count(*) FROM docente
UNION ALL SELECT 'matricula', count(*) FROM matricula
UNION ALL SELECT 'docente_curso', count(*) FROM docente_curso
UNION ALL SELECT 'sala', count(*) FROM sala
UNION ALL SELECT 'equipo', count(*) FROM equipo
UNION ALL SELECT 'horario', count(*) FROM horario
UNION ALL SELECT 'reserva', count(*) FROM reserva
UNION ALL SELECT 'aplicacion', count(*) FROM aplicacion
UNION ALL SELECT 'sala_aplicacion', count(*) FROM sala_aplicacion;

-- Estado de las reservas. Esperado: 1,2,5,6 APROBADA y 3,4 PENDIENTE.
SELECT r.id_reserva, s.nombre AS sala, r.fecha_reserva, r.hora_inicio, r.hora_fin,
       r.estado, p.nombres || ' ' || p.apellidos AS solicitante
FROM reserva r
JOIN sala s    ON s.id_sala = r.id_sala
JOIN persona p ON p.id_persona = r.id_persona
ORDER BY r.fecha_reserva, s.nombre, r.hora_inicio, r.id_reserva;

-- =====================================================================
-- DEMO DE LA COLA (descomenta y ejecuta de a una). Orden ESTRICTO: una pendiente
-- anterior, vigente y viable bloquea a las mas nuevas que se le cruzan.
--  1) Cancelar la 1 (lunes 08-10): la 3 (09-11) sigue pendiente porque choca con la 2
--     (10-12); la 4 (09-10) TAMBIEN sigue pendiente porque espera detras de la 3.
--  2) Cancelar la 2: se aprueba la 3 (09-11) y la 4 sigue pendiente (choca con la 3).
--  3) Cancelar la 3: se aprueba la 4 (09-10).
-- =====================================================================
-- UPDATE reserva SET estado = 'CANCELADA' WHERE id_reserva = 1;
-- SELECT id_reserva, hora_inicio, hora_fin, estado FROM reserva WHERE id_sala = 1 ORDER BY id_reserva;
-- UPDATE reserva SET estado = 'CANCELADA' WHERE id_reserva = 2;
-- SELECT id_reserva, hora_inicio, hora_fin, estado FROM reserva WHERE id_sala = 1 ORDER BY id_reserva;
-- UPDATE reserva SET estado = 'CANCELADA' WHERE id_reserva = 3;
-- SELECT id_reserva, hora_inicio, hora_fin, estado FROM reserva WHERE id_sala = 1 ORDER BY id_reserva;

-- =====================================================================
-- PRUEBAS QUE DEBEN FALLAR (descomenta de a una)
-- =====================================================================

-- 1) Persona que no es estudiante ni docente
-- INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
-- VALUES (date_trunc('week', CURRENT_DATE)::date + 8, '10:00', '11:00', 1, 9);

-- 2) Fuera del horario de la sala (cierra a las 18:00)
-- INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
-- VALUES (date_trunc('week', CURRENT_DATE)::date + 7, '19:00', '20:00', 1, 3);

-- 3) Sabado: la sala no tiene horario ese dia
-- INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
-- VALUES (date_trunc('week', CURRENT_DATE)::date + 12, '09:00', '10:00', 1, 3);

-- 4) Sala en mantenimiento (auditorio)
-- INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
-- VALUES (date_trunc('week', CURRENT_DATE)::date + 7, '09:00', '10:00', 4, 3);

-- 5) Fecha pasada
-- INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
-- VALUES (CURRENT_DATE - 1, '09:00', '10:00', 1, 3);

-- 6) Hora de fin menor que la de inicio (CHECK)
-- INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
-- VALUES (date_trunc('week', CURRENT_DATE)::date + 7, '15:00', '14:00', 1, 3);

-- 7) Un docente que no es estudiante no puede matricularse
-- INSERT INTO matricula (id_persona, id_curso) VALUES (6, 1);

-- 8) Bloque de horario que se cruza con otro de la misma sala y dia
-- INSERT INTO horario (dia_semana, hora_inicio, hora_fin, id_sala)
-- VALUES ('LUNES', '10:00', '12:00', 1);

-- 9) Aprobar a mano una reserva que choca con una aprobada (la 3 choca con la 2)
-- UPDATE reserva SET estado = 'APROBADA' WHERE id_reserva = 3;

-- 10) Reactivar una reserva cancelada (primero ejecuta la demo de la cola)
-- UPDATE reserva SET estado = 'PENDIENTE' WHERE id_reserva = 1;

-- 11) Aprobar a mano una pendiente cuando la sala ya no esta disponible.
--     Pone la sala 1 en mantenimiento ANTES de cancelar: la cola no aprueba nada
--     y la reserva 3 sigue pendiente. Luego el UPDATE manual debe fallar.
-- UPDATE sala SET estado = 'MANTENIMIENTO' WHERE id_sala = 1;
-- UPDATE reserva SET estado = 'CANCELADA' WHERE id_reserva IN (1, 2, 4);
-- UPDATE reserva SET estado = 'APROBADA' WHERE id_reserva = 3;   -- ERROR: sala no disponible
-- UPDATE sala SET estado = 'DISPONIBLE' WHERE id_sala = 1;       -- (restaurar)

-- Estado "efectivo": muestra VENCIDA aunque vencer_reservas() no haya corrido.
-- SELECT id_reserva, estado, estado_efectivo FROM v_reserva_estado ORDER BY id_reserva;
