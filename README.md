# Laboratorios de arquitectura en OCI

Módulos para un taller técnico: elasticidad, seguridad, un agente de IA con límites,
analítica operacional, observabilidad y adopción de agentes sobre Oracle. Cada uno se
despliega en un clic, se destruye con un comando, y termina con **un entregable escrito**.

**→ [Sitio con la guía completa](https://jesmonsa.github.io/oci-workshop-labs/)**

---

## Los módulos

| # | Módulo | Qué demuestra | Salida del ejercicio |
|---|---|---|---|
| 1 | [Elasticidad](labs/01-elasticidad) | Un grupo de instancias que crece bajo carga y **se reduce solo** | Backlog priorizado de optimizaciones |
| 2 | [Seguridad](labs/02-seguridad) | Red en tres capas, WAF, Bastion; auditoría del módulo 1 | Checklist de 39 controles, con mínimos por ambiente |
| 3 | [Agente de IA](labs/03-agente-ia) | Un agente que consulta infraestructura y **no puede hacer daño** | Ficha de caso de uso priorizado |
| 4 | [Datos y analítica](labs/04-datos-analitica) | Un tablero que encuentra lo que el promedio esconde | Blueprint de fuentes y responsables |
| 5 | [Observabilidad](labs/05-observabilidad) | Una alarma que suena, avisa **y se apaga sola** | Matriz señal → umbral → responsable → acción |
| 6 | [Agentes: MCP y Skills](labs/06-agentes-mcp) | Qué puede hacer de verdad un agente conectado a tu base — y qué lo detiene | Política de adopción de agentes |

## Por qué están encadenados

Los cinco primeros no son laboratorios sueltos: el orden es el argumento.

```
  1 · Elasticidad ──────────────► la infraestructura se construye EXPUESTA a propósito
        │                                                    │
        │  métrica de CPU                                    ▼
        │                          2 · Seguridad ──► audita el laboratorio anterior
        │                                │                   y muestra la versión corregida
        │                                │ identidad acotada,
        │                                │ aislamiento, registro
        │                                ▼
        │                          3 · Agente de IA ──► consulta ambos laboratorios,
        │                                │              y su validador hereda esos controles
        │                                │ ¿de qué datos depende el caso?
        │                                ▼
        │                          4 · Datos ──► ¿existen esos datos?, ¿quién responde por ellos?
        │                                │
        │                                │ señales de negocio
        ▼                                ▼
  5 · Observabilidad ◄──────────────────────  la misma métrica del módulo 1, ahora con
                                              umbral, responsable y acción escrita
```

El módulo 5 cierra el círculo: la métrica que en el módulo 1 disparaba el
autoescalamiento se convierte en una alarma **y el autoescalamiento la apaga en vivo**.
Esa es la lección más difícil del tema y aquí ocurre sola.

El **módulo 6 va aparte, y es autocontenido**: el 3 construye a mano un agente con
catálogo cerrado para enseñar el principio; el 6 muestra ese mismo principio ya
convertido en producto, y qué queda sin resolver cuando alguien te lo da hecho.

## Despliegue en un clic

Cada módulo tiene su botón. Requieren una cuenta de OCI con permiso para crear recursos
en un compartment.

| Módulo | Desplegar |
|---|---|
| Guardarraíles de costo (**primero**) | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/jesmonsa/oci-workshop-labs/releases/latest/download/presupuesto-y-alertas.zip) |
| 1 · Elasticidad | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/jesmonsa/oci-workshop-labs/releases/latest/download/01-elasticidad.zip) |
| 2 · Seguridad | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/jesmonsa/oci-workshop-labs/releases/latest/download/02-seguridad.zip) |
| 4 · Datos y analítica | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/jesmonsa/oci-workshop-labs/releases/latest/download/04-datos-analitica.zip) |
| 5 · Observabilidad | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/jesmonsa/oci-workshop-labs/releases/latest/download/05-observabilidad.zip) |
| 6 · Agentes (MCP y Skills) | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/jesmonsa/oci-workshop-labs/releases/latest/download/06-agentes-mcp.zip) |

El módulo 3 no despliega infraestructura: es un programa que se ejecuta contra los
laboratorios anteriores. El módulo 6 es **autocontenido** — crea su propia base y no
necesita ningún otro — y con el nivel siempre gratuito no consume crédito.

> **El de costo va primero, y no es una formalidad.** Los créditos de una cuenta de
> prueba son finitos y no vuelven. Es un despliegue de un minuto que avisa antes de que
> el gasto ocurra.

Detalle completo en la [guía de despliegue](https://jesmonsa.github.io/oci-workshop-labs/despliegue.html).

## Las plantillas

Cinco entregables que se llenan **en vivo** durante el taller y se clasifican solos.
Cada uno se genera desde un script de Python: se edita la lista de controles o de
señales, se vuelve a ejecutar, y salen el Excel y su versión en Markdown.

| Plantilla | Qué hace de especial |
|---|---|
| [Checklist de seguridad](plantillas/checklist-seguridad) | Convierte «no sé» en riesgo a validar y «no» de bajo esfuerzo en quick win |
| [Ficha de caso de IA](plantillas/ficha-caso-ia) | Prioriza ocho candidatos con cuatro criterios ponderados |
| [Blueprint de datos](plantillas/blueprint-datos) | Marca en rojo las fuentes sin dueño |
| [Matriz de observabilidad](plantillas/matriz-observabilidad) | Marca como **ruido** toda alarma que despierte a alguien sin acción escrita |
| [Política de agentes](plantillas/politica-agentes) | Marca como **no permitida** una prueba de concepto apuntando a producción |

```bash
pip install openpyxl
cd plantillas/checklist-seguridad && python generar_checklist.py
```

## Costo y limpieza

Los laboratorios usan recursos que **se cobran**. El más caro con diferencia es el
módulo 4 (base de datos administrada); los más baratos, el 5 (solo alarmas) y el 6
(nivel siempre gratuito).

**Cada módulo tiene su `scripts/99-destroy.sh`.** Correrlo al terminar el día no es
opcional: el crédito no vuelve. Desde Resource Manager, el equivalente es la acción
*Destroy* del stack.

## Advertencias honestas

- Los laboratorios están **simplificados para que quepan en el tiempo de una sesión**.
  Cada módulo dice en su README qué simplificó y por qué. El módulo 1, por ejemplo,
  pone la aplicación en una subred pública: eso es deliberado, y el módulo 2 lo audita.
- **Ninguna cifra de rendimiento viene precargada.** Los tiempos y comparaciones se
  miden al ejecutar los laboratorios. Donde no se midió, las herramientas lo dicen
  explícitamente en vez de estimar.
- Los nombres de algunos recursos (shapes, reglas del WAF, métricas) **cambian entre
  regiones**. Cada manual incluye el comando para verificarlos antes de desplegar.

## Licencia

[UPL-1.0](LICENSE). Úsese, modifíquese y adáptese libremente.
