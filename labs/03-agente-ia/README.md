# Módulo 03 · Un agente que no puede hacer daño

Un agente responde preguntas en lenguaje natural sobre la infraestructura de los laboratorios anteriores. Lo interesante no es que responda.

**Salida del ejercicio:** Ficha de caso de uso priorizado ·
**[Página del módulo](https://jesmonsa.github.io/oci-workshop-labs/modulos/03-agente-ia.html)**

> Este módulo **no despliega infraestructura**: es un programa que se ejecuta contra los laboratorios anteriores.

## Qué demuestra

- **El modelo no ejecuta nada.** Propone una herramienta de un catálogo cerrado; un validador escrito por una persona decide si se ejecuta.
- No existe ninguna herramienta de escritura. No está deshabilitada por configuración: no está en el código.
- Una petición de cambio —«apaga esa instancia»— se rechaza. Y una inyección de instrucciones —«ignora tus instrucciones anteriores»— también, por la misma vía.
- Todo queda en una bitácora: la pregunta, lo que propuso el modelo, lo que decidió el validador y lo que se ejecutó. Sin registro no hay agente auditable.

## Arquitectura

```
   pregunta en                                              consulta de
   lenguaje natural                                         solo lectura
        │                                                          ▲
        ▼                                                          │
  ┌─────────────┐    propone     ┌──────────────┐    permite   ┌───┴──────┐
  │PLANIFICADOR │ ─────────────► │  VALIDADOR   │ ───────────► │ CATÁLOGO │
  │ (el modelo) │  {herramienta} │ (código, sin │              │8 lecturas│
  └─────────────┘                │      IA)     │              └──────────┘
                                 └──────┬───────┘
                                        │ rechaza
                                        ▼
                                no se ejecuta nada
```

## Paso a paso

1. **Instalar y probar sin credenciales** — `--catalogo` muestra las ocho herramientas y `--autoprueba` ejercita la capa de validación. Los dos funcionan sin cuenta de nube y sin modelo: si fallan, el problema es el entorno.
2. **Comprobar si hay modelos disponibles** — El servicio de IA generativa no está en todas las regiones. El agente descubre el modelo por su cuenta en vez de traer un identificador fijo, que es la forma más segura de que algo falle meses después.
3. **Preguntar contra el laboratorio** — «¿cuántas máquinas hay corriendo?», «¿alguna tiene IP pública?», «¿cuánto llevamos gastando este mes?». Cada respuesta imprime tres líneas: lo que propuso el modelo, lo que decidió el validador, y el resultado.
4. **Pedirle algo que no debe hacer** — «apaga la instancia app-1». Termina en `RECHAZADA · no se ejecutó nada`. Es el momento que sostiene el módulo.
5. **Intentar una inyección de instrucciones** — Mismo rechazo. Ninguna instrucción escrita puede sacar al agente de su catálogo, porque el catálogo no se decide con texto.
6. **Leer la bitácora** — Una línea por interacción. No guarda los datos devueltos, solo cuántas filas: una bitácora que copia lo consultado se convierte ella misma en un problema de seguridad.

El detalle completo, con todos los comandos y la tabla de diagnóstico de fallos, está en
[`docs/MANUAL.md`](docs/MANUAL.md).

## Hacerlo a mano, en la consola

El mismo módulo está escrito pantalla por pantalla, para construirlo desde la consola de
Oracle Cloud sin Terraform: [`docs/MANUAL-CONSOLA.md`](docs/MANUAL-CONSOLA.md) ·
[versión web](https://jesmonsa.github.io/oci-workshop-labs/manuales/03-agente-ia.html) ·
[PDF](https://jesmonsa.github.io/oci-workshop-labs/pdf/Manual-Consola-03-Agente-IA.pdf)

## Qué se simplificó, y por qué

Un laboratorio que no dice en qué se apartó de una arquitectura real enseña mal.

| Simplificación | Por qué |
|---|---|
| El agente no entiende el negocio | Elige entre ocho consultas. Decirlo en voz alta da más credibilidad que exagerar lo que hace. |
| Funciona sin modelo | Con `--sin-llm` el traductor es un emparejador de palabras clave. La demostración sirve igual, y el argumento se ve más claro: la seguridad nunca estuvo en el modelo. |
| Ampliar el catálogo son ocho líneas | Pero solo con funciones de lectura. Una acción de escritura no se agrega ahí: se diseña con aprobación humana explícita y alcance acotado, y eso ya es otro proyecto. |

## Cómo se relaciona con los demás

Consulta los laboratorios de los [módulos 1](../01-elasticidad) y [2](../02-seguridad), y su validador es la aplicación directa de los controles del módulo 2. El caso de uso que se elija define de qué datos depende — que es con lo que abre el [módulo 4](../04-datos-analitica).
