"""
Genera la salida formal del módulo 3 desde una única fuente de datos:

  - Ficha_Caso_IA.xlsx   -> se proyecta y se llena EN VIVO.
                                    Hoja «Priorización»: ordena los candidatos solo.
                                    Hoja «Ficha»: el formulario del caso elegido.
  - CANDIDATOS.md                -> catálogo de casos, legible en GitHub.
  - FICHA-CASO-USO.md -> la misma ficha en Markdown, para papel o memoria.

Editar CANDIDATOS / CRITERIOS / CAMPOS y volver a correr:
    python generar_ficha.py
Después abrir el Excel y guardarlo una vez para que calcule.
"""

from pathlib import Path

from openpyxl import Workbook
from openpyxl.formatting.rule import FormulaRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.worksheet.datavalidation import DataValidation

AQUI = Path(__file__).parent

# --- Criterios de priorización (peso, sentido) -------------------------------
# Los cuatro se puntúan de 1 a 5 y SIEMPRE en el mismo sentido: 5 es mejor.
# Por eso riesgo y tiempo se enuncian invertidos, para que nadie se confunda al votar.
CRITERIOS = [
    ("Valor", 0.35, "¿Cuánto mejora el trabajo de alguien concreto? 5 = mucho."),
    ("Datos", 0.25, "¿Existen los datos, están accesibles y en buen estado? 5 = listos hoy."),
    ("Riesgo bajo", 0.20, "¿Qué pasa si el modelo se equivoca? 5 = consecuencia menor y reversible."),
    ("Rapidez", 0.20, "¿Qué tan pronto se ve un resultado? 5 = piloto en dos semanas."),
]

# (id, caso, qué hace, usuario, requisito crítico)
CANDIDATOS = [
    ("IA-01", "Asistente de soporte sobre documentación y tickets",
     "Busca y responde sobre manuales, notas de versión e historial de tickets, citando la fuente.",
     "Agentes de soporte N1 y N2",
     "Documentación y tickets accesibles en formato digital y razonablemente ordenados."),
    ("IA-02", "Agente de operación cloud (consulta y diagnóstico)",
     "Responde en lenguaje natural sobre el estado de la infraestructura: inventario, exposición, salud, costo. Solo lectura.",
     "Equipo de infraestructura y operaciones de la organización",
     "Un catálogo cerrado de consultas y un validador que impida cualquier escritura."),
    ("IA-03", "Copiloto de desarrollo (código y pruebas)",
     "Sugiere código, genera pruebas unitarias y explica código heredado.",
     "Equipo de desarrollo",
     "Política clara sobre qué código puede salir del entorno y cuál no."),
    ("IA-04", "Clasificación y enrutamiento automático de tickets",
     "Asigna categoría, prioridad y grupo resolutor al crear el ticket.",
     "Mesa de servicio",
     "Histórico de tickets bien etiquetado para medir si acierta."),
    ("IA-05", "Resumen de incidentes y borrador de informe post-incidente",
     "Reúne cronología, acciones y efectos, y redacta el borrador que hoy nadie quiere escribir.",
     "Operaciones y líderes técnicos",
     "Registros y bitácoras del incidente en un solo lugar."),
    ("IA-06", "Búsqueda semántica en portal B2B o catálogo",
     "Permite buscar por intención y no por palabra exacta.",
     "Clientes de la organización en el portal",
     "Catálogo con descripciones suficientes para que la búsqueda tenga de dónde agarrarse."),
    ("IA-07", "Capacidad embebida en ERP, WHS o Sales/RCP",
     "Recomendaciones o asistencia dentro del producto: sugerir reposición, detectar anomalías, explicar un indicador.",
     "Usuarios finales del producto de la organización",
     "Definir si la capacidad es igual para todos los clientes o se adapta por cliente."),
    ("IA-08", "Consulta del estado de su ambiente para el cliente final",
     "Cada cliente pregunta en lenguaje natural por el estado, el consumo y los eventos de SU ambiente.",
     "Clientes a los que la organización opera la infraestructura",
     "Aislamiento estricto por cliente: la respuesta jamás puede mezclar datos de dos clientes."),
]

