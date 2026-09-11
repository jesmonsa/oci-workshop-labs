# Candidatos de casos de uso de IA

Catálogo de partida para la priorización del módulo 3. **No son recomendaciones**:
son candidatos para que la organización descarte, ajuste o priorice. La priorización se hace
en vivo en `Ficha_Caso_IA.xlsx`, hoja «Priorización».

## Criterios

Los cuatro se puntúan de 1 a 5, y **5 siempre es lo mejor**.

| Criterio | Peso | Qué se pregunta |
|---|:-:|---|
| Valor | 35% | ¿Cuánto mejora el trabajo de alguien concreto? 5 = mucho. |
| Datos | 25% | ¿Existen los datos, están accesibles y en buen estado? 5 = listos hoy. |
| Riesgo bajo | 20% | ¿Qué pasa si el modelo se equivoca? 5 = consecuencia menor y reversible. |
| Rapidez | 20% | ¿Qué tan pronto se ve un resultado? 5 = piloto en dos semanas. |

## Candidatos

### IA-01 · Asistente de soporte sobre documentación y tickets

Busca y responde sobre manuales, notas de versión e historial de tickets, citando la fuente.

- **Usuario:** Agentes de soporte N1 y N2
- **Requisito crítico:** Documentación y tickets accesibles en formato digital y razonablemente ordenados.

### IA-02 · Agente de operación cloud (consulta y diagnóstico)

Responde en lenguaje natural sobre el estado de la infraestructura: inventario, exposición, salud, costo. Solo lectura.

- **Usuario:** Equipo de infraestructura y operaciones de la organización
- **Requisito crítico:** Un catálogo cerrado de consultas y un validador que impida cualquier escritura.

### IA-03 · Copiloto de desarrollo (código y pruebas)

Sugiere código, genera pruebas unitarias y explica código heredado.

- **Usuario:** Equipo de desarrollo
- **Requisito crítico:** Política clara sobre qué código puede salir del entorno y cuál no.

### IA-04 · Clasificación y enrutamiento automático de tickets

Asigna categoría, prioridad y grupo resolutor al crear el ticket.

- **Usuario:** Mesa de servicio
- **Requisito crítico:** Histórico de tickets bien etiquetado para medir si acierta.

### IA-05 · Resumen de incidentes y borrador de informe post-incidente

Reúne cronología, acciones y efectos, y redacta el borrador que hoy nadie quiere escribir.

- **Usuario:** Operaciones y líderes técnicos
- **Requisito crítico:** Registros y bitácoras del incidente en un solo lugar.

### IA-06 · Búsqueda semántica en portal B2B o catálogo

Permite buscar por intención y no por palabra exacta.

- **Usuario:** Clientes de la organización en el portal
- **Requisito crítico:** Catálogo con descripciones suficientes para que la búsqueda tenga de dónde agarrarse.

### IA-07 · Capacidad embebida en ERP, WHS o Sales/RCP

Recomendaciones o asistencia dentro del producto: sugerir reposición, detectar anomalías, explicar un indicador.

- **Usuario:** Usuarios finales del producto de la organización
- **Requisito crítico:** Definir si la capacidad es igual para todos los clientes o se adapta por cliente.

### IA-08 · Consulta del estado de su ambiente para el cliente final

Cada cliente pregunta en lenguaje natural por el estado, el consumo y los eventos de SU ambiente.

- **Usuario:** Clientes a los que la organización opera la infraestructura
- **Requisito crítico:** Aislamiento estricto por cliente: la respuesta jamás puede mezclar datos de dos clientes.

## Campos de la ficha

| Campo | Qué se busca |
|---|---|
| Nombre del caso | Como lo llamarían dentro de la organización. |
| Problema | Una frase, SIN mencionar inteligencia artificial. Si el problema solo existe cuando se menciona la IA, no es un problema. |
| ¿Quién lo sufre? | Una persona concreta con nombre de cargo, no «el negocio» ni «los clientes». |
| ¿Cómo se resuelve hoy? | Qué hace hoy esa persona, cuánto tiempo le toma y con qué frecuencia. |
| Costo actual del problema | Horas al mes, errores, reprocesos o clientes afectados. Aproximado sirve. |
| Fuentes de datos | Qué datos hacen falta y dónde están hoy. |
| Clasificación de esos datos | Públicos · internos · confidenciales · de clientes finales. Si hay datos de clientes, el caso hereda las obligaciones del contrato con ellos. |
| Arquitectura conceptual | Dos o tres líneas: de dónde salen los datos, qué los procesa, dónde se muestra. |
| Modo de operación | ¿Asiste a una persona que decide, o actúa solo? ¿Qué acciones puede tomar y cuáles tiene prohibidas? |
| Riesgos y controles | Respuesta incorrecta, fuga de datos, inyección de instrucciones, dependencia. Para cada uno: qué control lo contiene. |
| KPI principal | Un solo indicador. El que le importa al usuario del caso, no al proyecto. |
| Línea base y meta | Cuánto vale hoy ese indicador y cuánto sería un buen resultado. |
| Criterio de éxito del experimento | El umbral que decide seguir o parar. Se escribe ANTES de empezar. |
| Diseño del experimento (2 semanas) | Qué se construye, con qué muestra, quién lo prueba, cómo se mide. |
| Qué NO va a hacer | Alcance negativo explícito. Es lo que evita que el piloto crezca hasta morir. |
| Dueño en la organización | Una persona. No un área. |
| Apoyo de Oracle | Quién acompaña y en qué. |
| Siguiente paso y fecha | Concreto, con fecha, para las próximas dos semanas. |
