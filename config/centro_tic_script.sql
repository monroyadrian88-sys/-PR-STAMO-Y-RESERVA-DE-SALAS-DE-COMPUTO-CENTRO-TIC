-- =====================================================================
-- PROYECTO CENTRO TIC
-- Base de datos: gestion academica, salas, equipos y reservas
-- Motor: PostgreSQL 12+
--
-- REGLAS:
-- * Solo estudiantes y docentes pueden reservar.
-- * Las solicitudes validas se aprueban automaticamente si no se cruzan
--   con una reserva APROBADA.
-- * Solo APROBADA bloquea el horario.
-- * Si hay cruce con una APROBADA, la solicitud queda PENDIENTE.
-- * La cola se procesa por fecha de reserva, antiguedad exacta de solicitud
--   y luego id_reserva.
-- * Una reserva pendiente que ya empezo pasa a VENCIDA.
-- * Las operaciones de reservas y horarios de una sala se serializan
--   bloqueando la fila de sala.
--
-- IMPORTANTE: DROP SCHEMA elimina todos los objetos y datos existentes
-- del esquema gestion.
-- =====================================================================

DROP SCHEMA IF EXISTS gestion CASCADE;
CREATE SCHEMA gestion;
SET search_path TO gestion;

-- ---------------------------------------------------------------------
-- AREA ACADEMICA
-- ---------------------------------------------------------------------
CREATE TABLE facultad (
    id_facultad INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE programa_academico (
    id_programa INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    nivel_academico VARCHAR(30) NOT NULL
        CHECK (nivel_academico IN (
            'TECNICO', 'TECNOLOGO', 'PREGRADO',
            'ESPECIALIZACION', 'MAESTRIA', 'DOCTORADO'
        )),
    id_facultad INT NOT NULL
        REFERENCES facultad(id_facultad)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    UNIQUE (nombre, id_facultad)
);

CREATE TABLE curso (
    id_curso INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE programa_curso (
    id_programa INT NOT NULL
        REFERENCES programa_academico(id_programa)
        ON UPDATE CASCADE ON DELETE CASCADE,
    id_curso INT NOT NULL
        REFERENCES curso(id_curso)
        ON UPDATE CASCADE ON DELETE CASCADE,
    semestre SMALLINT NOT NULL CHECK (semestre BETWEEN 1 AND 14),
    PRIMARY KEY (id_programa, id_curso)
);

-- Especializacion parcial y superpuesta: una persona puede ser estudiante,
-- docente, ambos o ninguno.
CREATE TABLE persona (
    id_persona INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE estudiante (
    id_persona INT PRIMARY KEY
        REFERENCES persona(id_persona)
        ON UPDATE CASCADE ON DELETE CASCADE,
    codigo_estudiante VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE docente (
    id_persona INT PRIMARY KEY
        REFERENCES persona(id_persona)
        ON UPDATE CASCADE ON DELETE CASCADE,
    codigo_docente VARCHAR(20) NOT NULL UNIQUE,
    telefono VARCHAR(20)
);

CREATE TABLE matricula (
    id_persona INT NOT NULL
        REFERENCES estudiante(id_persona)
        ON UPDATE CASCADE ON DELETE CASCADE,
    id_curso INT NOT NULL
        REFERENCES curso(id_curso)
        ON UPDATE CASCADE ON DELETE CASCADE,
    PRIMARY KEY (id_persona, id_curso)
);

CREATE TABLE docente_curso (
    id_persona INT NOT NULL
        REFERENCES docente(id_persona)
        ON UPDATE CASCADE ON DELETE CASCADE,
    id_curso INT NOT NULL
        REFERENCES curso(id_curso)
        ON UPDATE CASCADE ON DELETE CASCADE,
    PRIMARY KEY (id_persona, id_curso)
);

-- ---------------------------------------------------------------------
-- SALAS, EQUIPOS, HORARIOS Y APLICACIONES
-- ---------------------------------------------------------------------
CREATE TABLE sala (
    id_sala INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    edificio VARCHAR(80) NOT NULL,
    capacidad INT NOT NULL CHECK (capacidad > 0),
    estado VARCHAR(20) NOT NULL DEFAULT 'DISPONIBLE'
        CHECK (estado IN ('DISPONIBLE', 'MANTENIMIENTO', 'INACTIVA')),
    UNIQUE (nombre, edificio)
);

CREATE TABLE equipo (
    id_equipo INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_inventario VARCHAR(30) NOT NULL UNIQUE,
    marca VARCHAR(50),
    modelo VARCHAR(50),
    estado VARCHAR(20) NOT NULL DEFAULT 'OPERATIVO'
        CHECK (estado IN ('OPERATIVO', 'EN_REPARACION', 'BAJA')),
    id_sala INT NOT NULL
        REFERENCES sala(id_sala)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE horario (
    id_horario INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dia_semana VARCHAR(10) NOT NULL
        CHECK (dia_semana IN (
            'LUNES', 'MARTES', 'MIERCOLES', 'JUEVES',
            'VIERNES', 'SABADO', 'DOMINGO'
        )),
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    id_sala INT NOT NULL
        REFERENCES sala(id_sala)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CHECK (hora_fin > hora_inicio),
    UNIQUE (id_sala, dia_semana, hora_inicio)
);

CREATE TABLE aplicacion (
    id_aplicacion INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    version VARCHAR(30) NOT NULL,
    descripcion TEXT,
    UNIQUE (nombre, version)
);

CREATE TABLE sala_aplicacion (
    id_sala INT NOT NULL
        REFERENCES sala(id_sala)
        ON UPDATE CASCADE ON DELETE CASCADE,
    id_aplicacion INT NOT NULL
        REFERENCES aplicacion(id_aplicacion)
        ON UPDATE CASCADE ON DELETE CASCADE,
    PRIMARY KEY (id_sala, id_aplicacion)
);

-- ---------------------------------------------------------------------
-- RESERVAS
-- ---------------------------------------------------------------------
CREATE TABLE reserva (
    id_reserva INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_solicitud TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    fecha_reserva DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado IN (
            'PENDIENTE', 'APROBADA', 'RECHAZADA', 'CANCELADA', 'VENCIDA'
        )),
    id_sala INT NOT NULL
        REFERENCES sala(id_sala)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    id_persona INT NOT NULL
        REFERENCES persona(id_persona)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (hora_fin > hora_inicio)
);

-- ---------------------------------------------------------------------
-- INDICES
-- ---------------------------------------------------------------------
CREATE INDEX idx_programa_facultad ON programa_academico(id_facultad);
CREATE INDEX idx_programa_curso_cur ON programa_curso(id_curso);
CREATE INDEX idx_matricula_curso ON matricula(id_curso);
CREATE INDEX idx_docente_curso_cur ON docente_curso(id_curso);
CREATE INDEX idx_equipo_sala ON equipo(id_sala);
CREATE INDEX idx_horario_sala ON horario(id_sala);
CREATE INDEX idx_sala_app_app ON sala_aplicacion(id_aplicacion);
CREATE INDEX idx_reserva_persona ON reserva(id_persona);
CREATE INDEX idx_reserva_aprobadas ON reserva(id_sala, fecha_reserva)
    WHERE estado = 'APROBADA';
CREATE INDEX idx_reserva_cola
    ON reserva(id_sala, fecha_reserva, fecha_solicitud, id_reserva)
    WHERE estado = 'PENDIENTE';

-- ---------------------------------------------------------------------
-- FUNCIONES AUXILIARES
-- ---------------------------------------------------------------------
CREATE FUNCTION dia_semana_es(p_fecha DATE)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
SET search_path = gestion, pg_temp
AS $$
    SELECT (ARRAY['LUNES','MARTES','MIERCOLES','JUEVES','VIERNES','SABADO','DOMINGO'])
           [EXTRACT(ISODOW FROM p_fecha)::INT];
$$;

CREATE FUNCTION reserva_dentro_horario(
    p_id_sala INT, p_fecha DATE, p_ini TIME, p_fin TIME
)
RETURNS BOOLEAN
LANGUAGE sql STABLE
SET search_path = gestion, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM horario h
        WHERE h.id_sala = p_id_sala
          AND h.dia_semana = dia_semana_es(p_fecha)
          AND h.hora_inicio <= p_ini
          AND h.hora_fin >= p_fin
    );
$$;

CREATE FUNCTION persona_puede_reservar(p_id_persona INT)
RETURNS BOOLEAN
LANGUAGE sql STABLE
SET search_path = gestion, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM estudiante e WHERE e.id_persona = p_id_persona
    ) OR EXISTS (
        SELECT 1 FROM docente d WHERE d.id_persona = p_id_persona
    );
$$;

CREATE FUNCTION hay_conflicto_aprobado(
    p_id_sala INT, p_fecha DATE, p_ini TIME, p_fin TIME, p_excluir INT
)
RETURNS BOOLEAN
LANGUAGE sql STABLE
SET search_path = gestion, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM reserva r
        WHERE r.id_sala = p_id_sala
          AND r.fecha_reserva = p_fecha
          AND r.estado = 'APROBADA'
          AND r.id_reserva IS DISTINCT FROM p_excluir
          AND r.hora_inicio < p_fin
          AND r.hora_fin > p_ini
    );
$$;

-- Hay una pendiente MAS ANTIGUA, vigente y viable que se cruza con la franja.
-- Se usa tanto al insertar como en la cola para que el orden sea el mismo.
-- "Vigente": su hora de inicio no ha pasado. "Viable": su solicitante sigue
-- siendo estudiante/docente y la franja cabe en el horario actual de la sala;
-- una pendiente que ya no podria aprobarse no bloquea a las demas.
CREATE FUNCTION hay_pendiente_anterior(
    p_id_sala INT, p_fecha DATE, p_ini TIME, p_fin TIME,
    p_fecha_solicitud TIMESTAMPTZ, p_id_reserva INT
)
RETURNS BOOLEAN
LANGUAGE sql STABLE
SET search_path = gestion, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM reserva p
        WHERE p.id_sala = p_id_sala
          AND p.fecha_reserva = p_fecha
          AND p.estado = 'PENDIENTE'
          AND p.hora_inicio < p_fin
          AND p.hora_fin > p_ini
          AND (p.fecha_solicitud, p.id_reserva) < (p_fecha_solicitud, p_id_reserva)
          AND p.fecha_reserva + p.hora_inicio >= LOCALTIMESTAMP
          AND persona_puede_reservar(p.id_persona)
          AND reserva_dentro_horario(p.id_sala, p.fecha_reserva, p.hora_inicio, p.hora_fin)
    );