# --- Campos de la ficha (etiqueta, ayuda, alto de fila) ----------------------
CAMPOS = [
    ("Nombre del caso", "Como lo llamarían dentro de la organización.", 22),
    ("Problema", "Una frase, SIN mencionar inteligencia artificial. Si el problema solo existe "
                 "cuando se menciona la IA, no es un problema.", 40),
    ("¿Quién lo sufre?", "Una persona concreta con nombre de cargo, no «el negocio» ni «los clientes».", 30),
    ("¿Cómo se resuelve hoy?", "Qué hace hoy esa persona, cuánto tiempo le toma y con qué frecuencia.", 40),
    ("Costo actual del problema", "Horas al mes, errores, reprocesos o clientes afectados. Aproximado sirve.", 30),
    ("Fuentes de datos", "Qué datos hacen falta y dónde están hoy.", 40),
    ("Clasificación de esos datos", "Públicos · internos · confidenciales · de clientes finales. "
                                    "Si hay datos de clientes, el caso hereda las obligaciones del contrato con ellos.", 40),
    ("Arquitectura conceptual", "Dos o tres líneas: de dónde salen los datos, qué los procesa, dónde se muestra.", 40),
    ("Modo de operación", "¿Asiste a una persona que decide, o actúa solo? ¿Qué acciones puede tomar "
                          "y cuáles tiene prohibidas?", 40),
    ("Riesgos y controles", "Respuesta incorrecta, fuga de datos, inyección de instrucciones, dependencia. "
                            "Para cada uno: qué control lo contiene.", 55),
    ("KPI principal", "Un solo indicador. El que le importa al usuario del caso, no al proyecto.", 25),
    ("Línea base y meta", "Cuánto vale hoy ese indicador y cuánto sería un buen resultado.", 25),
    ("Criterio de éxito del experimento", "El umbral que decide seguir o parar. Se escribe ANTES de empezar.", 35),
    ("Diseño del experimento (2 semanas)", "Qué se construye, con qué muestra, quién lo prueba, cómo se mide.", 45),
    ("Qué NO va a hacer", "Alcance negativo explícito. Es lo que evita que el piloto crezca hasta morir.", 35),
    ("Dueño en la organización", "Una persona. No un área.", 22),
    ("Apoyo de Oracle", "Quién acompaña y en qué.", 22),
    ("Siguiente paso y fecha", "Concreto, con fecha, para las próximas dos semanas.", 30),
]

# --- Estilos -----------------------------------------------------------------
FUENTE, AZUL, GRIS = "Arial", "1F3864", "595959"
FILL_HEAD = PatternFill("solid", start_color=AZUL)
FILL_INPUT = PatternFill("solid", start_color="FFF2CC")
FILL_SUAVE = PatternFill("solid", start_color="D9E1F2")
FILL_GANADOR = PatternFill("solid", start_color="C6EFCE")
BORDE = Border(*(Side(style="thin", color="BFBFBF"),) * 4)


def f(bold=False, size=10, color="000000", italic=False):
    return Font(name=FUENTE, bold=bold, size=size, color=color, italic=italic)


