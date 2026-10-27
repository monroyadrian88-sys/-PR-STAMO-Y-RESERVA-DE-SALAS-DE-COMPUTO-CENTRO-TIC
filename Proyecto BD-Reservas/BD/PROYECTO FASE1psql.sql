-- =====================================================================
-- Modelo relacional: gestion academica, personas, salas y reservas
-- Motor: PostgreSQL 12+
-- Orden: se crean primero las tablas que no dependen de otras.
-- =====================================================================

DROP SCHEMA IF EXISTS gestion CASCADE;
CREATE SCHEMA gestion;
SET search_path TO gestion;

-- ---------------------------------------------------------------------
-- AREA ACADEMICA
-- ---------------------------------------------------------------------
CREATE TABLE facultad (
    id_facultad  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE programa_academico (
    id_programa      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre           VARCHAR(100) NOT NULL,
    nivel_academico  VARCHAR(30)  NOT NULL
        CHECK (nivel_academico IN ('TECNICO','TECNOLOGO','PREGRADO','ESPECIALIZACION','MAESTRIA','DOCTORADO')),
    id_facultad      INT NOT NULL
        REFERENCES facultad (id_facultad) ON UPDATE CASCADE ON DELETE RESTRICT,
    UNIQUE (nombre, id_facultad)
);

CREATE TABLE curso (
    id_curso  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre    VARCHAR(100) NOT NULL
);

-- N:M entre programa y curso. El semestre depende de la pareja programa-curso.
CREATE TABLE programa_curso (
    id_programa  INT NOT NULL
        REFERENCES programa_academico (id_programa) ON UPDATE CASCADE ON DELETE CASCADE,
    id_curso     INT NOT NULL
        REFERENCES curso (id_curso) ON UPDATE CASCADE ON DELETE CASCADE,
    semestre     SMALLINT NOT NULL CHECK (semestre BETWEEN 1 AND 14),
    PRIMARY KEY (id_programa, id_curso)
);

-- ---------------------------------------------------------------------
-- AREA DE PERSONAS (especializacion parcial y superpuesta)
-- ---------------------------------------------------------------------
CREATE TABLE persona (
    id_persona  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombres     VARCHAR(100) NOT NULL,
    apellidos   VARCHAR(100) NOT NULL,
    correo      VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE estudiante (
    id_persona         INT PRIMARY KEY
        REFERENCES persona (id_persona) ON UPDATE CASCADE ON DELETE CASCADE,
    codigo_estudiante  VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE docente (
    id_persona      INT PRIMARY KEY
        REFERENCES persona (id_persona) ON UPDATE CASCADE ON DELETE CASCADE,
    codigo_docente  VARCHAR(20) NOT NULL UNIQUE,
    telefono        VARCHAR(20)
);

-- Matricula: solo estudiantes (id_persona apunta a ESTUDIANTE).
CREATE TABLE matricula (
    id_persona  INT NOT NULL
        REFERENCES estudiante (id_persona) ON UPDATE CASCADE ON DELETE CASCADE,
    id_curso    INT NOT NULL
        REFERENCES curso (id_curso) ON UPDATE CASCADE ON DELETE CASCADE,
    PRIMARY KEY (id_persona, id_curso)
);

-- Asignacion de docentes a cursos (resuelve la N:M IMPARTE).
CREATE TABLE docente_curso (
    id_persona  INT NOT NULL
        REFERENCES docente (id_persona) ON UPDATE CASCADE ON DELETE CASCADE,
    id_curso    INT NOT NULL
        REFERENCES curso (id_curso) ON UPDATE CASCADE ON DELETE CASCADE,
    PRIMARY KEY (id_persona, id_curso)
);

-- ---------------------------------------------------------------------
-- AREA DE SALAS Y RESERVAS
-- ---------------------------------------------------------------------
CREATE TABLE sala (
    id_sala    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre     VARCHAR(80) NOT NULL,
    edificio   VARCHAR(80) NOT NULL,
    capacidad  INT NOT NULL CHECK (capacidad > 0),
    estado     VARCHAR(20) NOT NULL DEFAULT 'DISPONIBLE'
        CHECK (estado IN ('DISPONIBLE','MANTENIMIENTO','INACTIVA')),
    UNIQUE (nombre, edificio)
);

CREATE TABLE equipo (
    id_equipo          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_inventario  VARCHAR(30) NOT NULL UNIQUE,
    marca              VARCHAR(50),
    modelo             VARCHAR(50),
    estado             VARCHAR(20) NOT NULL DEFAULT 'OPERATIVO'
        CHECK (estado IN ('OPERATIVO','EN_REPARACION','BAJA')),
    id_sala            INT NOT NULL
        REFERENCES sala (id_sala) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Horario de funcionamiento de cada sala.
CREATE TABLE horario (
    id_horario   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dia_semana   VARCHAR(10) NOT NULL
        CHECK (dia_semana IN ('LUNES','MARTES','MIERCOLES','JUEVES','VIERNES','SABADO','DOMINGO')),
    hora_inicio  TIME NOT NULL,
    hora_fin     TIME NOT NULL,
    id_sala      INT NOT NULL
        REFERENCES sala (id_sala) ON UPDATE CASCADE ON DELETE CASCADE,
    CHECK (hora_fin > hora_inicio),
    UNIQUE (id_sala, dia_semana, hora_inicio)
);

CREATE TABLE reserva (
    id_reserva       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_solicitud  DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_reserva    DATE NOT NULL,
    hora_inicio      TIME NOT NULL,
    hora_fin         TIME NOT NULL,
    estado           VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado IN ('PENDIENTE','APROBADA','RECHAZADA','CANCELADA')),
    id_sala          INT NOT NULL
        REFERENCES sala (id_sala) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_persona       INT NOT NULL
        REFERENCES persona (id_persona) ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (hora_fin > hora_inicio),
    CHECK (fecha_reserva >= fecha_solicitud)
);

CREATE TABLE aplicacion (
    id_aplicacion  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,
    version        VARCHAR(30)  NOT NULL,
    descripcion    TEXT,
    UNIQUE (nombre, version)
);

CREATE TABLE sala_aplicacion (
    id_sala        INT NOT NULL
        REFERENCES sala (id_sala) ON UPDATE CASCADE ON DELETE CASCADE,
    id_aplicacion  INT NOT NULL
        REFERENCES aplicacion (id_aplicacion) ON UPDATE CASCADE ON DELETE CASCADE,
    PRIMARY KEY (id_sala, id_aplicacion)
);

-- ---------------------------------------------------------------------
-- INDICES sobre llaves foraneas que no son prefijo de una PK
-- ---------------------------------------------------------------------
CREATE INDEX idx_programa_facultad   ON programa_academico (id_facultad);
CREATE INDEX idx_programa_curso_cur  ON programa_curso (id_curso);
CREATE INDEX idx_matricula_curso     ON matricula (id_curso);
CREATE INDEX idx_docente_curso_cur   ON docente_curso (id_curso);
CREATE INDEX idx_equipo_sala         ON equipo (id_sala);
CREATE INDEX idx_horario_sala        ON horario (id_sala);
CREATE INDEX idx_reserva_sala_fecha  ON reserva (id_sala, fecha_reserva);
CREATE INDEX idx_reserva_persona     ON reserva (id_persona);
CREATE INDEX idx_sala_app_app        ON sala_aplicacion (id_aplicacion);

-- =====================================================================
-- REGLAS DE NEGOCIO DE LAS RESERVAS (funciones + triggers)
-- =====================================================================
CREATE OR REPLACE FUNCTION validar_reserva()
RETURNS TRIGGER AS $$
DECLARE
    v_estado_sala TEXT;
    v_dia         TEXT;
BEGIN
    -- No se puede reservar en una fecha pasada (solo al crear).
    IF TG_OP = 'INSERT' AND NEW.fecha_reserva < CURRENT_DATE THEN
        RAISE EXCEPTION 'No se puede reservar en una fecha pasada';
    END IF;

    -- Solo se validan las reservas que ocupan la sala.
    IF NEW.estado IN ('PENDIENTE','APROBADA') THEN

        -- Bloquea la fila de la sala hasta terminar la transaccion: dos
        -- reservas simultaneas para la misma sala se procesan una por una.
        SELECT estado INTO v_estado_sala
        FROM sala WHERE id_sala = NEW.id_sala FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'La sala no existe';
        END IF;

        -- 1) La sala debe estar disponible.
        IF v_estado_sala <> 'DISPONIBLE' THEN
            RAISE EXCEPTION 'La sala no esta disponible para reservas';
        END IF;

        -- 2) El dia y las horas deben caer dentro del horario de la sala.
        v_dia := (ARRAY['LUNES','MARTES','MIERCOLES','JUEVES','VIERNES','SABADO','DOMINGO'])
                 [EXTRACT(ISODOW FROM NEW.fecha_reserva)::INT];

        IF NOT EXISTS (
            SELECT 1 FROM horario h
            WHERE h.id_sala = NEW.id_sala
              AND h.dia_semana = v_dia
              AND h.hora_inicio <= NEW.hora_inicio
              AND h.hora_fin    >= NEW.hora_fin
        ) THEN
            RAISE EXCEPTION 'La reserva queda fuera del horario de funcionamiento de la sala';
        END IF;

        -- 3) No puede cruzarse con otra reserva activa de la misma sala.
        IF EXISTS (
            SELECT 1 FROM reserva r
            WHERE r.id_sala = NEW.id_sala
              AND r.fecha_reserva = NEW.fecha_reserva
              AND r.estado IN ('PENDIENTE','APROBADA')
              AND r.id_reserva IS DISTINCT FROM NEW.id_reserva
              AND r.hora_inicio < NEW.hora_fin
              AND r.hora_fin    > NEW.hora_inicio
        ) THEN
            RAISE EXCEPTION 'La sala ya tiene una reserva que se cruza en ese horario';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_reserva
