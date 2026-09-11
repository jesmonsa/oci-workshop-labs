# Disponibilidad, MTTR y compromisos de servicio

Material de apoyo. No se proyecta completo: se usa si la conversación llega a los
compromisos de servicio, que con la organización es probable porque le operan infraestructura
a terceros.

---

## 1. Los cuatro números, y cuál importa de verdad

| Número | Qué mide | Trampa habitual |
|---|---|---|
| **Disponibilidad** | % del tiempo que el servicio responde | Se mide desde dentro, donde casi siempre responde |
| **MTTD** (detección) | Desde que empieza el problema hasta que alguien se entera | Casi nadie lo mide, y es donde está el margen |
| **MTTR** (recuperación) | Desde que se detecta hasta que se resuelve | Se confunde con «desde que se reportó» |
| **Frecuencia** | Cuántas veces al mes | Tres caídas de 5 min molestan más que una de 15 |

> **El que más margen de mejora esconde es el MTTD.** Si el cliente avisa antes que la
> alarma, el problema no fue la caída: fue la observabilidad. Y ese es un problema que
> se arregla con configuración, no con más infraestructura.

---

## 2. Qué significan de verdad los «nueves»

| Disponibilidad | Tiempo caído al mes | Qué exige en la práctica |
|---|---|---|
| 99 % | ~7 h | Monitoreo básico y atención en horario |
| 99,5 % | ~3,6 h | Alarmas con dueño; guardia de alguna forma |
| 99,9 % | ~43 min | Guardia real, redundancia, runbooks probados |
| 99,95 % | ~22 min | Automatización de la recuperación; la intervención humana ya no alcanza |
| 99,99 % | ~4 min | Arquitectura multi-zona, despliegues sin corte, inversión considerable |

**La conversación honesta:** cada nueve adicional cuesta aproximadamente un orden de
magnitud más. Prometer 99,9 % sin guardia ni redundancia no es un compromiso: es una
esperanza.

Y hay una pregunta previa que ahorra discusiones: **¿disponibilidad de qué, medida
desde dónde y en qué horario?** Un 99,9 % medido desde dentro de la misma red, sobre
un `ping`, en horario laboral, no significa nada.

---

## 3. Lo que la organización necesita definir para sus clientes

Si la organización opera infraestructura de terceros, cada cliente tiene —explícita o
implícitamente— un compromiso. Vale la pena hacerlo explícito, porque lo implícito
siempre se interpreta a favor de quien reclama:

- [ ] **Qué se mide.** Un recorrido de usuario concreto, no «el servidor está arriba».
- [ ] **Desde dónde.** Desde fuera de la nube, o el número no representa la experiencia.
- [ ] **En qué horario.** ¿24x7 o ventana de negocio? Cambia el costo por completo.
- [ ] **Qué no cuenta.** Mantenimientos avisados, fallos del cliente, causas externas.
- [ ] **Cómo se reporta.** Un informe mensual automático vale más que uno perfecto que
      nadie arma.
- [ ] **Qué pasa si no se cumple.** Si no hay consecuencia, no es un compromiso.

> El punto 2 es el que más cambia los números y el que más se olvida. Medir desde
> dentro es medir si el servidor cree que está bien.

---

## 4. Presupuesto de error: la idea que evita las dos discusiones eternas

Si el compromiso es 99,9 %, sobran ~43 minutos de caída al mes. Eso es el **presupuesto
de error**, y usarlo como herramienta de decisión resuelve dos peleas típicas:

- **Si queda presupuesto:** se puede desplegar, cambiar, experimentar. El riesgo está
  cubierto.
- **Si se agotó:** se congela lo que no sea estabilidad hasta el siguiente periodo.

Convierte «¿desplegamos en la preparación?» de una discusión de opiniones en una de datos. No
hace falta adoptar toda la teoría que hay detrás: la idea del presupuesto, sola, ya
cambia la conversación.

---

## 5. Cómo empezar sin instrumentar nada

Para un equipo que hoy no mide, el orden que da resultados más rápido:

1. **Una prueba sintética desde fuera**, cada minuto, del recorrido más importante.
   Es la señal S-01 de la matriz y da disponibilidad y MTTD de una vez.
2. **Registrar los incidentes en una hoja**: cuándo empezó, cuándo se detectó, cuándo
   se resolvió, qué lo causó. Cuatro columnas. Con un mes de datos ya hay conversación.
3. **Revisión mensual de 30 minutos** con esa hoja delante.

Nada de esto necesita herramienta nueva ni proyecto. Y en dos meses produce los números
que hoy no existen.

> Es, además, un buen primer tramo para la agenda de implementación del bloque: cabe
> en «esta semana» y no depende de que nadie apruebe nada.
