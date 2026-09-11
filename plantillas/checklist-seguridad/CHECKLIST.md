# Checklist de controles de seguridad

Versión legible del checklist del módulo 2. **En la sesión se usa el Excel**
(`Checklist_Seguridad.xlsx`), que clasifica cada respuesta automáticamente.
Ambos se generan desde `generar_checklist.py`: editar allí, nunca a mano.

**Niveles:** **O** = obligatorio · R = recomendado · Op = opcional · N/A = no aplica.
**Núcleo** = se revisa en vivo en los 40 minutos; el resto queda como autoevaluación.

**Regla de clasificación:** Sí → Cumple · No sé → Riesgo a validar ·
No/Parcial con esfuerzo Bajo → Quick win · No/Parcial con esfuerzo Medio → Profundización.

Total: 39 controles · núcleo: 25.

## Red y segmentación

| ID | Control | Dev | QA | Prod | Esfuerzo | Núcleo |
|---|---|:-:|:-:|:-:|:-:|:-:|
| **R-01** | Capas de aplicación y datos en subredes privadas; solo el balanceador tiene IP pública | R | **O** | **O** | Medio | ● |
| **R-02** | Security list por defecto de cada VCN sin SSH/RDP abierto a 0.0.0.0/0 | **O** | **O** | **O** | Bajo | ● |
| **R-03** | Reglas de tráfico por NSG según función (balanceador → app → datos), no listas amplias por subred | R | **O** | **O** | Medio | ● |
| **R-04** | Salida a internet solo por NAT, a servicios OCI por Service Gateway; la capa de datos sin salida a internet | Op | R | **O** | Bajo |  |
| **R-05** | Ambientes separados por compartment y VCN, sin conectividad abierta entre desarrollo y producción | **O** | **O** | **O** | Medio | ● |

- **R-01** — Una IP pública en un servidor de aplicación es superficie de ataque que no aporta nada: el tráfico legítimo entra por el balanceador. *Verificación:* Script de auditoría (R-01) · subredes con prohibit-public-ip-on-vnic = true
- **R-02** — OCI crea cada VCN con una security list por defecto que abre el 22 a internet. Una subred creada sin especificar lista la hereda. *Verificación:* Script de auditoría (R-02)
- **R-03** — Con NSG, «solo el balanceador habla con la app» se escribe literalmente; con listas por subred se termina abriendo la subred entera. *Verificación:* Script de auditoría (R-03) · VCN → Network Security Groups
- **R-04** — Un servidor comprometido lo primero que intenta es salir. Controlar la salida limita el daño y la exfiltración. *Verificación:* Tablas de ruteo de subredes privadas: sin Internet Gateway
- **R-05** — Un error o una credencial filtrada en desarrollo no debe tener camino hacia producción. *Verificación:* Compartments por ambiente · revisar peering y DRG entre VCNs

## Borde: balanceador y WAF

| ID | Control | Dev | QA | Prod | Esfuerzo | Núcleo |
|---|---|:-:|:-:|:-:|:-:|:-:|
| **B-01** | Solo el balanceador (o un API Gateway) publica servicios a internet | **O** | **O** | **O** | Medio |  |
| **B-02** | WAF con reglas OWASP delante de toda aplicación pública | Op | R | **O** | Bajo | ● |
| **B-03** | TLS terminado en el balanceador con certificado gestionado; HTTP solo redirige a HTTPS | R | **O** | **O** | Bajo | ● |
| **B-04** | Límite de tasa en endpoints sensibles (inicio de sesión, APIs públicas) | Op | R | R | Bajo |  |

- **B-01** — Un único punto de entrada es un único lugar donde aplicar TLS, WAF, límites y registro. *Verificación:* Inventario de IPs públicas: oci network public-ip list
- **B-02** — Filtra ataques comunes (inyección, XSS) antes de que lleguen al código y compra tiempo cuando aparece una vulnerabilidad nueva. *Verificación:* Script de auditoría (B-02)
- **B-03** — Credenciales y sesiones viajan cifradas. Los certificados gestionados evitan caducidades sorpresa. *Verificación:* Script de auditoría (B-03) · listeners del balanceador
- **B-04** — Frena fuerza bruta y abuso de APIs sin tocar la aplicación. *Verificación:* Política WAF: reglas de rate limiting

## Identidad y segregación de funciones

| ID | Control | Dev | QA | Prod | Esfuerzo | Núcleo |
|---|---|:-:|:-:|:-:|:-:|:-:|
| **I-01** | MFA obligatorio para todo acceso a la consola | **O** | **O** | **O** | Bajo | ● |
| **I-02** | Nadie opera el día a día con el grupo Administrators; cuentas de emergencia documentadas y vigiladas | **O** | **O** | **O** | Bajo | ● |
| **I-03** | Grupos por función (red, cómputo, datos, seguridad, auditoría) con políticas limitadas a su compartment | R | **O** | **O** | Medio | ● |
| **I-04** | La automatización (Terraform, CI/CD, scripts) usa principals de instancia o recurso, no llaves API de personas | R | **O** | **O** | Medio | ● |
| **I-05** | Llaves API rotadas cada 90 días como máximo; usuarios inactivos revisados cada trimestre | R | R | **O** | Bajo |  |