BEFORE INSERT OR UPDATE ON reserva
FOR EACH ROW EXECUTE FUNCTION validar_reserva();

-- Los bloques de horario de una misma sala y dia no pueden solaparse.
CREATE OR REPLACE FUNCTION validar_horario()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM horario h
        WHERE h.id_sala = NEW.id_sala
          AND h.dia_semana = NEW.dia_semana
          AND h.id_horario IS DISTINCT FROM NEW.id_horario
          AND h.hora_inicio < NEW.hora_fin
          AND h.hora_fin    > NEW.hora_inicio
    ) THEN
        RAISE EXCEPTION 'El horario se cruza con otro bloque de la misma sala y dia';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_horario
BEFORE INSERT OR UPDATE ON horario
FOR EACH ROW EXECUTE FUNCTION validar_horario();

-- ---------------------------------------------------------------------
-- DATOS DE PRUEBA (opcional, para verificar que todo funciona)
-- ---------------------------------------------------------------------
INSERT INTO facultad (nombre) VALUES ('Ingenieria');
INSERT INTO programa_academico (nombre, nivel_academico, id_facultad)
    VALUES ('Ingenieria de Sistemas', 'PREGRADO', 1);
INSERT INTO curso (nombre) VALUES ('Bases de Datos');
INSERT INTO programa_curso VALUES (1, 1, 5);

