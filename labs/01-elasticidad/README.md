# Módulo 01 · Arquitectura elástica

Un grupo de instancias detrás de un balanceador que crece bajo carga y vuelve a reducirse solo, con el ciclo completo cronometrado.

**Salida del ejercicio:** Backlog priorizado de optimizaciones ·
**[Página del módulo](https://jesmonsa.github.io/oci-workshop-labs/modulos/01-elasticidad.html)**

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/jesmonsa/oci-workshop-labs/releases/latest/download/01-elasticidad.zip)

## Qué demuestra

- Elasticidad horizontal real: de 2 a 6 instancias y de vuelta, con el balanceador incorporando cada servidor nuevo cuando pasa su verificación de salud.
- **El scale-in**, que es la mitad que casi nadie configura. Escalar hacia arriba salva la experiencia; escalar hacia abajo es lo que salva la factura.
- El costo de escalar verticalmente: la ventana de indisponibilidad al redimensionar una máquina, medida, no citada.
- FinOps que se activa el mismo día: presupuesto, alertas por umbral y por proyección, y reporte de costo por etiqueta.

## Arquitectura

```
                       Internet
                          │
                 ┌────────▼────────┐
                 │  Load Balancer  │  flexible · health check /health
                 └────────┬────────┘
        ┌─────────────────┼─────────────────┐
   ┌────▼────┐       ┌────▼────┐       ┌────▼────┐
   │  app-1  │       │  app-2  │  ...  │  app-N  │   2 → 6 instancias
   └─────────┘       └─────────┘       └─────────┘
                          │
              métrica de CPU del grupo
                          │
                 ┌────────▼─────────┐
                 │  Autoescalamiento│  CPU > 55 % → +2   (máx. 6)
                 └──────────────────┘  CPU < 20 % → −1   (mín. 2)
```

## Paso a paso

1. **Poner los guardarraíles de costo** — Antes de crear nada. Es un despliegue de un minuto que avisa antes de que el gasto ocurra, y el crédito de una cuenta de prueba no vuelve.
2. **Desplegar el laboratorio** — Con el botón, o con `terraform apply`. Entre 5 y 8 minutos: el balanceador es lo más lento.
3. **Comprobar que responde** — `curl` a la URL del balanceador dos veces seguidas: el nombre del host debe alternar. Si no alterna, hay un solo backend sano.
4. **Medir el ciclo** — Generar carga y cronometrar tres momentos: cuándo cruza el umbral la métrica, cuándo arranca la instancia nueva, y cuándo empieza a atender tráfico. **Ese último número es el que importa**: define cuánto colchón hace falta por encima de la demanda.
5. **Cortar la carga y mirar el scale-in** — Tarda más que la subida, a propósito: se baja con más cautela de la que se sube.
6. **Destruir** — `./scripts/99-destroy.sh`. Todos los días.

El detalle completo, con todos los comandos y la tabla de diagnóstico de fallos, está en
[`docs/MANUAL.md`](docs/MANUAL.md).

## Hacerlo a mano, en la consola

El mismo módulo está escrito pantalla por pantalla, para construirlo desde la consola de
Oracle Cloud sin Terraform: [`docs/MANUAL-CONSOLA.md`](docs/MANUAL-CONSOLA.md) ·
[versión web](https://jesmonsa.github.io/oci-workshop-labs/manuales/01-elasticidad.html) ·
[PDF](https://jesmonsa.github.io/oci-workshop-labs/pdf/Manual-Consola-01-Elasticidad.pdf)

## Qué se simplificó, y por qué

Un laboratorio que no dice en qué se apartó de una arquitectura real enseña mal.

| Simplificación | Por qué |
|---|---|
| La aplicación vive en una subred pública | Es deliberado. En una arquitectura real va en subred privada detrás del balanceador — y el [módulo 2](02-seguridad.html) empieza auditando exactamente esto. |
| El acceso SSH está restringido a una sola IP | Si aparece `0.0.0.0/0` en la configuración, el laboratorio no se levanta: en una cuenta nueva los escaneos empiezan en minutos. |
| Los umbrales son agresivos | Están puestos para que el escalamiento se vea dentro del tiempo de una sesión. En producción serían más conservadores. |

## Cómo se relaciona con los demás

Todo lo que sigue se monta encima de este laboratorio. El [módulo 2](../02-seguridad) lo audita, el [módulo 3](../03-agente-ia) lo consulta, y el [módulo 5](../05-observabilidad) convierte su métrica de CPU en una alarma con responsable.
