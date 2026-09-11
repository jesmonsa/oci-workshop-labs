# Módulo 02 · Seguridad de extremo a extremo

La versión corregida del laboratorio anterior, al lado del original, para comparar las dos con el mismo comando.

**Salida del ejercicio:** Checklist de 39 controles con mínimos por ambiente ·
**[Página del módulo](https://jesmonsa.github.io/oci-workshop-labs/modulos/02-seguridad.html)**

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/jesmonsa/oci-workshop-labs/releases/latest/download/02-seguridad.zip)

## Qué demuestra

- **Detectar:** un script de solo lectura audita el módulo 1 y encuentra lo que se dejó abierto a propósito. Se puede entregar al cliente para que lo corra en su propia cuenta.
- **Proteger el borde:** el mismo ataque devuelve 200 contra el balanceador sin WAF y 403 contra el que sí lo tiene.
- **Entrar sin puertas abiertas:** sesión administrativa por Bastion hacia una instancia sin IP pública. El puerto 22 existe, pero solo desde una IP.
- **Prevenir:** una Security Zone rechaza crear un bucket público, y deja crear el privado.

## Arquitectura

```
      ANTES (módulo 1)                      DESPUÉS (módulo 2)
 ┌──────────────────────────┐   ┌────────────────────────────────────┐
 │ subred pública           │   │ pública   [LB + WAF]  ← solo esto  │
 │  [LB sin WAF]            │   │              │ NSG: 80 solo del LB │
 │  [app-1 con IP pública]  │   │ privada   [app-1] [app-2] sin IP   │
 │  [app-2 con IP pública]  │   │              │ NSG: BD solo de app │
 │  lista por defecto:      │   │ privada   [datos] sin internet     │
 │  puerto 22 ← 0.0.0.0/0   │   │ Bastion → 22 solo desde su endpoint│
 └──────────────────────────┘   │ Registro de red · alertas de cambio│
                                └────────────────────────────────────┘
```

## Paso a paso

1. **Activar la postura antes que nada** — Cloud Guard tarda en acumular hallazgos: encenderlo el mismo día de la sesión es encenderlo tarde.
2. **Verificar las reglas del WAF** — Las claves de las capacidades de protección cambian entre regiones. El manual trae el comando; hacerlo antes del primer despliegue.
3. **Desplegar el laboratorio seguro** — Entre 8 y 12 minutos.
4. **Auditar el módulo 1** — `./scripts/10-auditoria-rapida.sh` contra el compartment del laboratorio anterior. Debe encontrar varios hallazgos altos. Correrlo también contra este: casi todo debe salir limpio. Que encuentre cosas en uno y no en el otro es la mejor prueba de que el script funciona.
5. **Comparar los dos balanceadores** — `./scripts/20-prueba-waf.sh` imprime una tabla de dos columnas con los códigos HTTP. Se lee de un vistazo.
6. **Entrar por el bastión** — Crear la sesión toma uno o dos minutos: conviene hacerlo antes, no en vivo.

El detalle completo, con todos los comandos y la tabla de diagnóstico de fallos, está en
[`docs/MANUAL.md`](docs/MANUAL.md).

## Qué se simplificó, y por qué

Un laboratorio que no dice en qué se apartó de una arquitectura real enseña mal.

| Simplificación | Por qué |
|---|---|
| El balanceador escucha en HTTP, no en HTTPS | Para no depender de un certificado en el laboratorio. En producción es 443 con certificado gestionado y el 80 solo redirige — es el control B-03 del checklist. |
| La base de datos no se despliega | La capa de datos existe en la red, con sus reglas, para que el diagrama de tres capas quede completo y se pueda mostrar. |
| El origen permitido hacia la base es el CIDR de la subred | Y no la IP exacta del endpoint del bastión, porque referenciarla crearía una dependencia circular. En esa subred solo hay dos cosas, así que el alcance real es el mismo. |

## Cómo se relaciona con los demás

Audita el [módulo 1](../01-elasticidad). Sus tres controles de identidad, aislamiento y registro son los que hereda el validador del [módulo 3](../03-agente-ia), y su alerta de cambios críticos aparece como señal en el [módulo 5](../05-observabilidad).
