-- =============================================================================
-- Esquema de ejemplo del módulo 6.
--
-- Imita un sistema heredado de pedidos: nombres abreviados, sin comentarios,
-- con las rarezas que tienen los esquemas reales. Es a propósito — un esquema
-- limpio y documentado no deja nada que preguntarle a un agente.
--
-- Hay cuatro cosas mal puestas deliberadamente. NO se anuncian en la sesión:
-- la gracia es que el agente las encuentre y la sala juzgue si tiene razón.
-- Están listadas al final de este archivo, para quien facilita.
--
-- Ejecutar:  sql -S <conexión> @esquema.sql
-- =============================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON

-- Se limpia primero, para poder repetir el laboratorio sin arrastrar estado.
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('PED_DET','PED_HDR','PRD_CAT','CLI_MST')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/

CREATE TABLE CLI_MST (
  CLI_ID     NUMBER(10)    NOT NULL,
  CLI_NOM    VARCHAR2(120) NOT NULL,
  CLI_DOC    VARCHAR2(20),
  CLI_EST    CHAR(1)       DEFAULT 'A',
  CLI_FCH_AL DATE          DEFAULT SYSDATE,
  CLI_SEG    VARCHAR2(30),
  CONSTRAINT PK_CLI_MST PRIMARY KEY (CLI_ID)
);

CREATE TABLE PRD_CAT (
  PRD_ID   NUMBER(10)    NOT NULL,
  PRD_DSC  VARCHAR2(200) NOT NULL,
  PRD_UNI  VARCHAR2(10),
  PRD_PRC  NUMBER(12,2),
  PRD_ACT  CHAR(1) DEFAULT 'S',
  CONSTRAINT PK_PRD_CAT PRIMARY KEY (PRD_ID)
);

CREATE TABLE PED_HDR (
  PED_ID     NUMBER(12)  NOT NULL,
  CLI_ID     NUMBER(10)  NOT NULL,
  PED_FCH    DATE        NOT NULL,
  PED_EST    VARCHAR2(12),
  PED_TOT    NUMBER(14,2),
  PED_CAN    VARCHAR2(10),
  CONSTRAINT PK_PED_HDR PRIMARY KEY (PED_ID),
  CONSTRAINT FK_PED_CLI FOREIGN KEY (CLI_ID) REFERENCES CLI_MST (CLI_ID)
);

CREATE TABLE PED_DET (
  PED_ID   NUMBER(12) NOT NULL,
  LIN_NUM  NUMBER(4)  NOT NULL,
  PRD_ID   NUMBER(10) NOT NULL,
  DET_CNT  NUMBER(10,2),
  DET_PRC  NUMBER(12,2),
  CONSTRAINT PK_PED_DET PRIMARY KEY (PED_ID, LIN_NUM)
);

-- Nota para quien facilita: PED_DET no declara clave foránea hacia PED_HDR ni
-- hacia PRD_CAT. Es una de las cosas plantadas.

CREATE INDEX IX_PED_HDR_CLI ON PED_HDR (CLI_ID);

-- =============================================================================
-- Datos
-- =============================================================================

INSERT INTO CLI_MST (CLI_ID, CLI_NOM, CLI_DOC, CLI_EST, CLI_SEG)
SELECT LEVEL,
       'Cliente ' || LPAD(LEVEL, 4, '0'),
       TO_CHAR(800000000 + LEVEL),
       CASE WHEN MOD(LEVEL, 17) = 0 THEN 'I' ELSE 'A' END,
       CASE MOD(LEVEL, 4) WHEN 0 THEN 'MAYORISTA' WHEN 1 THEN 'MINORISTA'
                          WHEN 2 THEN 'INSTITUCIONAL' ELSE 'RETAIL' END
FROM DUAL CONNECT BY LEVEL <= 300;

INSERT INTO PRD_CAT (PRD_ID, PRD_DSC, PRD_UNI, PRD_PRC, PRD_ACT)
SELECT LEVEL,
       'Producto ' || LPAD(LEVEL, 3, '0'),
       CASE MOD(LEVEL, 3) WHEN 0 THEN 'UND' WHEN 1 THEN 'CAJ' ELSE 'KG' END,
       ROUND(DBMS_RANDOM.VALUE(1000, 250000), 2),
       CASE WHEN MOD(LEVEL, 23) = 0 THEN 'N' ELSE 'S' END
FROM DUAL CONNECT BY LEVEL <= 120;

