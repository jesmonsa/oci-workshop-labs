-- =============================================================================
-- Esquema del laboratorio de analítica operacional — módulo 4
--
-- Caso: plataforma de documentos electrónicos. Una sola tabla ancha, a propósito:
-- el bloque no es sobre modelado dimensional, es sobre qué decisiones se pueden
-- tomar con estos datos y cuánto tarda la consulta que las responde.
--
-- La columna cliente_id está en TODAS las consultas. No es decorativa: es el
-- patrón de aislamiento multi-cliente que la organización necesita si ofrece analítica
-- a sus propios clientes (bloques 4 y 5).
-- =============================================================================

CREATE DATABASE IF NOT EXISTS operacion
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE operacion;

DROP TABLE IF EXISTS documentos;

CREATE TABLE documentos (
  documento_id      BIGINT       NOT NULL,
  cliente_id        INT          NOT NULL,   -- cliente de la organización (el emisor)
  tipo              VARCHAR(16)  NOT NULL,   -- FACTURA, NOTA_CREDITO, NOTA_DEBITO
  canal             VARCHAR(12)  NOT NULL,   -- API, PORTAL, LOTE
  ciudad            VARCHAR(24)  NOT NULL,
  estado            VARCHAR(12)  NOT NULL,   -- ACEPTADO, RECHAZADO, EN_PROCESO, ANULADO
  motivo_rechazo    VARCHAR(40)  NULL,
  fecha_emision     DATETIME     NOT NULL,
  fecha_validacion  DATETIME     NULL,       -- respuesta de la autoridad tributaria
  minutos_validacion INT         NULL,       -- derivado, para no calcularlo en cada consulta
  reintentos        TINYINT      NOT NULL DEFAULT 0,
  valor             DECIMAL(14,2) NOT NULL,
  PRIMARY KEY (documento_id),

  -- Índices pensados para las consultas de consultas.sql. En InnoDB son los que
  -- hacen la diferencia; con el acelerador analítico dejan de importar, y ese
  -- contraste es parte de lo que se muestra.
  KEY idx_fecha        (fecha_emision),
  KEY idx_cliente_fecha(cliente_id, fecha_emision),
  KEY idx_estado_fecha (estado, fecha_emision)
) ENGINE=InnoDB;

-- =============================================================================
-- Acelerador analítico (opcional)
--
-- Ejecutar SOLO si el clúster de HeatWave está creado (ver terraform/heatwave,
-- variable crear_cluster_heatwave). Sin clúster, estas dos sentencias fallan y
-- el resto del laboratorio funciona igual.
--
-- SECONDARY_ENGINE marca la tabla como candidata; SECONDARY_LOAD la carga en
-- memoria del acelerador. A partir de ahí, la misma consulta SQL puede resolverse
-- en un motor o en el otro sin cambiar una letra — que es justamente el argumento:
-- no hay que reescribir la aplicación para tener analítica rápida.
-- =============================================================================

-- ALTER TABLE documentos SECONDARY_ENGINE = RAPID;
-- ALTER TABLE documentos SECONDARY_LOAD;

-- Verificación de que quedó cargada:
-- SELECT NAME, LOAD_STATUS FROM performance_schema.rpd_tables
--   JOIN performance_schema.rpd_table_id USING (ID);
