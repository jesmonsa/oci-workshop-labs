# Matriz de observabilidad — señales candidatas

Catálogo de partida para el módulo 5. **En la sesión se usa el Excel**
(`matriz/Matriz_Observabilidad.xlsx`), que calcula la cobertura y
marca solo las señales que despiertan a alguien sin tener acción escrita.

Las señales vienen de los bloques anteriores: la CPU del autoescalamiento (módulo 1),
los cambios críticos de seguridad (módulo 2), las transacciones detenidas y los
tiempos por canal (módulo 4), y el consumo contra presupuesto (módulo 1).

**Estado (se calcula solo):**

| Estado | Cuándo |
|---|---|
| **Lista** | Existe, con responsable y acción |
| **Ruido** | Despierta a alguien (24x7 o CRITICAL) sin responsable o sin acción |
| **Por implementar** | No existe todavía |
| **Incompleta** | Existe pero le falta responsable o acción |

Total: 16 señales candidatas en 10 categorías.

| ID | Categoría | Señal | ¿Síntoma o causa? | De dónde sale | Umbral sugerido |
|---|---|---|:-:|---|---|
| **S-01** | Disponibilidad | El servicio responde desde fuera (prueba sintética) | Síntoma | Monitoreo sintético cada minuto, desde fuera de la nube | 2 fallos seguidos |
| **S-02** | Latencia | Latencia p95 de la API | Síntoma | Métricas del balanceador o instrumentación de la aplicación | Acordar con el compromiso de servicio |
| **S-03** | Errores | Tasa de respuestas 5xx | Síntoma | Métricas del balanceador | > 1 % durante 5 min |
| **S-04** | Errores | Fallos de integración con sistemas externos | Síntoma | Registros de la aplicación | > N por hora |
| **S-05** | Tráfico | Caída abrupta del volumen de transacciones | Síntoma | Base de datos o aplicación | < 50 % de lo normal para esa hora |
| **S-06** | Saturación | CPU de la capa de aplicación | Causa | Métricas de cómputo (la misma del autoescalamiento) | > 45 % sostenido 3 min |
| **S-07** | Disponibilidad | Servidores no saludables detrás del balanceador | Síntoma | Métricas del balanceador | > 0 durante 2 min |
| **S-08** | Saturación | Conexiones o memoria de la base de datos | Causa | Métricas de la base administrada | > 80 % del máximo |
| **S-09** | Capacidad | Almacenamiento de la base de datos | Causa | Métricas de la base administrada | > 75 % (avisa con semanas, no con horas) |
| **S-10** | Capacidad | El grupo de instancias lleva rato en su tamaño máximo | Causa | Métricas del grupo de instancias | En el máximo más de 15 min |
| **S-11** | Negocio | Transacciones detenidas en proceso | Síntoma | Consulta a la base (la del módulo 4) | > N detenidas más de 4 h |
| **S-12** | Negocio | Tiempo de proceso p95 por canal | Síntoma | Consulta a la base (la del módulo 4) | Acordar con el compromiso de servicio |
| **S-13** | Costo | Consumo del mes contra el presupuesto | Causa | Presupuestos y alertas (las del módulo 1) | 50 % · 75 % · 90 % · proyección |
| **S-14** | Seguridad | Cambios en identidades y reglas de red | Causa | Eventos y notificaciones (las del módulo 2) | Cualquier cambio, siempre |
| **S-15** | Seguridad | Certificado TLS próximo a vencer | Causa | Servicio de certificados | Faltan menos de 30 días |
| **S-16** | Confiabilidad | Tiempo medio de recuperación del último mes | Indicador | Registro de incidentes | No es alarma: se revisa cada mes |

## Lo que se llena en vivo

Umbral acordado · Severidad · ¿Existe hoy? · **Responsable** · **Acción o runbook** ·
¿Despierta a alguien? · Notas.

> Las dos columnas en negrita son las que convierten una señal en una alarma.
> Sin ellas hay una gráfica bonita y un teléfono que suena de madrugada sin que
> nadie sepa qué hacer.