$$;

-- ---------------------------------------------------------------------
-- VALIDACION CENTRAL: aplica al insertar y al intentar aprobar.
-- La antiguedad de la solicitud la fija el servidor.
-- ---------------------------------------------------------------------
CREATE FUNCTION reserva_antes()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = gestion, pg_temp
AS $$
DECLARE
    v_estado_sala TEXT;
    v_validar BOOLEAN := FALSE;
    v_conflicto BOOLEAN := FALSE;
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.fecha_solicitud := clock_timestamp();
        NEW.estado := 'PENDIENTE';
        v_validar := TRUE;
    ELSE
        NEW.fecha_solicitud := OLD.fecha_solicitud;

        IF OLD.estado IN ('CANCELADA', 'RECHAZADA', 'VENCIDA')
           AND NEW.estado <> OLD.estado THEN
            RAISE EXCEPTION 'Una reserva % no se puede reactivar', OLD.estado;
        END IF;

        v_validar :=
            (OLD.id_sala, OLD.fecha_reserva, OLD.hora_inicio, OLD.hora_fin, OLD.id_persona)
            IS DISTINCT FROM
            (NEW.id_sala, NEW.fecha_reserva, NEW.hora_inicio, NEW.hora_fin, NEW.id_persona)
            OR (OLD.estado <> 'APROBADA' AND NEW.estado = 'APROBADA');
    END IF;

    IF NEW.estado IN ('PENDIENTE', 'APROBADA') THEN
        -- Siempre bloquear la sala, serializando las operaciones de reserva.
        SELECT estado INTO v_estado_sala
        FROM sala
        WHERE id_sala = NEW.id_sala
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'La sala no existe';
        END IF;

        -- Cada solicitud nueva y cada aprobacion se valida por completo.
        IF v_validar THEN
            IF NEW.fecha_reserva + NEW.hora_inicio < LOCALTIMESTAMP THEN
                RAISE EXCEPTION 'La fecha y hora de la reserva ya pasaron';
            END IF;

            IF NOT persona_puede_reservar(NEW.id_persona) THEN
                RAISE EXCEPTION 'Solo estudiantes y docentes pueden reservar (persona %)',
                                NEW.id_persona;
            END IF;

            IF v_estado_sala <> 'DISPONIBLE' THEN
                RAISE EXCEPTION 'La sala no esta disponible para reservas';
            END IF;

            IF NOT reserva_dentro_horario(
                NEW.id_sala, NEW.fecha_reserva, NEW.hora_inicio, NEW.hora_fin
            ) THEN
                RAISE EXCEPTION 'La reserva queda fuera del horario de funcionamiento';
            END IF;
        END IF;

        v_conflicto := hay_conflicto_aprobado(
            NEW.id_sala, NEW.fecha_reserva, NEW.hora_inicio, NEW.hora_fin, NEW.id_reserva
        );

        IF TG_OP = 'INSERT' THEN
            -- Si hay conflicto con aprobada, queda pendiente.
            -- Si no, se aprueba salvo que exista una pendiente mas antigua, vigente y
            -- viable que se cruce con esta; en ese caso se respeta el orden de la cola.
            IF v_conflicto OR hay_pendiente_anterior(
                NEW.id_sala, NEW.fecha_reserva, NEW.hora_inicio, NEW.hora_fin,
                NEW.fecha_solicitud, NEW.id_reserva
            ) THEN
                NEW.estado := 'PENDIENTE';
            ELSE
                NEW.estado := 'APROBADA';
            END IF;
        ELSIF NEW.estado = 'APROBADA' AND v_conflicto THEN
            RAISE EXCEPTION 'No se puede aprobar: se cruza con otra reserva aprobada';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------