- **I-01** — La mayoría de incidentes en nube empiezan con una credencial robada. MFA la vuelve insuficiente por sí sola. *Verificación:* Script de auditoría (I-01) · dominio de identidad → política de inicio de sesión
- **I-02** — El administrador total es la llave maestra: se usa en emergencias, y cuando se usa, alguien se entera. *Verificación:* Miembros del grupo Administrators: pocos, nominales y justificados
- **I-03** — Segregación de funciones: quien despliega aplicaciones no cambia reglas de red ni permisos. *Verificación:* Políticas con «manage all-resources in tenancy» fuera de Administrators
- **I-04** — Una llave API personal en un pipeline es una credencial sin dueño el día que esa persona se va. *Verificación:* Llaves API en variables de CI y archivos ~/.oci de servidores
- **I-05** — Las credenciales viejas son las que nadie recuerda tener. *Verificación:* Script de auditoría (I-05)

## Secretos y cifrado

| ID | Control | Dev | QA | Prod | Esfuerzo | Núcleo |
|---|---|:-:|:-:|:-:|:-:|:-:|
| **S-01** | Ningún secreto en código, tfvars, cloud-init ni variables de CI en texto plano; se consumen desde OCI Vault | **O** | **O** | **O** | Medio | ● |
| **S-02** | Estado de Terraform almacenado remoto, cifrado y con acceso restringido | R | **O** | **O** | Bajo | ● |
| **S-03** | Rotación definida de secretos (credenciales de base de datos, tokens) con responsable | Op | R | R | Medio |  |
| **S-04** | Llaves propias en Vault para datos de producción cuando lo exija un contrato o una regulación | Op | Op | R | Medio |  |

- **S-01** — El repositorio es el primer lugar donde busca un atacante, y el historial de Git no olvida. *Verificación:* git log -p &#124; grep -iE "password&#124;secret&#124;BEGIN .*KEY"
- **S-02** — El tfstate guarda en claro contraseñas y llaves de lo que crea. Suele terminar en un portátil o en un bucket abierto. *Verificación:* ¿Dónde vive el tfstate? Backend en Object Storage con acceso por política
- **S-03** — Un secreto que nunca rota termina filtrándose sin que nadie lo note. *Verificación:* Vault: fecha de la última versión de cada secreto
- **S-04** — OCI cifra todo por defecto; la llave propia agrega control de revocación y evidencia para auditorías. *Verificación:* Volúmenes, buckets y bases: campo kms-key-id

## Acceso administrativo

| ID | Control | Dev | QA | Prod | Esfuerzo | Núcleo |
|---|---|:-:|:-:|:-:|:-:|:-:|
| **A-01** | Acceso administrativo por OCI Bastion con sesiones que expiran; sin SSH/RDP expuesto | R | **O** | **O** | Bajo | ● |
| **A-02** | Llaves SSH por persona, nunca compartidas; revocación inmediata cuando alguien sale del equipo | **O** | **O** | **O** | Bajo | ● |
| **A-03** | Parcheo de sistema operativo con cadencia definida y medida | R | **O** | **O** | Medio |  |

- **A-01** — El 22 abierto no es una necesidad operativa, es una costumbre. Bastion da el mismo acceso con identidad, TTL y registro. *Verificación:* Script de auditoría (R-02, R-03) · Identity & Security → Bastion
- **A-02** — Una llave compartida hace imposible saber quién hizo qué y obliga a rotar para todos. *Verificación:* authorized_keys en los servidores: ¿una llave por persona?
- **A-03** — La mayoría de explotaciones usan vulnerabilidades con parche disponible hace meses. *Verificación:* OS Management Hub o equivalente: % de hosts al día

## Seguridad de datos

| ID | Control | Dev | QA | Prod | Esfuerzo | Núcleo |
|---|---|:-:|:-:|:-:|:-:|:-:|
| **D-01** | Bases de datos sin endpoint público; acceso solo desde el NSG de aplicación | **O** | **O** | **O** | Bajo | ● |
| **D-02** | Buckets de Object Storage sin acceso público, salvo contenido intencionalmente público y documentado | **O** | **O** | **O** | Bajo | ● |
| **D-03** | La aplicación usa un usuario de base de datos con mínimo privilegio, nunca el administrador | R | **O** | **O** | Medio | ● |
| **D-04** | Datos de producción no se copian a desarrollo o pruebas sin enmascaramiento | **O** | **O** | N/A | Medio | ● |
| **D-05** | Evaluación periódica de configuración y usuarios de la base (Data Safe o equivalente) | Op | R | R | Bajo |  |
| **D-06** | Respaldos cifrados, fuera del alcance de las credenciales de producción, con restauración probada cada trimestre | R | R | **O** | Medio |  |

