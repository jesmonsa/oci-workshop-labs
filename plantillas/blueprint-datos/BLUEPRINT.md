# Blueprint del flujo analítico — plantilla

Versión en Markdown del lienzo. **En vivo se usa el Excel**
(`blueprint/Blueprint_Datos.xlsx`); esta versión sirve para imprimir,
para dibujarlo en el tablero o para pegarlo en la memoria.

> **El orden de las casillas no es casual.** Empieza por la decisión y termina en
> los responsables. Casi todo el mundo empieza por los datos y termina con un
> tablero que nadie abre.

**Prioridad elegida:** ______________________

## 1. La decisión

> ¿Qué decisión se toma con esto, quién la toma y cada cuánto? Si no hay decisión, no hay tablero: hay un reporte.



## 2. La pregunta

> La pregunta exacta que responde. Una sola, redactada como la diría esa persona.



## 3. Las fuentes

> De qué sistemas sale. Se detalla en la hoja «Fuentes».



## 4. El procesamiento

> Qué hay que hacerle a los datos: unir, limpiar, agregar, enmascarar. Con qué frecuencia se actualiza y cuánto retraso se tolera.



## 5. La visualización

> Dónde lo ve esa persona: ¿tablero aparte, o dentro del producto que ya usa? ¿Lo ve la organización, o también sus clientes?



## 6. Los responsables

> Dueño del dato en el origen · quién construye · quién lo mantiene vivo · a quién se le reclama cuando el número está mal.



## Primer entregable (2 semanas)

| | |
|---|---|
| **Qué se construye** | |
| **Quién** | |
| **Para cuándo** | |
| **Cómo se sabe que sirvió** | |

## Inventario de fuentes

Se llena en la hoja «Fuentes» del Excel. Columnas:

| ID | Fuente | Sistema de origen | Tipo | ¿Existe hoy? | Frecuencia de actualización | Calidad (1-5) | Sensibilidad | Dueño del dato | ¿Sirve para el caso de IA? | Notas |
|---|---|---|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |  |  |  |

Fuentes precargadas como hipótesis de trabajo (todas por validar con la organización):

- **F-01** Documentos electrónicos emitidos — origen: Plataforma de documentos · tipo: Transaccional
- **F-02** Respuestas de la autoridad tributaria — origen: Integración externa · tipo: Transaccional
- **F-03** Maestro de clientes — origen: ERP · tipo: Maestro
- **F-04** Inventario y movimientos — origen: WHS / ERP · tipo: Transaccional
- **F-05** Tickets de soporte — origen: Mesa de servicio · tipo: Operativo
- **F-06** Registros de la plataforma (aplicación) — origen: Infraestructura · tipo: Operativo
- **F-07** Métricas de infraestructura y costo — origen: OCI · tipo: Operativo
- **F-08** Actividad de usuarios en el portal B2B — origen: Portal · tipo: Comportamiento
