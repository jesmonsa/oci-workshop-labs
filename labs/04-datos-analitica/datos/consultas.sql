-- =============================================================================
-- Consultas del laboratorio — módulo 4
--
-- Cada consulta lleva la decisión que habilita. Es la regla del bloque:
-- una métrica sin decisión asociada es decoración.
--
-- Formato: medir_consultas.py lee los bloques por las marcas @consulta.
-- =============================================================================

-- @consulta: volumen_diario
-- @titulo: Documentos emitidos por día (últimos 30 días)
-- @decision: ¿la capacidad contratada alcanza para lo que viene?
-- @peso: ligera
SELECT DATE(fecha_emision) AS dia,
       COUNT(*)            AS emitidos
FROM documentos
WHERE fecha_emision >= CURDATE() - INTERVAL 30 DAY
GROUP BY dia
ORDER BY dia;

-- @consulta: tasa_rechazo_diaria
-- @titulo: Tasa de rechazo diaria (últimos 30 días)
-- @decision: ¿el problema de calidad es de siempre o empezó un día concreto?
-- @peso: ligera
SELECT DATE(fecha_emision) AS dia,
       ROUND(100 * SUM(estado = 'RECHAZADO') / COUNT(*), 2) AS tasa_rechazo
FROM documentos
WHERE fecha_emision >= CURDATE() - INTERVAL 30 DAY
GROUP BY dia
ORDER BY dia;

-- @consulta: motivos_rechazo
-- @titulo: Motivos de rechazo (últimos 30 días)
-- @decision: ¿dónde se pone el esfuerzo de corrección esta semana?
-- @peso: ligera
SELECT motivo_rechazo                                        AS motivo,
       COUNT(*)                                              AS rechazados,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)      AS pct
FROM documentos
WHERE estado = 'RECHAZADO'
  AND fecha_emision >= CURDATE() - INTERVAL 30 DAY
GROUP BY motivo_rechazo
ORDER BY rechazados DESC;

-- @consulta: clientes_en_riesgo
-- @titulo: Clientes cuya tasa de rechazo empeoró esta semana
-- @decision: ¿a qué cliente hay que llamar hoy, antes de que llame él?
-- @peso: media
SELECT cliente_id,
       ROUND(100 * SUM(CASE WHEN fecha_emision >= CURDATE() - INTERVAL 7 DAY
                            THEN estado = 'RECHAZADO' END)
                 / NULLIF(SUM(fecha_emision >= CURDATE() - INTERVAL 7 DAY), 0), 1)  AS rechazo_7d,
       ROUND(100 * SUM(CASE WHEN fecha_emision <  CURDATE() - INTERVAL 7 DAY
                            THEN estado = 'RECHAZADO' END)
                 / NULLIF(SUM(fecha_emision <  CURDATE() - INTERVAL 7 DAY), 0), 1)  AS rechazo_previo,
       SUM(fecha_emision >= CURDATE() - INTERVAL 7 DAY)                             AS documentos_7d
FROM documentos
WHERE fecha_emision >= CURDATE() - INTERVAL 60 DAY
GROUP BY cliente_id
HAVING documentos_7d > 100 AND rechazo_7d > rechazo_previo * 1.5
ORDER BY rechazo_7d DESC
LIMIT 10;

-- @consulta: atascados
-- @titulo: Documentos detenidos hace más de 4 horas
-- @decision: ¿qué hay que destrabar hoy? (la consulta más operativa de todas)
-- @peso: ligera
SELECT cliente_id,
       canal,
       COUNT(*)                                                  AS detenidos,
       ROUND(MAX(TIMESTAMPDIFF(HOUR, fecha_emision, NOW())), 1)  AS horas_el_mas_viejo
FROM documentos
WHERE estado = 'EN_PROCESO'
  AND fecha_emision < NOW() - INTERVAL 4 HOUR
GROUP BY cliente_id, canal
ORDER BY detenidos DESC
LIMIT 15;

-- @consulta: percentiles_por_canal
-- @titulo: Tiempo de validación p50 y p95 por canal (mes en curso)
-- @decision: ¿qué canal incumple el compromiso de servicio y hay que rediseñar?
-- @peso: pesada
WITH ordenados AS (
  SELECT canal,
         minutos_validacion,
         PERCENT_RANK() OVER (PARTITION BY canal ORDER BY minutos_validacion) AS pr
  FROM documentos
  WHERE estado = 'ACEPTADO'
    AND minutos_validacion IS NOT NULL
    AND fecha_emision >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
)
SELECT canal,
       MAX(CASE WHEN pr <= 0.50 THEN minutos_validacion END) AS p50_min,
       MAX(CASE WHEN pr <= 0.95 THEN minutos_validacion END) AS p95_min,
       COUNT(*)                                              AS muestras
FROM ordenados
GROUP BY canal
ORDER BY p95_min DESC;

-- @consulta: agregacion_historica
-- @titulo: Agregación completa de seis meses por cliente, tipo y estado
-- @decision: ¿cómo se comporta cada cliente en el histórico? (base de la analítica embebida)
-- @peso: pesada
SELECT cliente_id,
       tipo,
       estado,
       COUNT(*)                             AS documentos,
       ROUND(SUM(valor) / 1000000, 2)       AS valor_millones,
       ROUND(AVG(minutos_validacion), 1)    AS promedio_validacion_min
FROM documentos
GROUP BY cliente_id, tipo, estado
ORDER BY documentos DESC;

-- @consulta: un_solo_cliente
-- @titulo: La misma analítica, para UN cliente (patrón multi-cliente)
-- @decision: ¿se le puede entregar este tablero a cada cliente, viendo solo lo suyo?
-- @peso: media
-- @parametro_cliente: 47
SELECT DATE_FORMAT(fecha_emision, '%Y-%m')      AS mes,
       COUNT(*)                                 AS documentos,
       ROUND(100 * SUM(estado = 'RECHAZADO') / COUNT(*), 2) AS tasa_rechazo,
       ROUND(AVG(minutos_validacion), 1)        AS promedio_validacion_min
FROM documentos
WHERE cliente_id = 47
GROUP BY mes
ORDER BY mes;

-- Nota sobre la última consulta: el filtro por cliente_id está en el SQL, no en la
-- aplicación ni en el tablero. Si la organización ofrece analítica a sus clientes, ese filtro
-- tiene que aplicarse en la capa de datos y venir de la identidad de quien consulta,
-- nunca de un parámetro que llegue del navegador. Es el mismo principio del módulo 3:
-- el alcance se fija fuera de la capa que recibe la petición.