- **D-01** — Una base expuesta a internet recibe intentos de acceso en minutos. *Verificación:* Consola de la base: sin IP pública · NSG con el puerto solo desde la app
- **D-02** — Es la fuga de datos más común y más evitable de la nube. *Verificación:* Script de auditoría (D-02)
- **D-03** — Si la aplicación se compromete, el atacante hereda exactamente los permisos de ese usuario. *Verificación:* Usuarios y privilegios definidos en la base
- **D-04** — Desarrollo tiene casi siempre controles más débiles. Datos reales ahí son producción sin protección. *Verificación:* Procedimiento de refresco de ambientes
- **D-05** — Detecta usuarios sobrantes, privilegios excesivos y configuraciones débiles antes que un auditor. *Verificación:* Data Safe: evaluación de seguridad y de usuarios [VALIDAR soporte según motor]
- **D-06** — Un respaldo que nunca se restauró es una hipótesis. Y un ransomware que alcanza los respaldos los cifra también. *Verificación:* Última restauración de prueba documentada

## Postura

| ID | Control | Dev | QA | Prod | Esfuerzo | Núcleo |
|---|---|:-:|:-:|:-:|:-:|:-:|
| **P-01** | Cloud Guard habilitado con detectores de configuración y actividad sobre todos los compartments | **O** | **O** | **O** | Bajo | ● |
| **P-02** | Security Zones en los compartments de producción | Op | R | **O** | Medio | ● |
| **P-03** | Escaneo de vulnerabilidades de hosts e imágenes de contenedor | R | R | R | Bajo |  |
| **P-04** | Revisión periódica contra el CIS OCI Foundations Benchmark | Op | R | R | Medio |  |

- **P-01** — Detecta de forma continua lo que un checklist revisa una vez. No tiene costo adicional. *Verificación:* Script de auditoría (P-01) · Cloud Guard → Problems
- **P-02** — Pasa de detectar a prevenir: la plataforma rechaza lo que viola la política antes de que exista. *Verificación:* Security Zones asociadas a los compartments de producción
- **P-03** — Sin inventario de vulnerabilidades no hay forma de priorizar parches. *Verificación:* Vulnerability Scanning: recetas y objetivos configurados
- **P-04** — Da una línea base externa y reconocida para medir avance y responder auditorías. *Verificación:* Reporte de cumplimiento CIS del repositorio OCI CIS Landing Zone

## Registro y respuesta

| ID | Control | Dev | QA | Prod | Esfuerzo | Núcleo |
|---|---|:-:|:-:|:-:|:-:|:-:|
| **L-01** | Retención de Audit en 365 días | **O** | **O** | **O** | Bajo | ● |
| **L-02** | Flow logs de VCN en subredes de producción | Op | R | R | Bajo |  |
| **L-03** | Alertas ante cambios críticos: políticas IAM, security lists, NSGs y gateways | R | **O** | **O** | Bajo | ● |
| **L-04** | Procedimiento de respuesta a incidentes con responsables, contactos y primeros pasos | R | R | **O** | Medio | ● |
| **L-05** | Registros centralizados y enviados a SIEM o Logging Analytics con retención definida | Op | R | R | Medio |  |

- **L-01** — Muchos incidentes se descubren meses después. Sin registro no hay investigación posible. *Verificación:* Script de auditoría (L-01) · Tenancy → Audit retention
- **L-02** — Permiten reconstruir quién habló con quién durante un incidente. *Verificación:* Script de auditoría (L-02)
- **L-03** — Un cambio de regla a las 2 a. m. debería despertar a alguien, no descubrirse en la preparación. *Verificación:* Events + Notifications con reglas sobre esos tipos de evento
- **L-04** — En un incidente, la primera hora se pierde decidiendo quién decide. *Verificación:* Documento vigente y probado en un simulacro
- **L-05** — Correlacionar Audit, red y aplicación es lo que convierte registros en detección. *Verificación:* Service Connector Hub hacia SIEM o Logging Analytics

## Operación para terceros

| ID | Control | Dev | QA | Prod | Esfuerzo | Núcleo |
|---|---|:-:|:-:|:-:|:-:|:-:|
| **M-01** | Cada cliente final en tenancy o compartment propio; nunca recursos de dos clientes en el mismo compartment | R | **O** | **O** | Medio | ● |
| **M-02** | El equipo de la organización entra a los tenancies de clientes con identidades nominales y federadas, no usuarios compartidos | **O** | **O** | **O** | Medio | ● |
| **M-03** | Registro revisable de qué operador accedió a qué cliente y cuándo | R | **O** | **O** | Bajo |  |

- **M-01** — Aísla impacto, permisos y costo por cliente. Es también la base del showback por cliente del módulo 1. *Verificación:* Estructura de compartments o tenancies por cliente
- **M-02** — Un usuario compartido entre operadores impide atribuir acciones y cumplirle al cliente. *Verificación:* Usuarios en tenancies de clientes: ¿nominales? ¿federados?
- **M-03** — Es lo primero que pide un cliente regulado (salud, sector cooperativo) antes de delegar su operación. *Verificación:* Audit por tenancy, con revisión periódica
