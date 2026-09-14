# Runbook · Saturación de CPU

> **Este enlace viaja dentro del correo de la alarma.** Si quien lo abre a las 3 de la
> mañana tiene que buscar en un wiki cuál es el procedimiento, el runbook no sirve.

| | |
|---|---|
| **Alarma** | `lab05-saturacion-cpu` |
| **Severidad** | WARNING — degradación probable, no caída |
| **Qué significa** | La CPU del servicio lleva más de 3 minutos por encima del 45 % |
| **Responsable** | Turno de operación · escala a arquitectura si pasa de 30 min |
| **Tiempo objetivo** | Diagnóstico en 5 minutos · decisión en 15 |

---

## 1. Antes de tocar nada: 60 segundos de verificación

```bash
# ¿El autoescalamiento ya reaccionó?
oci compute-management instance-pool get --instance-pool-id "$POOL" \
  --query 'data.{tamano:size,estado:"lifecycle-state"}'

# ¿El usuario lo está sintiendo?
oci lb backend-set-health get --load-balancer-id "$LB" --backend-set-name "$BSET" \
  --query 'data.{estado:status,total:"total-backend-count",criticos:"critical-state-backend-names"}'

# ¿Es carga real o un solo cliente disparado?
curl -s "http://$LB/" | head -3
```

**La primera pregunta es la que más tiempo ahorra.** Si el pool ya creció y los backends
están sanos, la plataforma está haciendo su trabajo y **nadie está perdiendo servicio**.

Pero no esperes a que la alarma se cierre por haber más capacidad: **no se cierra por
eso**. Medido: con la carga sostenida, el pool llegó a su máximo y la alarma siguió
sonando 35 minutos. Más capacidad sube el rendimiento, no baja la utilización. La alarma
se cierra cuando **baja la demanda** (medido: 115 s después de cortar la carga). La
pregunta útil no es «¿ya se cerró?», sino **«¿el pool llegó a su tope?»**.

---

## 2. Árbol de decisión

```
¿El pool creció y los backends están OK?
├── SÍ  → ¿El pool está en su tamaño máximo?
│         ├── NO  → NO HAY ACCIÓN urgente: está absorbiendo la ráfaga. Se registra y
│         │         se revisa en la preparación (sección 4), aunque la alarma siga sonando.
│         └── SÍ  → Ya no queda margen para crecer. Ir a 3.a
└── NO  → ¿Los backends están caídos?
          ├── SÍ  → Esto ya es la alarma CRITICAL. Ver RUNBOOK-backends-caidos.md
          └── NO  → El autoescalamiento no está reaccionando. Ir a 3.b
```

---

## 3. Acciones

### 3.a · El pool llegó a su tope

La capacidad máxima configurada no alcanza para la demanda actual.

```bash
# Subir el techo (cambio temporal; el cambio permanente va por el repositorio)
oci autoscaling configuration update --auto-scaling-configuration-id "$AS" \
  --policies '[{"capacity":{"initial":2,"max":8,"min":2}, ...}]' --force
```

Después del incidente, el cambio se hace en Terraform y pasa por revisión. Un cambio
de capacidad hecho a mano y no versionado es la forma más común de que la siguiente
persona no entienda por qué el ambiente no coincide con el código.

### 3.b · El autoescalamiento no reacciona

Causas, en orden de probabilidad:

1. **El plugin de monitoreo está deshabilitado** en las instancias nuevas → no hay
   métrica → la regla nunca dispara. Es la causa número uno.
2. **Periodo de enfriamiento activo** desde un escalamiento anterior (5 min por defecto).
3. La configuración de autoescalamiento está deshabilitada.

```bash
oci autoscaling configuration get --auto-scaling-configuration-id "$AS" \
  --query 'data.{habilitado:"is-enabled",enfriamiento:"cool-down-in-seconds"}'
```

### 3.c · Es un solo cliente o un abuso

Si el tráfico viene concentrado en un origen: limitación de tasa en el WAF
(control B-04 del bloque de seguridad). No se escala infraestructura para absorber
un abuso — se sale más caro y no resuelve nada.

---

## 4. Después: lo que casi nadie hace

- [ ] Registrar el evento aunque se haya resuelto solo. **Tres alarmas que se cierran
      solas en una semana son una señal de capacidad, no tres falsos positivos.**
- [ ] Si se cerró sola en menos de 15 minutos y no hubo impacto: revisar si el umbral
      debe subir. Una alarma que suena y nunca requiere acción se vuelve invisible.
- [ ] Si hubo impacto al usuario: entra a la revisión semanal con su línea de tiempo.

---

## 5. Escalamiento

| Cuándo | A quién |
|---|---|
| Más de 30 min sin resolver | Arquitectura |
| Hay impacto visible al cliente final | Líder de operación + comercial de esa cuenta |
| Se sospecha abuso o ataque | Seguridad |

---

*Última revisión: ___ · Dueño de este runbook: ___*

> Un runbook sin fecha de revisión es un runbook que ya no es verdad. Se revisa cada
> vez que se usa, aunque sea para confirmar que sigue estando bien.
