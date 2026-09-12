# Madurez del ecosistema de agentes

Material de apoyo. No se proyecta completo: se usa para responder bien cuando alguien
pregunte —y alguien va a preguntar— si esto ya se puede usar de verdad.

> **Advertencia de uso.** Lo que sigue describe **cómo leer** el estado de una pieza,
> no cuál es el estado de cada una hoy. Este ecosistema cambia de mes en mes: lo que
> hoy es una prueba de concepto puede ser producto el trimestre que viene. **Verificar
> siempre en la documentación del proveedor antes de recomendar nada.**

---

## 1. Tres niveles que no se pueden mezclar

| Nivel | Cómo se reconoce | Qué se puede hacer con él |
|---|---|---|
| **Producto** | Está en la documentación oficial del servicio, tiene versión y soporte | Se puede llevar a producción con los controles normales |
| **Preview / beta** | Se anuncia como tal; la interfaz puede cambiar | Vale para desarrollo y pruebas, no para producción |
| **Prueba de concepto** | El propio repositorio dice *reference implementation* o *not intended for production use* | Se estudia, se demuestra, **no se adopta** |

La tercera fila es la que importa. Cuando el autor de un componente declara por
escrito que no está pensado para producción, conectarlo a un ambiente real no es una
decisión técnica arriesgada: es ir contra la indicación explícita de quien lo escribió.

**Y no es un juicio sobre la calidad del código.** Una prueba de concepto puede estar
muy bien hecha. Lo que no tiene es el compromiso de que la interfaz no cambie mañana,
ni un canal de soporte cuando falle a las tres de la madrugada.

---

## 2. Cómo verificarlo en dos minutos

Antes de recomendar cualquier servidor MCP:

- [ ] ¿Está documentado en el sitio de documentación del producto, o solo en un
      repositorio de código?
- [ ] ¿El repositorio dice explícitamente algo sobre uso en producción?
- [ ] ¿Tiene número de versión y notas de versión, o solo commits?
- [ ] ¿Hay un canal de soporte, o el único canal son las incidencias del repositorio?
- [ ] ¿Cuándo fue el último cambio? Un componente sin actividad en meses, en un área
      que se mueve así de rápido, es una señal en sí misma.

Cinco preguntas, dos minutos, y la respuesta cabe en una celda de la plantilla.

---

## 3. Las tres formas de conectar un agente a una base

Conviene conocerlas porque tienen perfiles de riesgo distintos, y la conversación
cambia según cuál se elija:

| Forma | Dónde corre | Identidad | Cuándo conviene |
|---|---|---|---|
| **Proceso local** (por ejemplo el de SQLcl) | En el equipo de quien desarrolla | Conexiones guardadas en ese equipo | Desarrollo. Es el del laboratorio |
| **Servicio gestionado en la nube** | En la nube, por HTTPS | La identidad de la nube | Cuando hace falta gobierno central y registro |
| **Punto de acceso en el servicio de datos REST** | Junto a la base | La del servicio REST | Cuando ya se usa esa capa |

**La diferencia práctica está en quién controla la credencial.** En el proceso local,
cada persona guarda sus conexiones en su equipo: cómodo para desarrollar, imposible de
gobernar de forma central. En el servicio gestionado, la identidad y los permisos son
los de la nube, con su registro de auditoría — que es lo que pedirá cualquier cliente
regulado.

Para un taller, el proceso local es el correcto: se ve todo, se rompe sin consecuencias
y no hace falta pedirle nada a nadie.

---

## 4. Skills y servidores no son lo mismo

Se mencionan juntos y se confunden constantemente, pero el riesgo es distinto:

| | Agent Skills | Servidor MCP |
|---|---|---|
| **Qué aporta** | Conocimiento: documentación que el agente consulta | Herramientas: cosas que el agente puede ejecutar |
| **¿Ejecuta algo?** | No | Sí |
| **¿Toca sistemas tuyos?** | No | Sí, los que le permitas |
| **Riesgo principal** | Que el contenido esté desactualizado | Que el alcance sea mayor del que crees |
| **Control** | Revisar qué skill se instala | Catálogo, nivel de restricción **y permisos de la conexión** |

Una skill mal actualizada hace que el agente dé un consejo viejo. Un servidor MCP mal
acotado hace que el agente borre algo. No es el mismo tipo de problema y no merece el
mismo nivel de control.

---

## 5. Lo que hay que llevarse a la plantilla

Tres columnas del entregable salen de aquí, y son las que más discusión ahorran
después:

1. **Madurez declarada** — con la fuente donde se comprobó, no de memoria.
2. **Ambiente permitido** — y si la madurez no es «producto», producción no es una
   opción disponible.
3. **Usuario o identidad** — porque el nivel de restricción limita a la herramienta,
   y el permiso limita el daño.

Si una de las tres queda vacía, el componente no está listo para adoptarse. No porque
sea malo: porque todavía no se ha decidido nada sobre él.
