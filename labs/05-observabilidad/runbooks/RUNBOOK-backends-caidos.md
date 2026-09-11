# Runbook · Servidores no saludables detrás del balanceador

| | |
|---|---|
| **Alarma** | `lab05-backends-no-saludables` |
| **Severidad** | CRITICAL — el usuario lo está sintiendo ahora |
| **Qué significa** | Al menos un servidor no pasa la verificación de salud hace 2 minutos |
| **Responsable** | Turno de operación · escala inmediatamente si caen todos |
| **Tiempo objetivo** | Diagnóstico en 3 minutos |

> **Por qué es CRITICAL aunque el número sea pequeño.** La severidad la define el
> impacto, no la magnitud. La alarma de CPU avisa de una causa posible; esta avisa de
> un síntoma que el usuario ya está viendo.

---

## 1. Alcance: 30 segundos

```bash
oci lb backend-health list --load-balancer-id "$LB" --backend-set-name "$BSET" --output table
```

| Lo que ves | Qué significa | Urgencia |
|---|---|---|
| 1 de N caído | El balanceador ya lo sacó de rotación | Media: hay servicio |
| Mitad caídos | Capacidad al límite, degradación probable | Alta |
| **Todos caídos** | **Caída total del servicio** | Máxima: escalar ya |

---

## 2. Las tres causas, en orden de frecuencia

### 2.a · Instancia recién creada que aún no arranca

Si el pool acaba de crecer, un backend nuevo aparece como no saludable hasta que la
aplicación levanta. **Si la alarma llegó justo después de un escalamiento, esperar dos
minutos antes de tocar nada.**

### 2.b · La aplicación se cayó en una instancia

```bash
# Entrar por el bastión (nunca por SSH público)
ssh -i <llave> -o ProxyCommand="..." opc@<ip-privada>
sudo systemctl status lab-app
sudo journalctl -u lab-app -n 50 --no-pager
sudo systemctl restart lab-app
```

### 2.c · El cortafuegos del sistema operativo bloquea la verificación

La causa más frustrante, porque la instancia se ve perfecta:

```bash
sudo firewall-cmd --list-ports     # debe incluir 80/tcp
```

---

## 3. Si están todos caídos

1. **Declarar incidente.** Avisar antes de diagnosticar: quien comunica no es quien
   resuelve.
2. Revisar si hubo un cambio reciente: despliegue, cambio de regla de red, cambio de
   configuración. *La causa más probable de una caída total es un cambio, no una avería.*
3. Revisar la alarma de cambios críticos del bloque de seguridad: si llegó un correo de
   cambio de security list en la última hora, ahí está la respuesta.
4. Revertir antes que arreglar. Entender puede esperar; el servicio no.

---

## 4. Después del incidente

- [ ] Línea de tiempo: cuándo empezó, cuándo se detectó, cuándo se resolvió.
- [ ] **La diferencia entre «empezó» y «se detectó» es el número que hay que mejorar.**
      Si el cliente avisó antes que la alarma, el problema de hoy no fue la caída:
      fue la observabilidad.
- [ ] Informe breve dentro de las 48 horas. No busca culpables; busca la señal que
      faltaba.

---

## 5. Escalamiento

| Cuándo | A quién |
|---|---|
| Todos los backends caídos | Líder de operación, inmediato |
| Más de 15 min de impacto | Arquitectura + comercial de la cuenta afectada |
| Se sospecha causa de seguridad | Seguridad, y no se reinicia nada hasta preservar evidencia |

---

*Última revisión: ___ · Dueño de este runbook: ___*
