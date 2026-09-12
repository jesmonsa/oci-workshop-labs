# Módulo 04 · Datos y analítica operacional

Tres millones de documentos sintéticos y un tablero que encuentra dos cosas que el promedio esconde.

**Salida del ejercicio:** Blueprint de fuentes, procesamiento y responsables ·
**[Página del módulo](https://jesmonsa.github.io/oci-workshop-labs/modulos/04-datos-analitica.html)**

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/jesmonsa/oci-workshop-labs/releases/latest/download/04-datos-analitica.zip)

## Qué demuestra

- **El promedio esconde al cliente que se está quemando.** La tasa de rechazo agregada se ve tranquila, pero un cliente pasó del 5 % al 20 % en diez días. En el promedio no se ve porque es uno entre ciento veinte.
- Un canal tarda en su mediana lo que otro tarda en su peor caso, y ahí se concentra todo lo que queda detenido. Eso no es un problema de reportes: es una decisión de arquitectura.
- La misma consulta SQL, sin cambiar una letra, en el motor transaccional y en el acelerador analítico. Lo que importa no es el número: es que la aplicación no cambió.
- El tablero es **un solo archivo HTML** sin dependencias. Abre sin internet. Eso no es una limitación: es el patrón de analítica embebida.

## Arquitectura

```
 generar_datos.py ──► CSV ──► Object Storage ──► importación ──► base
                                                                   │
                                         medir_consultas.py ◄───────┘
                                                  │        (mismo SQL,
                                           resultados.json  dos motores)
                                                  │
                                            tablero.py ──► tablero.html
```

## Paso a paso

1. **Decidir el alcance antes de empezar** — Con acelerador, sin acelerador, o con una base local sin nube. El argumento del módulo **no depende del acelerador**: los tiempos son un adorno valioso, no la tesis.
2. **Desplegar** — Entre 15 y 25 minutos. Se lanza y se hace otra cosa mientras — por ejemplo, generar los datos.
3. **Generar los datos** — Tres millones de filas en dos a cuatro minutos. La misma semilla produce siempre los mismos datos, así que la demostración es reproducible.
4. **Abrir el túnel** — La base no tiene endpoint público: se llega por reenvío de puerto a través del bastión, el mismo patrón del módulo 2.
5. **Cargar y verificar** — **Verificar siempre el conteo:** una importación a medias produce un tablero convincente y equivocado.
6. **Medir y construir el tablero** — El script detecta solo si hay acelerador. Si no lo hay, lo dice y mide un solo motor; no estima el segundo número.
7. **Mirar el tablero con los ojos** — Los dos hallazgos deben verse sin esfuerzo. Guardar una copia: es el respaldo, y funciona sin red.

El detalle completo, con todos los comandos y la tabla de diagnóstico de fallos, está en
[`docs/MANUAL.md`](docs/MANUAL.md).

## Hacerlo a mano, en la consola

El mismo módulo está escrito pantalla por pantalla, para construirlo desde la consola de
Oracle Cloud sin Terraform: [`docs/MANUAL-CONSOLA.md`](docs/MANUAL-CONSOLA.md) ·
[versión web](https://jesmonsa.github.io/oci-workshop-labs/manuales/04-datos-analitica.html) ·
[PDF](https://jesmonsa.github.io/oci-workshop-labs/pdf/Manual-Consola-04-Datos.pdf)

## Qué se simplificó, y por qué

Un laboratorio que no dice en qué se apartó de una arquitectura real enseña mal.

| Simplificación | Por qué |
|---|---|
| Una sola tabla ancha | No es un ejercicio de modelado dimensional. Es sobre qué decisiones se pueden tomar con estos datos y cuánto tarda la consulta que las responde. |
| Los datos son inventados | No hay ni un dato real, y conviene decirlo en voz alta al empezar. Pero tienen la forma y el desorden de los datos de verdad. |
| Los hallazgos están plantados a propósito | Sin algo que encontrar, un tablero solo demuestra que sabemos dibujar barras. Que la sala los descubra sola es lo que convierte la demostración en un argumento. |

## Cómo se relaciona con los demás

Abre preguntando si existen los datos que pidió el caso del [módulo 3](../03-agente-ia). Su columna de identificador de cliente aplica el aislamiento del [módulo 2](../02-seguridad), y sus señales de negocio entran a la matriz del [módulo 5](../05-observabilidad).