-- COLA DE PENDIENTES: procesa una sala y opcionalmente una fecha.
-- Las solicitudes que chocan con una aprobada siguen pendientes.
-- ---------------------------------------------------------------------
CREATE FUNCTION procesar_cola_sala(p_id_sala INT, p_fecha DATE DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = gestion, pg_temp
AS $$
DECLARE
    v_estado_sala TEXT;
    r RECORD;
BEGIN
    SELECT estado INTO v_estado_sala
    FROM sala
    WHERE id_sala = p_id_sala
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    UPDATE reserva
       SET estado = 'VENCIDA'
     WHERE id_sala = p_id_sala
       AND estado = 'PENDIENTE'
       AND (p_fecha IS NULL OR fecha_reserva = p_fecha)
       AND fecha_reserva + hora_inicio < LOCALTIMESTAMP;

    IF v_estado_sala <> 'DISPONIBLE' THEN
        RETURN;
    END IF;

    FOR r IN
        SELECT id_reserva, id_persona, fecha_reserva, hora_inicio, hora_fin, fecha_solicitud
        FROM reserva
        WHERE id_sala = p_id_sala
          AND estado = 'PENDIENTE'
          AND (p_fecha IS NULL OR fecha_reserva = p_fecha)
        ORDER BY fecha_reserva, fecha_solicitud, id_reserva
    LOOP
        -- Se vuelve a validar al cambiar a APROBADA; si no es viable,
        -- la excepcion no debe abortar toda la cola. Las condiciones que
        -- pueden invalidar una pendiente se filtran antes del UPDATE.
        IF r.fecha_reserva + r.hora_inicio >= LOCALTIMESTAMP
           AND persona_puede_reservar(r.id_persona)
           AND reserva_dentro_horario(p_id_sala, r.fecha_reserva, r.hora_inicio, r.hora_fin)
           AND NOT hay_conflicto_aprobado(
               p_id_sala, r.fecha_reserva, r.hora_inicio, r.hora_fin, r.id_reserva
           )
           AND NOT hay_pendiente_anterior(
               p_id_sala, r.fecha_reserva, r.hora_inicio, r.hora_fin,
               r.fecha_solicitud, r.id_reserva
           )
        THEN
            UPDATE reserva
               SET estado = 'APROBADA'
             WHERE id_reserva = r.id_reserva;
        END IF;
    END LOOP;
END;
$$;

CREATE FUNCTION vencer_reservas()
RETURNS INT
LANGUAGE plpgsql
SET search_path = gestion, pg_temp
AS $$
DECLARE
    v_filas INT;
BEGIN
    UPDATE reserva
       SET estado = 'VENCIDA'
     WHERE estado = 'PENDIENTE'
       AND fecha_reserva + hora_inicio < LOCALTIMESTAMP;

    GET DIAGNOSTICS v_filas = ROW_COUNT;
    RETURN v_filas;
END;
$$;

-- ---------------------------------------------------------------------
-- AFTER UPDATE/DELETE: libera y reevalua solo las fechas afectadas.
-- ---------------------------------------------------------------------
CREATE FUNCTION reserva_despues()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = gestion, pg_temp
AS $$
DECLARE
    v_cambio BOOLEAN;
    v_s1 INT; v_f1 DATE;
    v_s2 INT; v_f2 DATE;
    v_ts INT; v_tf DATE;
BEGIN
    -- Evita recursividad cuando procesar_cola_sala actualiza estados.
    IF pg_trigger_depth() > 1 THEN
        RETURN NULL;
    END IF;

    IF TG_OP = 'DELETE' THEN
        IF OLD.estado IN ('APROBADA', 'PENDIENTE') THEN
            PERFORM procesar_cola_sala(OLD.id_sala, OLD.fecha_reserva);
        END IF;
        RETURN NULL;
    END IF;

    v_cambio :=
        (OLD.id_sala, OLD.fecha_reserva, OLD.hora_inicio, OLD.hora_fin)
        IS DISTINCT FROM
        (NEW.id_sala, NEW.fecha_reserva, NEW.hora_inicio, NEW.hora_fin);

    -- Libera franja: una APROBADA que deja de serlo o se mueve, y tambien una
    -- PENDIENTE que se cancela, se rechaza o se mueve, porque una pendiente
    -- anterior bloquea a las que se le cruzan.
    IF (OLD.estado = 'APROBADA' AND (NEW.estado <> 'APROBADA' OR v_cambio))
       OR (OLD.estado = 'PENDIENTE'
           AND (NEW.estado IN ('CANCELADA', 'RECHAZADA') OR v_cambio)) THEN
        v_s1 := OLD.id_sala;
        v_f1 := OLD.fecha_reserva;
    END IF;

    IF NEW.estado = 'PENDIENTE' AND v_cambio THEN
        v_s2 := NEW.id_sala;
        v_f2 := NEW.fecha_reserva;
    END IF;

    IF v_s1 IS NOT NULL AND v_s2 IS NOT NULL AND v_s1 = v_s2 AND v_f1 = v_f2 THEN
        v_s2 := NULL;
        v_f2 := NULL;
    END IF;

    IF v_s1 IS NULL THEN
        v_s1 := v_s2;
        v_f1 := v_f2;
        v_s2 := NULL;
        v_f2 := NULL;
    END IF;

    IF v_s2 IS NOT NULL AND v_s2 < v_s1 THEN
        v_ts := v_s1; v_tf := v_f1;
        v_s1 := v_s2; v_f1 := v_f2;
        v_s2 := v_ts; v_f2 := v_tf;
    END IF;

    IF v_s1 IS NOT NULL THEN
        PERFORM procesar_cola_sala(v_s1, v_f1);
    END IF;
    IF v_s2 IS NOT NULL THEN
        PERFORM procesar_cola_sala(v_s2, v_f2);
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_reserva_antes
BEFORE INSERT OR UPDATE ON reserva
FOR EACH ROW EXECUTE FUNCTION reserva_antes();

CREATE TRIGGER trg_reserva_despues
AFTER UPDATE OR DELETE ON reserva
FOR EACH ROW EXECUTE FUNCTION reserva_despues();

-- ---------------------------------------------------------------------
-- VALIDACION DE HORARIOS: no permite bloques solapados por sala y dia.
-- ---------------------------------------------------------------------
CREATE FUNCTION validar_horario()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = gestion, pg_temp
AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.id_sala <> NEW.id_sala THEN
        PERFORM 1
        FROM sala
        WHERE id_sala IN (OLD.id_sala, NEW.id_sala)
        ORDER BY id_sala
        FOR UPDATE;
    ELSE
        PERFORM 1 FROM sala WHERE id_sala = NEW.id_sala FOR UPDATE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM horario h
        WHERE h.id_sala = NEW.id_sala
          AND h.dia_semana = NEW.dia_semana
          AND h.id_horario IS DISTINCT FROM NEW.id_horario
          AND h.hora_inicio < NEW.hora_fin
          AND h.hora_fin > NEW.hora_inicio
    ) THEN
        RAISE EXCEPTION 'El horario se cruza con otro bloque de la misma sala y dia';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_horario