def construir_xlsx(ruta):
    wb = Workbook()
    ws_leeme = wb.active
    ws_leeme.title = "Leeme"
    wp = wb.create_sheet("Priorización")
    wf = wb.create_sheet("Ficha")

    # ======================= PRIORIZACIÓN =======================
    wp["A1"] = "Priorización de casos de uso de IA — Taller de arquitectura en OCI · módulo 3"
    wp["A1"].font = f(True, 14, AZUL)
    wp["A2"] = ("Puntuar de 1 a 5. En los cuatro criterios, 5 siempre es lo mejor. "
                "El puntaje y el orden se calculan solos.")
    wp["A2"].font = f(size=9, color=GRIS, italic=True)

    for col, ancho in zip("ABCDEFGHIJK", [8, 34, 46, 26, 9, 9, 11, 10, 10, 8, 40]):
        wp.column_dimensions[col].width = ancho

    # Pesos (fila 4), encabezados (fila 5), datos desde la 6
    wp["D4"] = "Pesos →"
    wp["D4"].font = f(True, 9, GRIS)
    wp["D4"].alignment = Alignment(horizontal="right")
    for j, (nombre, peso, _) in enumerate(CRITERIOS):
        c = wp.cell(row=4, column=5 + j, value=peso)
        c.font = f(True, 9, "C00000")
        c.number_format = "0%"
        c.alignment = Alignment(horizontal="center")

    encabezados = ["ID", "Caso", "Qué hace", "Usuario"] + [c[0] for c in CRITERIOS] + \
                  ["Puntaje", "Orden", "Requisito crítico"]
    for j, h in enumerate(encabezados, start=1):
        c = wp.cell(row=5, column=j, value=h)
        c.font = f(True, 10, "FFFFFF")
        c.fill = FILL_HEAD
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        c.border = BORDE
    wp.row_dimensions[5].height = 30

    primera, ultima = 6, 6 + len(CANDIDATOS) - 1
    for i, (cid, caso, que, usuario, requisito) in enumerate(CANDIDATOS):
        r = primera + i
        for col, v in enumerate([cid, caso, que, usuario], start=1):
            c = wp.cell(row=r, column=col, value=v)
            c.font = f(bold=(col == 1))
            c.alignment = Alignment(vertical="top", wrap_text=True,
                                    horizontal="center" if col == 1 else "left")
            c.border = BORDE
        for j in range(len(CRITERIOS)):          # celdas de puntuación
            c = wp.cell(row=r, column=5 + j)
            c.fill = FILL_INPUT
            c.border = BORDE
            c.alignment = Alignment(horizontal="center", vertical="center")
            c.font = f(True, 11)
        c = wp.cell(row=r, column=9,
                    value=f"=IF(COUNT(E{r}:H{r})<4,\"\",ROUND(SUMPRODUCT(E{r}:H{r},$E$4:$H$4),2))")
        c.font = f(True, 11, AZUL)
        c.alignment = Alignment(horizontal="center", vertical="center")
        c.border = BORDE
        c = wp.cell(row=r, column=10,
                    value=f'=IF(I{r}="","",RANK(I{r},$I${primera}:$I${ultima}))')
        c.font = f(True, 11)
        c.alignment = Alignment(horizontal="center", vertical="center")
        c.border = BORDE
        c = wp.cell(row=r, column=11, value=requisito)
        c.font = f(size=9, color=GRIS)
        c.alignment = Alignment(vertical="top", wrap_text=True)
        c.border = BORDE
        wp.row_dimensions[r].height = 46

    dv = DataValidation(type="whole", operator="between", formula1=1, formula2=5,
                        allow_blank=True, showErrorMessage=True,
                        errorTitle="Fuera de rango", error="Puntuar de 1 a 5.")
    wp.add_data_validation(dv)
    dv.add(f"E{primera}:H{ultima}")

    wp.conditional_formatting.add(
        f"A{primera}:K{ultima}",
        FormulaRule(formula=[f"$J{primera}=1"], fill=FILL_GANADOR))

    fila = ultima + 2
    wp.cell(row=fila, column=1, value="Cómo se puntúa").font = f(True, 11, AZUL)
    for k, (nombre, peso, ayuda) in enumerate(CRITERIOS, start=1):
        wp.cell(row=fila + k, column=1, value=nombre).font = f(True, 9)
        wp.cell(row=fila + k, column=2, value=f"{peso:.0%}").font = f(size=9, color="C00000")
        c = wp.cell(row=fila + k, column=3, value=ayuda)
        c.font = f(size=9)
        c.alignment = Alignment(wrap_text=True)
    fila += len(CRITERIOS) + 2
    c = wp.cell(row=fila, column=1,
                value="El puntaje ordena la conversación; no la reemplaza. Si el grupo quiere el "
                      "segundo en vez del primero, se elige el segundo y se escribe por qué.")
    c.font = f(size=9, italic=True, color=GRIS)

    wp.freeze_panes = "E6"
    wp.page_setup.orientation = "landscape"
    wp.sheet_properties.pageSetUpPr.fitToPage = True
    wp.page_setup.fitToWidth = 1
    wp.page_setup.fitToHeight = 0

    # ======================= FICHA =======================
    wf.column_dimensions["A"].width = 3
    wf.column_dimensions["B"].width = 30
    wf.column_dimensions["C"].width = 78
    wf.column_dimensions["D"].width = 52

    wf["B2"] = "Ficha de caso de uso de IA"
    wf["B2"].font = f(True, 16, AZUL)
    wf["B3"] = "Taller de arquitectura en OCI · módulo 3 · la fecha del taller"
    wf["B3"].font = f(size=10, color=GRIS)
    wf["D2"] = "Se llena en vivo, en los últimos 13 minutos del bloque."
    wf["D2"].font = f(size=9, italic=True, color=GRIS)

    r = 5
    for etiqueta, ayuda, alto in CAMPOS:
        ce = wf.cell(row=r, column=2, value=etiqueta)
        ce.font = f(True, 10, "FFFFFF")
        ce.fill = FILL_HEAD
        ce.alignment = Alignment(vertical="center", wrap_text=True)
        ce.border = BORDE
        ci = wf.cell(row=r, column=3)
        ci.fill = FILL_INPUT
        ci.border = BORDE
        ci.alignment = Alignment(vertical="top", wrap_text=True)
        ci.font = f()
        ca = wf.cell(row=r, column=4, value=ayuda)
        ca.font = f(size=9, italic=True, color=GRIS)
        ca.alignment = Alignment(vertical="top", wrap_text=True)
        wf.row_dimensions[r].height = alto
        r += 1

    r += 1
    wf.cell(row=r, column=2, value="Marcados para validar").font = f(True, 11, AZUL)
    r += 1
    for j, h in enumerate(["Supuesto", "Quién lo confirma", "Para cuándo"]):
        c = wf.cell(row=r, column=2 + j, value=h)
        c.font = f(True, 9, "FFFFFF")
        c.fill = FILL_HEAD
        c.border = BORDE
    for k in range(3):
        for j in range(3):
            c = wf.cell(row=r + 1 + k, column=2 + j)
            c.fill = FILL_INPUT
            c.border = BORDE
        wf.row_dimensions[r + 1 + k].height = 20

    wf.page_setup.orientation = "portrait"
    wf.sheet_properties.pageSetUpPr.fitToPage = True
    wf.page_setup.fitToWidth = 1
    wf.page_setup.fitToHeight = 0

    # ======================= LEEME =======================
    ws_leeme.column_dimensions["A"].width = 3
    ws_leeme.column_dimensions["B"].width = 30
    ws_leeme.column_dimensions["C"].width = 92
    ws_leeme["B2"] = "Cómo se usa este archivo"
    ws_leeme["B2"].font = f(True, 16, AZUL)
    ws_leeme["B3"] = "Taller de arquitectura en OCI · módulo 3 · IA aplicada al producto, soporte y operación"
    ws_leeme["B3"].font = f(size=10, color=GRIS)

    bloques = [
        ("En la sesión", None),
        ("Minuto 24", "Hoja «Priorización». Se puntúan los 8 candidatos de 1 a 5 en cada criterio. "
                      "Diez minutos, sin debate largo: la primera intuición del grupo sirve."),
        ("Minuto 33", "Se mira el orden. Se elige UNO. Si el grupo prefiere el segundo, se elige el "
                      "segundo y se anota la razón: el puntaje ordena, no manda."),
        ("Minuto 34", "Hoja «Ficha». Se llena campo por campo, en voz alta, para el caso elegido."),
        ("Minuto 47", "Los tres últimos campos —dueño, qué no va a hacer, siguiente paso— no se "
                      "dejan para después. Son los que hacen que esto ocurra."),
        ("", None),
        ("Las dos reglas del ejercicio", None),
        ("Una frase sin «IA»", "El campo «Problema» se escribe sin mencionar inteligencia artificial. "
                               "Si el problema solo existe cuando se menciona la IA, no es un problema."),
        ("Una persona, no un área", "«¿Quién lo sufre?» se responde con un cargo concreto. "
                                    "Los casos que no tienen un usuario con nombre no llegan a producción."),
        ("", None),
        ("Qué se edita", None),
        ("Celdas amarillas", "Puntajes en Priorización, respuestas en Ficha. Todo lo demás se calcula."),
        ("", None),
        ("Después de la sesión", None),
        ("Entrega", "Esta ficha, completa, va en la memoria del bloque, dentro de las 48 horas. "
                    "El experimento de dos semanas empieza con ella, no con un documento nuevo."),
    ]
    r = 5
    for a, b in bloques:
        ca = ws_leeme.cell(row=r, column=2, value=a)
        if b is None and a:
            ca.font = f(True, 11, AZUL)
        else:
            ca.font = f(True, 10)
            cb = ws_leeme.cell(row=r, column=3, value=b)
            cb.font = f(size=10)
            cb.alignment = Alignment(wrap_text=True, vertical="top")
            ws_leeme.row_dimensions[r].height = 30
        r += 1

    wb.active = 1
    wb.save(ruta)


