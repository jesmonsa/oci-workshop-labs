# Gobierno y aislamiento de datos en IA

Material de apoyo. **No se proyecta**: se usa para responder bien cuando alguien pregunte
—y alguien va a preguntar— por dónde viajan los datos.

> **Advertencia de uso.** Este documento **no** afirma lo que hace tal o cual proveedor con
> los datos. Las condiciones cambian por servicio, por región, por modalidad de despliegue
> y por contrato. Lo que este documento da es **la lista de preguntas que hay que hacer y
> conseguir por escrito**, para cualquier proveedor. Cuando en la sala te pregunten por el
> caso concreto de un servicio de Oracle, la respuesta correcta es: *"te lo confirmo con la
> documentación contractual vigente"*, y se anota como `[VALIDAR]`.

---

## 1. Las siete preguntas

Sirven igual para Oracle, para otro proveedor de nube o para una API de un tercero. la organización
puede reusarlas con sus propios clientes, que es parte de lo que las hace valiosas.

| # | Pregunta | Por qué importa |
|---|---|---|
| 1 | ¿Los datos que envío en las solicitudes se usan para entrenar o mejorar modelos? | Es la preocupación número uno y casi siempre la respuesta está en el contrato, no en la consola |
| 2 | ¿Se retienen las solicitudes y respuestas? ¿Cuánto tiempo y quién puede leerlas? | Determina si un dato sensible en un prompt se convierte en un dato almacenado |
| 3 | ¿En qué región se procesa la inferencia? | Si hay compromisos de residencia de datos con clientes finales, esto los rompe o los cumple |
| 4 | ¿Cómo se aísla mi tráfico del de otros clientes del proveedor? | Modalidad compartida por demanda vs. capacidad dedicada |
| 5 | ¿Qué registros quedan de cada llamada, y los puedo consultar? | Sin esto no hay auditoría posible ni respuesta a un cliente que pregunte |
| 6 | Si ajusto un modelo con mis datos, ¿dónde quedan esos pesos y quién accede? | Un modelo ajustado puede memorizar y revelar datos de entrenamiento |
| 7 | ¿Qué compromiso contractual respalda todo lo anterior? | Una respuesta verbal en una reunión no es un control |

---

## 2. Lo que sí depende de quien construye, no del proveedor

Estas cuatro decisiones son de la organización en cualquier escenario, y son las que más riesgo
reducen en la práctica:

### 2.1 Qué datos entran al prompt

El control más efectivo y el más ignorado. **Un dato que no se envía no se puede filtrar.**

- Enviar identificadores, no personas: `cliente_00427`, no el nombre y la cédula.
- Recortar antes de enviar: el fragmento de documento que hace falta, no el documento.
- Enmascarar lo que no aporta a la respuesta: correos, teléfonos, números de cuenta.
- Decidir explícitamente qué categorías de dato **nunca** viajan.

### 2.2 Aislamiento entre clientes finales

Crítico para la organización, que opera infraestructura de terceros. Si un asistente responde sobre
los ambientes de varios clientes, el aislamiento **no puede depender del prompt**:

> Decirle al modelo "responde solo sobre el cliente A" no es un control de seguridad. Es
> una sugerencia.

El filtro por cliente va **antes** del modelo, en la capa de datos: la consulta se ejecuta
ya restringida al cliente, y al modelo solo le llega lo que ese cliente puede ver. Igual
que con una base de datos.

En el agente de la demo, el equivalente es el `--compartment`: el alcance se fija fuera del
modelo, y el modelo no tiene forma de ampliarlo.

### 2.3 Qué puede hacer, no solo qué puede leer

Es el argumento de la demo: catálogo cerrado de acciones, validador determinista, y ninguna
acción de escritura hasta que exista una razón y una aprobación explícita.

### 2.4 Quién revisa antes de que algo llegue al cliente final

Para casos que *asisten*, una persona revisa siempre. Para casos que *responden*
directamente a un cliente final, hacen falta: citar la fuente, poder decir "no sé", y una
vía de escalamiento a una persona.

---

## 3. Riesgos propios de la IA, y su control

| Riesgo | Qué es | Control que sí funciona |
|---|---|---|
| Respuesta incorrecta con tono seguro | El modelo afirma algo falso con total confianza | Citar la fuente siempre; permitir "no sé"; medir la tasa de acierto en el experimento |
| Fuga por el prompt | Un dato sensible viaja en la solicitud | Minimizar y enmascarar antes de enviar (2.1) |
| Inyección de instrucciones | Texto leído por el agente que le da órdenes nuevas | Que las acciones posibles no se decidan con texto (la demo) |
| Mezcla entre clientes | Una respuesta usa datos de otro cliente | Filtrar por cliente antes del modelo (2.2) |
| Dependencia silenciosa | El equipo deja de saber hacer lo que el asistente hace | Medir, revisar muestras periódicamente, mantener el procedimiento manual documentado |
| Costo descontrolado | El consumo por tokens crece sin que nadie lo note | Presupuesto y alerta desde el primer día — igual que en el módulo 1 |

---

## 4. Qué llevarse a la ficha

Del módulo 2 al módulo 3, tres controles se heredan tal cual y deben aparecer en el campo
*Riesgos y controles*:

1. **Identidad** (I-04): el asistente o agente se autentica con un principal propio y
   acotado, no con la llave de una persona.
2. **Aislamiento** (M-01, M-02): si toca datos de clientes finales, el alcance se fija
   fuera del modelo.
3. **Registro** (L-01, L-03): cada consulta queda registrada, y se puede responder qué
   se consultó y cuándo.

Si un caso de uso no puede cumplir esos tres, no es que sea inseguro: es que todavía no
está listo para producción, y su experimento de dos semanas debería ser justamente
resolverlos.
