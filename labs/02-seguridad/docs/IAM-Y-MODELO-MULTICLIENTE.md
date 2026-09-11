# Referencia: segregación de funciones y modelo multi-cliente

Material de apoyo para los dominios **I** (identidad) y **M** (operación para terceros) del
checklist. No se proyecta completo en la sesión: se abre si la conversación lo pide, y se
entrega como parte del repositorio.

---

## 1. Grupos por función

Propuesta de partida para la organización. La idea no es tener muchos grupos, sino que **ningún grupo
de trabajo diario pueda cambiar a la vez red, cómputo e identidades.**

| Grupo | Hace | No puede |
|---|---|---|
| `Administrators` | Emergencias. 2–3 cuentas nominales, vigiladas. | — (por eso casi no se usa) |
| `NetAdmins` | Gestionar VCNs, subredes, NSGs, gateways, balanceadores | Crear instancias, tocar IAM |
| `AppOps` | Desplegar y operar cómputo, contenedores, funciones | Cambiar reglas de red, tocar IAM |
| `DBAdmins` | Gestionar bases de datos administradas | Cambiar red o cómputo |
| `SecOps` | Cloud Guard, Vault, Security Zones, Bastion; leer todo | Desplegar aplicaciones |
| `Auditores` | Leer configuración y registros de auditoría | Modificar nada |

### Políticas de ejemplo

Compartments de ejemplo: `prod`, `prod:app`, `prod:datos`, `seguridad`.
En tenancies con dominios de identidad, los grupos se referencian como `'Default'/'NetAdmins'`.

```text
# NetAdmins — red, y solo red
Allow group NetAdmins to manage virtual-network-family in compartment prod
Allow group NetAdmins to manage load-balancers in compartment prod
Allow group NetAdmins to read instance-family in compartment prod

# AppOps — usa la red (conectar VNICs) pero no la cambia
Allow group AppOps to manage instance-family in compartment prod:app
Allow group AppOps to manage cluster-family in compartment prod:app
Allow group AppOps to use virtual-network-family in compartment prod
Allow group AppOps to read secret-bundles in compartment prod:app

# DBAdmins
Allow group DBAdmins to manage mysql-family in compartment prod:datos
Allow group DBAdmins to use virtual-network-family in compartment prod

# SecOps
Allow group SecOps to manage cloud-guard-family in tenancy
Allow group SecOps to manage vaults in compartment seguridad
Allow group SecOps to manage keys in compartment seguridad
Allow group SecOps to manage bastion-family in compartment prod
Allow group SecOps to read all-resources in tenancy

# Auditores
Allow group Auditores to inspect all-resources in tenancy
Allow group Auditores to read audit-events in tenancy
```

> La diferencia entre `manage` y `use` en la red es la segregación en una palabra: AppOps
> puede poner una instancia en una subred (`use`), pero no puede abrir un puerto (`manage`).

### Automatización sin llaves personales (control I-04)

la organización usa Terraform y la CLI hoy, y planea incorporar el SDK. Ese es el momento de
decidir con qué identidad corre la automatización:

| Dónde corre | Identidad recomendada |
|---|---|
| Una instancia de OCI (runner propio) | *Instance principal*: grupo dinámico con las instancias del runner |
| OCI DevOps / Functions | *Resource principal* |
| GitHub Actions u otro CI externo | Usuario de servicio (no personal), llave rotada, permisos acotados por compartment — o federación de identidad de carga de trabajo si está disponible `[VALIDAR]` |

```text
# Grupo dinámico: las instancias del runner de Terraform de desarrollo
ALL {instance.compartment.id = '<ocid-compartment-cicd>'}

# Política: ese runner solo gestiona el compartment de desarrollo
Allow dynamic-group RunnerTerraformDev to manage all-resources in compartment dev
```

---

## 2. Modelo multi-cliente (dominio M)

la organización opera infraestructura para sus clientes. En 7) se
planteó además la posibilidad de absorber infraestructura de clientes que hoy son directos
de Oracle, con la opción técnica de un **tenancy independiente por cliente**.

| | A. Tenancy por cliente | B. Compartment por cliente (en el tenancy de la organización) |
|---|---|---|
| **Aislamiento** | Total: identidades, límites, red y registros separados | Lógico: depende de que las políticas estén bien escritas |
| **Radio de impacto de un error de IAM** | Un cliente | Potencialmente todos |
| **Facturación** | Separada por naturaleza, un contrato por cliente | Una sola factura; showback por tags y compartments |
| **Operación para la organización** | Más tenancies que gestionar; requiere identidad federada para no multiplicar usuarios | Más simple de operar |
| **Qué pide un cliente regulado** | Normalmente esto | Hay que demostrar el aislamiento |
| **Cuándo conviene** | Clientes regulados, clientes grandes, clientes que migran desde contrato directo con Oracle | Clientes pequeños con cargas estándar |

**Recomendación de partida:** no es uno u otro. Un modelo mixto —tenancy propio para
clientes regulados o grandes, compartments para el resto— con **tres reglas iguales para
ambos**:

1. Identidades **nominales y federadas** de los operadores de la organización (control M-02).
   Nunca un usuario compartido "operaciones@".
2. **Trazabilidad por cliente**: quién entró, a qué cliente, cuándo (control M-03).
3. **Tags obligatorios** con el identificador de cliente en todo recurso, para que el
   showback del módulo 1 funcione en cualquiera de los dos modelos.

> Este modelo es el candidato natural a una sesión de profundización: toca arquitectura,
> seguridad y modelo de operación al mismo tiempo.
