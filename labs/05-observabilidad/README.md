# Módulo 05 · Observabilidad y confiabilidad

La métrica del módulo 1 convertida en alarma. Suena, avisa con el runbook dentro, y el autoescalamiento la apaga sola.

**Salida del ejercicio:** Matriz señal → umbral → responsable → acción ·
**[Página del módulo](https://jesmonsa.github.io/oci-workshop-labs/modulos/05-observabilidad.html)**

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/jesmonsa/oci-workshop-labs/releases/latest/download/05-observabilidad.zip)

## Qué demuestra

- **El correo trae el runbook enlazado.** Quien lo recibe de madrugada no busca en ningún wiki. Eso es lo que baja el tiempo de recuperación: no el tablero, no la herramienta.
- **La alarma se cierra sola**, porque el autoescalamiento reaccionó. ¿Debía despertar a alguien? No. ¿Debía desaparecer sin rastro? Tampoco. Distinguir lo que se atiende ahora de lo que hay que saber es lo que separa a un equipo que apaga incendios de uno que opera.
- El estado «sin datos»: una alarma ciega se ve exactamente igual que una tranquila. Es el estado más peligroso de un modelo de observabilidad.
- Una alarma que despierta a alguien sin acción escrita es **ruido**, y el ruido es lo que hace que en seis meses nadie mire las que sí importan.

## Arquitectura

```
  carga ──► CPU sube ──► alarma DISPARA ──► correo con el runbook dentro
                                 │
                   el autoescalamiento agrega instancias
                                 │
          CPU por instancia baja ──► la alarma SE CIERRA SOLA
                                      (queda registrada, no despierta a nadie)
```

## Paso a paso

1. **Verificar los nombres de métrica** — Una alarma sobre una métrica que no existe **se crea sin error y nunca suena**. En la consola se ve perfecta. Es la peor forma de fallar.
2. **Desplegar** — Menos de un minuto: son tres recursos.
3. **Confirmar la suscripción de correo** — Hasta ese clic, la alarma dispara igual y la bandeja de entrada sigue vacía. Es el fallo más común y el más frustrante.
4. **Comprobar que las alarmas ven datos** — El panel distingue tres estados. El tercero, «sin datos», no es calma: es ceguera.
5. **Medir el ciclo completo** — El script arranca la carga, cronometra cuánto tarda en disparar y cuánto en cerrarse sola, y lo anota. Sin ese número no se puede cronometrar una demostración.
6. **Capturar el correo** — Con el enlace al runbook visible. Es la imagen del módulo.

El detalle completo, con todos los comandos y la tabla de diagnóstico de fallos, está en
[`docs/MANUAL.md`](docs/MANUAL.md).

## Qué se simplificó, y por qué

Un laboratorio que no dice en qué se apartó de una arquitectura real enseña mal.

| Simplificación | Por qué |
|---|---|
| Solo dos alarmas | Una de causa (saturación) y una de síntoma (servidores caídos). Con esas dos alcanza para mostrar que la severidad la define el impacto, no la magnitud de la métrica. |
| El umbral es más bajo que el del autoescalamiento | A propósito: así la alarma suena primero y el autoescalamiento la apaga después. Ese orden es lo que hace entendible la conversación sobre alarmas que se resuelven solas. |
| Falta lo que un modelo completo necesita | Registros centralizados, trazas distribuidas, prueba sintética desde fuera y revisión periódica. Lo que se muestra es el mínimo viable — y el mínimo viable es justo lo que se puede tener en dos semanas. |

## Cómo se relaciona con los demás

Cierra el círculo: convierte en alarma la misma métrica que disparaba el autoescalamiento en el [módulo 1](../01-elasticidad), incorpora la alerta de cambios críticos del [módulo 2](../02-seguridad) y las señales de negocio del [módulo 4](../04-datos-analitica).
