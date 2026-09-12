# Módulo 06 · Agentes sobre Oracle: MCP y Agent Skills

Conectar un agente a una base de datos de verdad, ver exactamente qué puede hacer, y descubrir cuál es el control que realmente lo acota.

**Salida del ejercicio:** Política de adopción de agentes ·
**[Página del módulo](https://jesmonsa.github.io/oci-workshop-labs/modulos/06-agentes-mcp.html)**

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/jesmonsa/oci-workshop-labs/releases/latest/download/06-agentes-mcp.zip)

## Qué demuestra

- **Qué expone de verdad un servidor MCP.** Un inspector propio lista el catálogo de herramientas hablando el protocolo directamente, sin necesidad de ningún cliente de IA. Sirve para cualquier servidor MCP, no solo el de Oracle.
- **Que el nivel de restricción no hace lo que parece.** El catálogo es casi idéntico en el nivel más cerrado y en uno permisivo: lo que cambia es qué acepta ejecutar una herramienta por dentro, algo que no se ve en la lista.
- **Cuál es el control que sí acota el daño.** Se crea un usuario de base de datos que solo puede leer, y se comprueba en vivo que el borrado se rechaza. No lo impidió el modelo ni el nivel de restricción: lo impidió un permiso.
- **Agent Skills:** la misma pregunta antes y después de instalar la skill. Lo que cambia no es que la respuesta sea más larga, es que cita una fuente.

## Arquitectura

```
  Agent Skills (conocimiento)          Servidor MCP (herramientas)
        │                                        │
        ▼                                        ▼
  ┌──────────────────────────────────────────────────────┐
  │              cliente de IA (el agente)               │
  └──────────────────────────────────────────────────────┘
                           │
              conexión guardada, con un usuario concreto
                           │
                           ▼
                  Autonomous Database
            (mTLS obligatorio · sin red que mantener)

  nivel de restricción  ─────►  limita a la herramienta
  permisos del usuario  ─────►  limitan el daño        ← este es el que cuenta
```

## Paso a paso

1. **Verificar el equipo primero** — Este módulo se apoya sobre todo en herramientas locales: SQLcl 25.2 o posterior, Java 17 o 21, Python. Si falta algo de eso, no lo arregla ningún despliegue.
2. **Desplegar la base** — Una Autonomous Database, sin VCN ni bastión. Con el nivel siempre gratuito no consume crédito. Entre 3 y 10 minutos.
3. **Preparar la conexión** — Se descarga el wallet y se guarda la conexión. El servidor MCP **no recibe credenciales**: usa conexiones que una persona guardó antes. El agente nunca ve la contraseña.
4. **Cargar el esquema de ejemplo** — Cuatro tablas al estilo de un sistema heredado, con cuatro problemas puestos a propósito que no se anuncian.
5. **Inspeccionar el servidor MCP** — El catálogo completo, en dos niveles de restricción, para compararlos. Aquí aparece el hallazgo del módulo.
6. **Crear el usuario mínimo** — Un usuario que solo lee cuatro tablas. El script comprueba en vivo que puede consultar y no puede borrar.
7. **Conectar el cliente de IA y preguntarle** — Termina pidiéndole que borre datos. La base lo rechaza, y el agente lo reporta.

El detalle completo, con todos los comandos y la tabla de diagnóstico de fallos, está en
[`docs/MANUAL.md`](docs/MANUAL.md).

## Qué se simplificó, y por qué

Un laboratorio que no dice en qué se apartó de una arquitectura real enseña mal.

| Simplificación | Por qué |
|---|---|
| La base tiene endpoint público | Protegido con mTLS obligatorio: hace falta el wallet, no basta la contraseña. Añadir una red privada habría sumado veinte minutos de despliegue sin aportar nada al argumento del módulo, que no trata de red. |
| Se usa el servidor MCP local, no uno gestionado | Es el correcto para un taller: se ve todo, se rompe sin consecuencias y no hay que pedirle permiso a nadie. En una organización, un servicio gestionado da identidad central y registro de auditoría. |
| El esquema es pequeño a propósito | Unas 16 mil filas. El volumen es el tema del módulo 4; aquí lo que importa es que el esquema tenga rarezas que un agente pueda encontrar — o inventarse. |

## Cómo se relaciona con los demás

Es **autocontenido**: no necesita ningún otro módulo. Aun así conversa bien con el [módulo 3](../03-agente-ia), que construye a mano un agente con catálogo cerrado para enseñar el principio; aquí se ve el mismo principio ya convertido en producto, y qué queda sin resolver cuando alguien te lo da hecho.