def construir_md():
    lineas = [
        "# Candidatos de casos de uso de IA",
        "",
        "Catálogo de partida para la priorización del módulo 3. **No son recomendaciones**:",
        "son candidatos para que la organización descarte, ajuste o priorice. La priorización se hace",
        "en vivo en `Ficha_Caso_IA.xlsx`, hoja «Priorización».",
        "",
        "## Criterios",
        "",
        "Los cuatro se puntúan de 1 a 5, y **5 siempre es lo mejor**.",
        "",
        "| Criterio | Peso | Qué se pregunta |",
        "|---|:-:|---|",
    ]
    for nombre, peso, ayuda in CRITERIOS:
        lineas.append(f"| {nombre} | {peso:.0%} | {ayuda} |")
    lineas += ["", "## Candidatos", ""]
    for cid, caso, que, usuario, requisito in CANDIDATOS:
        lineas += [f"### {cid} · {caso}", "",
                   f"{que}", "",
                   f"- **Usuario:** {usuario}",
                   f"- **Requisito crítico:** {requisito}", ""]
    lineas += [
        "## Campos de la ficha",
        "",
        "| Campo | Qué se busca |", "|---|---|",
        *[f"| {e} | {a} |" for e, a, _ in CAMPOS],
        "",
    ]
    (AQUI / "CANDIDATOS.md").write_text("\n".join(lineas), encoding="utf-8")

    ficha = [
        "# Ficha de caso de uso de IA — plantilla",
        "",
        "Versión en Markdown de la hoja «Ficha» del Excel, para imprimir o para pegar en la",
        "memoria de la sesión. **En vivo se usa el Excel**; esta versión es para el registro.",
        "",
        "| | |",
        "|---|---|",
        "| **Caso elegido** | |",
        "| **Fecha** | la fecha del taller |",
        "| **Participantes** | |",
        "",
    ]
    for etiqueta, ayuda, _ in CAMPOS:
        ficha += [f"## {etiqueta}", "", f"> {ayuda}", "", "", ""]
    ficha += [
        "## Marcados para validar", "",
        "| Supuesto | Quién lo confirma | Para cuándo |", "|---|---|---|",
        "| | | |", "| | | |", "| | | |", "",
    ]
    (AQUI / "FICHA-CASO-USO.md").write_text("\n".join(ficha), encoding="utf-8")


if __name__ == "__main__":
    ids = [c[0] for c in CANDIDATOS]
    assert len(ids) == len(set(ids)), "IDs duplicados"
    assert abs(sum(c[1] for c in CRITERIOS) - 1.0) < 1e-9, "Los pesos deben sumar 100%"
    construir_xlsx(AQUI / "Ficha_Caso_IA.xlsx")
    construir_md()
    print(f"Generado: {len(CANDIDATOS)} candidatos, {len(CAMPOS)} campos de ficha.")