INSERT INTO persona (nombres, apellidos, correo) VALUES ('Ana', 'Gomez', 'ana@uni.edu.co');
INSERT INTO estudiante VALUES (1, 'E2024001');
INSERT INTO matricula VALUES (1, 1);

INSERT INTO sala (nombre, edificio, capacidad) VALUES ('Sala 101', 'Edificio A', 30);
INSERT INTO horario (dia_semana, hora_inicio, hora_fin, id_sala)
    VALUES ('LUNES', '07:00', '18:00', 1);

-- ---------------------------------------------------------------------
-- PRUEBAS (ajusta las fechas a un lunes futuro; 2026-11-02 es lunes)
-- ---------------------------------------------------------------------
-- Valida: dentro del horario
-- INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
--     VALUES ('2026-11-02', '08:00', '10:00', 1, 1);
-- Debe fallar: se cruza con la anterior
-- INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
--     VALUES ('2026-11-02', '09:00', '11:00', 1, 1);
-- Debe fallar: fuera del horario (20:00)
-- INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
--     VALUES ('2026-11-02', '19:00', '20:00', 1, 1);
-- Debe fallar: martes, la sala no tiene horario ese dia
-- INSERT INTO reserva (fecha_reserva, hora_inicio, hora_fin, id_sala, id_persona)
--     VALUES ('2026-11-03', '08:00', '10:00', 1, 1);
