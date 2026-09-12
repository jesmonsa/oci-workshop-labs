# Política de adopción de agentes — plantilla

Versión en Markdown de la hoja «Servidores». **En la sesión se usa el Excel**
(`Politica_Agentes.xlsx`), que aplica solo las dos reglas de abajo.

## Las dos reglas

| Combinación | Resultado |
|---|---|
| Madurez *prueba de concepto* o *preview* + ambiente *producción* | **NO PERMITIDO** |
| Puede escribir + sin aprobador o sin identidad definida | **Falta aprobador** |

La primera no es una opinión sobre la calidad del software: es que su propio autor
dice que no está pensado para producción. Si aun así se quiere usar, la conversación
se tiene con esa frase encima de la mesa.

## La pregunta que más cambia la conversación

> **¿Con qué usuario de base de datos conecta el agente?**

El nivel de restricción de un servidor MCP limita a la herramienta, no a la base.
Si la conexión guardada es administradora, el agente tiene permisos de administrador
por muy cerrado que esté el nivel. El control que de verdad acota el daño es el
permiso de siempre.

## Componentes candidatos

| ID | Componente | Qué expone | Madurez | ¿Escribe? |
|---|---|---|---|---|
| **MCP-01** | SQLcl (servidor MCP local) | Cinco herramientas sobre una conexión guardada: listar conexiones, conectar, desconectar, ejecutar SQL y ejecutar comandos de SQLcl. | Producto | Sí |
| **MCP-02** | Servidor MCP gestionado de base de datos en la nube | Acceso a bases de datos por HTTPS con identidad de la nube y catálogos de herramientas gobernados. | Producto | Sí |
| **MCP-03** | Punto de acceso MCP incorporado en el servicio de datos REST | Alternativa por HTTPS sin proceso local. | Producto | Sí |
| **MCP-04** | Servidor MCP de infraestructura (uso general) | Decenas de herramientas para consultar y administrar recursos del tenancy. | Prueba de concepto | Sí |
| **MCP-05** | Servidor MCP de operación de infraestructura | Aprovisionar, administrar, monitorear y asegurar recursos por conversación. | Prueba de concepto | Sí |
| **MCP-06** | Servidor MCP de recuperación ante desastres | Consulta y operación de planes de recuperación. | Prueba de concepto | Sí |
| **MCP-07** | Agente propio con catálogo cerrado de solo lectura | Construido en casa, con un catálogo acotado y un validador determinista. | Propio | No |
| **MCP-08** | Agent Skills (conocimiento, no herramientas) | No expone herramientas ni ejecuta nada: aporta documentación de referencia al agente de código. | Producto | No |

> **La columna de madurez se verifica antes de cada sesión.** Este ecosistema se
> mueve rápido y lo que hoy es una prueba de concepto puede ser producto en seis meses.

## Lo que se llena en vivo

¿Lo vamos a usar? · Ambiente permitido · **Usuario o identidad** · Nivel de restricción ·
¿Queda registro? · **Quién aprueba ampliar** · Notas.

Las dos columnas en negrita son las que convierten una herramienta en una decisión.

## La política final

Cuatro frases, una por ambiente: equipo local, desarrollo, pruebas y producción.
Si las cuatro dicen lo mismo, no es una política: es una ilusión.
