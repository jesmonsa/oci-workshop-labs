# Runbook · [Nombre de la alarma]

> **Regla de oro:** cabe en una pantalla y lo puede seguir alguien que no diseñó el
> sistema, a las 3 de la mañana, con sueño. Si necesita contexto que solo tiene el
> arquitecto, no es un runbook: es una nota.

| | |
|---|---|
| **Alarma** | |
| **Severidad** | INFO / WARNING / CRITICAL |
| **Qué significa** | En una frase, sin jerga |
| **Responsable** | Rol, no persona. Las personas rotan |
| **Tiempo objetivo** | Diagnóstico en ___ · decisión en ___ |

---

## 1. Verificación rápida (60 segundos)

Los dos o tres comandos que dicen si esto es grave, copiables tal cual.

```bash
```

**La primera pregunta debe ser la que más veces evita trabajo.** Normalmente es:
*¿la plataforma ya lo está resolviendo sola?*

---

## 2. Árbol de decisión

```
¿Pregunta que parte el problema en dos?
├── SÍ  → ...
└── NO  → ...
```

---

## 3. Acciones

Una sección por rama, con los comandos exactos.

### 3.a ·

---

## 4. Después

- [ ] Registrar el evento aunque se haya resuelto solo.
- [ ] ¿El umbral sigue siendo el correcto?
- [ ] ¿Hubo impacto al usuario? → informe breve.

---

## 5. Escalamiento

| Cuándo | A quién |
|---|---|
| | |

---

*Última revisión: ___ · Dueño: ___*

---

## Cómo se sabe que un runbook es bueno

1. **Alguien que no lo escribió lo siguió** y funcionó.
2. **Empieza por descartar**, no por diagnosticar: la primera pregunta elimina la mitad
   de los casos.
3. **Dice qué NO hacer.** Reiniciar antes de mirar los registros borra la evidencia.
4. **Tiene fecha de revisión.** Sin fecha, en seis meses nadie sabe si sigue siendo cierto.
5. **Viaja con la alarma.** Un runbook que hay que buscar es un runbook que no se usa.
6. **Contempla que no haya que hacer nada.** La rama «esto se resuelve solo, regístralo
   y vuelve a dormir» es la más valiosa y la que casi nunca se escribe.