BEFORE INSERT OR UPDATE ON horario
FOR EACH ROW EXECUTE FUNCTION validar_horario();

-- ---------------------------------------------------------------------
-- VISTA: estado efectivo de las reservas.
-- ---------------------------------------------------------------------
CREATE VIEW v_reserva_estado AS
SELECT r.*,
       CASE
           WHEN r.estado = 'PENDIENTE'
            AND r.fecha_reserva + r.hora_inicio < LOCALTIMESTAMP
           THEN 'VENCIDA'
           ELSE r.estado
       END AS estado_efectivo
FROM reserva r;

-- ---------------------------------------------------------------------
-- DATOS DE PRUEBA (opcionales; descomenta o ejecuta por separado).
-- ---------------------------------------------------------------------
-- INSERT INTO facultad(nombre) VALUES ('Ingenieria');
-- INSERT INTO programa_academico(nombre, nivel_academico, id_facultad)
-- VALUES ('Ingenieria de Sistemas', 'PREGRADO', 1);
-- INSERT INTO curso(nombre) VALUES ('Bases de Datos');
-- INSERT INTO programa_curso(id_programa, id_curso, semestre) VALUES (1, 1, 3);
-- INSERT INTO persona(nombres, apellidos, correo)
-- VALUES ('Ana', 'Perez', 'ana@universidad.edu');
-- INSERT INTO estudiante(id_persona, codigo_estudiante) VALUES (1, 'EST-001');
-- INSERT INTO sala(nombre, edificio, capacidad) VALUES ('Laboratorio 1', 'Bloque A', 30);
-- INSERT INTO horario(dia_semana, hora_inicio, hora_fin, id_sala)
-- VALUES ('LUNES', '07:00', '20:00', 1);
--
-- Vencimiento: programar vencer_reservas() con pg_cron o cron del sistema.
-- Ejemplo pg_cron (requiere extension instalada y permisos):
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule('vencer-reservas', '*/15 * * * *',
--                      'SELECT gestion.vencer_reservas()');