INSERT INTO PED_HDR (PED_ID, CLI_ID, PED_FCH, PED_EST, PED_TOT, PED_CAN)
SELECT 100000 + LEVEL,
       TRUNC(DBMS_RANDOM.VALUE(1, 301)),
       SYSDATE - DBMS_RANDOM.VALUE(0, 540),
       CASE WHEN MOD(LEVEL, 40) = 0 THEN 'ANULADO'
            WHEN MOD(LEVEL, 11) = 0 THEN 'PENDIENTE'
            ELSE 'CERRADO' END,
       NULL,
       CASE MOD(LEVEL, 3) WHEN 0 THEN 'WEB' WHEN 1 THEN 'CALL' ELSE 'TIENDA' END
FROM DUAL CONNECT BY LEVEL <= 4000;

INSERT INTO PED_DET (PED_ID, LIN_NUM, PRD_ID, DET_CNT, DET_PRC)
SELECT h.PED_ID,
       l.LIN,
       TRUNC(DBMS_RANDOM.VALUE(1, 121)),
       TRUNC(DBMS_RANDOM.VALUE(1, 25)),
       ROUND(DBMS_RANDOM.VALUE(1000, 250000), 2)
FROM PED_HDR h
CROSS JOIN (SELECT LEVEL AS LIN FROM DUAL CONNECT BY LEVEL <= 4) l
WHERE MOD(h.PED_ID + l.LIN, 5) <> 0;

UPDATE PED_HDR h
SET PED_TOT = (SELECT ROUND(SUM(d.DET_CNT * d.DET_PRC), 2)
               FROM PED_DET d WHERE d.PED_ID = h.PED_ID);

-- =============================================================================
-- Las cuatro cosas plantadas
-- =============================================================================

-- 1. Un cliente duplicado con otro identificador: mismo documento, nombre casi
--    igual. Es el clásico que rompe cualquier informe por cliente.
INSERT INTO CLI_MST (CLI_ID, CLI_NOM, CLI_DOC, CLI_EST, CLI_SEG)
VALUES (9001, 'Cliente 0042 S.A.S', '800000042', 'A', 'MAYORISTA');

-- 2. Pedidos con fecha futura. Nada lo impide: no hay restricción de validación.
INSERT INTO PED_HDR (PED_ID, CLI_ID, PED_FCH, PED_EST, PED_TOT, PED_CAN)
SELECT 900000 + LEVEL, 42, SYSDATE + LEVEL * 7, 'CERRADO', 150000, 'WEB'
FROM DUAL CONNECT BY LEVEL <= 6;

-- 3. Líneas de detalle huérfanas: apuntan a pedidos que no existen. Posible
--    porque PED_DET no tiene clave foránea.
INSERT INTO PED_DET (PED_ID, LIN_NUM, PRD_ID, DET_CNT, DET_PRC)
SELECT 777000 + LEVEL, 1, 5, 3, 45000
FROM DUAL CONNECT BY LEVEL <= 25;

-- 4. Totales que no cuadran con el detalle, en una fracción de los pedidos.
UPDATE PED_HDR
SET PED_TOT = ROUND(PED_TOT * 1.19, 2)
WHERE MOD(PED_ID, 37) = 0 AND PED_EST = 'CERRADO';

COMMIT;

BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(USER);
END;
/

SELECT 'CLI_MST' AS tabla, COUNT(*) AS filas FROM CLI_MST
UNION ALL SELECT 'PRD_CAT', COUNT(*) FROM PRD_CAT
UNION ALL SELECT 'PED_HDR', COUNT(*) FROM PED_HDR
UNION ALL SELECT 'PED_DET', COUNT(*) FROM PED_DET;

PROMPT
PROMPT Esquema listo. Ahora se le puede preguntar a un agente qué ve aquí.
PROMPT

-- =============================================================================
-- SOLO PARA QUIEN FACILITA — lo que está plantado y qué se espera del agente
-- =============================================================================
--
-- 1. Cliente duplicado (CLI_ID 42 y 9001, mismo CLI_DOC '800000042').
--    Un agente con contexto de Oracle debería sugerir agrupar por CLI_DOC y
--    encontrarlo. Uno sin contexto suele quedarse en «revise los duplicados».
--
-- 2. Seis pedidos con PED_FCH en el futuro, y ninguna restricción que lo impida.
--    La respuesta buena no es solo encontrarlos: es notar que falta un CHECK.
--
-- 3. Veinticinco líneas en PED_DET sin cabecera en PED_HDR, posibles porque
--    PED_DET no declara clave foránea. Se ve con un NOT EXISTS.
--
-- 4. Algunos PED_TOT no coinciden con la suma de su detalle (multiplicados por
--    1.19, como si alguien hubiera guardado el total con impuesto en unos casos
--    y sin impuesto en otros). Es el hallazgo más difícil y el más realista.
--
-- Lo interesante de la sesión no es si el agente los encuentra los cuatro, sino
-- CÓMO llega: qué consultas escribe, cuáles se inventa, y cuándo afirma algo que
-- no comprobó. Ese es el contenido del módulo.
-- =============================================================================
