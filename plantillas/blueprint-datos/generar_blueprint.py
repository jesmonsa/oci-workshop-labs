"""
Genera la salida formal del módulo 4 desde una única fuente de datos:

  - Blueprint_Datos.xlsx   -> se proyecta y se llena EN VIVO.
      · Hoja «Fuentes»: inventario, con dueño y calidad. Marca solo lo que falta.
      · Hoja «Blueprint»: el lienzo de seis casillas.
  - ../docs/04-BLUEPRINT.md        -> el mismo lienzo en Markdown, para imprimir.

    python generar_blueprint.py
Después abrir el Excel y guardarlo una vez para que calcule.
"""

from pathlib import Path

from openpyxl import Workbook
from openpyxl.formatting.rule import FormulaRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.worksheet.datavalidation import DataValidation

AQUI = Path(__file__).parent

# Las seis casillas del lienzo, en el orden en que se llenan. El orden importa:
# empieza por la decisión, no por los datos. Casi todo el mundo lo hace al revés y
# termina con un tablero bonito que nadie abre.
CASILLAS = [
    ("1. La decisión",
     "¿Qué decisión se toma con esto, quién la toma y cada cuánto? "
     "Si no hay decisión, no hay tablero: hay un reporte.", 70),
    ("2. La pregunta",
     "La pregunta exacta que responde. Una sola, redactada como la diría esa persona.", 60),
    ("3. Las fuentes",
     "De qué sistemas sale. Se detalla en la hoja «Fuentes».", 60),
    ("4. El procesamiento",
     "Qué hay que hacerle a los datos: unir, limpiar, agregar, enmascarar. "
     "Con qué frecuencia se actualiza y cuánto retraso se tolera.", 70),
    ("5. La visualización",
     "Dónde lo ve esa persona: ¿tablero aparte, o dentro del producto que ya usa? "
     "¿Lo ve la organización, o también sus clientes?", 70),
    ("6. Los responsables",
     "Dueño del dato en el origen · quién construye · quién lo mantiene vivo · "
     "a quién se le reclama cuando el número está mal.", 70),
]

# Fuentes precargadas: hipótesis de trabajo para que la tabla no arranque vacía.
# la organización corrige, borra y agrega. Todas marcadas como [VALIDAR] a propósito.
FUENTES = [
    ("F-01", "Documentos electrónicos emitidos", "Plataforma de documentos", "Transaccional"),
    ("F-02", "Respuestas de la autoridad tributaria", "Integración externa", "Transaccional"),
    ("F-03", "Maestro de clientes", "ERP", "Maestro"),
    ("F-04", "Inventario y movimientos", "WHS / ERP", "Transaccional"),
    ("F-05", "Tickets de soporte", "Mesa de servicio", "Operativo"),
    ("F-06", "Registros de la plataforma (aplicación)", "Infraestructura", "Operativo"),
    ("F-07", "Métricas de infraestructura y costo", "OCI", "Operativo"),
    ("F-08", "Actividad de usuarios en el portal B2B", "Portal", "Comportamiento"),
]

COLUMNAS_FUENTES = [
    ("ID", 7, None),
    ("Fuente", 34, None),
    ("Sistema de origen", 22, None),
    ("Tipo", 15, None),
    ("¿Existe hoy?", 13, '"Sí,Parcial,No,No sé"'),
    ("Frecuencia de actualización", 20, '"Tiempo real,Cada hora,Diaria,Semanal,Manual,No sé"'),
    ("Calidad (1-5)", 12, None),
    ("Sensibilidad", 16, '"Interna,Confidencial,De clientes finales,No sé"'),
    ("Dueño del dato", 22, None),
    ("¿Sirve para el caso de IA?", 16, '"Sí,No,No sé"'),
    ("Notas", 32, None),
]

FUENTE, AZUL, GRIS = "Arial", "1F3864", "595959"
FILL_HEAD = PatternFill("solid", start_color=AZUL)
FILL_INPUT = PatternFill("solid", start_color="FFF2CC")
FILL_ALERTA = PatternFill("solid", start_color="FFC7CE")
FILL_OK = PatternFill("solid", start_color="C6EFCE")
BORDE = Border(*(Side(style="thin", color="BFBFBF"),) * 4)


def f(bold=False, size=10, color="000000", italic=False):
    return Font(name=FUENTE, bold=bold, size=size, color=color, italic=italic)


def construir_xlsx(ruta):
    wb = Workbook()
    ws_leeme = wb.active
    ws_leeme.title = "Leeme"
    wf = wb.create_sheet("Fuentes")
    wb_ = wb.create_sheet("Blueprint")

    # ============================ FUENTES ============================
    wf["A1"] = "Inventario de fuentes de datos — Taller de arquitectura en OCI · módulo 4"
    wf["A1"].font = f(True, 14, AZUL)
    wf["A2"] = ("Las filas vienen precargadas como hipótesis: corregir, borrar y agregar. "
                "Lo que importa no es completarla, sino descubrir qué no se sabe.")
    wf["A2"].font = f(size=9, color=GRIS, italic=True)

    for j, (nombre, ancho, _) in enumerate(COLUMNAS_FUENTES, start=1):
        c = wf.cell(row=4, column=j, value=nombre)
        c.font = f(True, 10, "FFFFFF")
        c.fill = FILL_HEAD
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        c.border = BORDE
        wf.column_dimensions[c.column_letter].width = ancho
    wf.row_dimensions[4].height = 34

    primera = 5
    ultima = primera + len(FUENTES) + 3          # cuatro filas en blanco para agregar
    for i in range(len(FUENTES) + 4):
        r = primera + i
        datos = FUENTES[i] if i < len(FUENTES) else ("", "", "", "")
        for j, v in enumerate(datos, start=1):
            c = wf.cell(row=r, column=j, value=v)
            c.font = f(bold=(j == 1))
            c.alignment = Alignment(vertical="center", wrap_text=True,
                                    horizontal="center" if j == 1 else "left")
            c.border = BORDE
        for j in range(5, len(COLUMNAS_FUENTES) + 1):
            c = wf.cell(row=r, column=j)
            c.fill = FILL_INPUT
            c.border = BORDE
            c.font = f()
            c.alignment = Alignment(horizontal="center" if j in (5, 6, 7, 8, 10) else "left",
                                    vertical="center", wrap_text=True)
        wf.row_dimensions[r].height = 30

    for j, (_, _, lista) in enumerate(COLUMNAS_FUENTES, start=1):
        if lista:
            dv = DataValidation(type="list", formula1=lista, allow_blank=True)
            wf.add_data_validation(dv)
            letra = wf.cell(row=4, column=j).column_letter
            dv.add(f"{letra}{primera}:{letra}{ultima}")
    dv_cal = DataValidation(type="whole", operator="between", formula1=1, formula2=5,
                            allow_blank=True, showErrorMessage=True,
                            errorTitle="Fuera de rango", error="Calidad de 1 a 5.")
    wf.add_data_validation(dv_cal)
    dv_cal.add(f"G{primera}:G{ultima}")

    # Lo que hay que mirar: sin dueño, calidad mala, o nadie sabe.
    wf.conditional_formatting.add(f"I{primera}:I{ultima}",
                                  FormulaRule(formula=[f'AND($B{primera}<>"",$I{primera}="")'],
                                              fill=FILL_ALERTA))
    wf.conditional_formatting.add(f"G{primera}:G{ultima}",
                                  FormulaRule(formula=[f'AND($G{primera}<>"",$G{primera}<=2)'],
                                              fill=FILL_ALERTA))
    for letra in ("E", "F", "H", "J"):
        wf.conditional_formatting.add(f"{letra}{primera}:{letra}{ultima}",
                                      FormulaRule(formula=[f'${letra}{primera}="No sé"'],
                                                  fill=FILL_ALERTA))

    fila = ultima + 2
    resumen = [
        ("Fuentes inventariadas", f'=COUNTA($B${primera}:$B${ultima})'),
        ("Sin dueño identificado",
         f'=COUNTIFS($B${primera}:$B${ultima},"<>",$I${primera}:$I${ultima},"")'),
        ("Con calidad 1 o 2", f'=COUNTIFS($G${primera}:$G${ultima},"<=2",$G${primera}:$G${ultima},"<>")'),
        ("Con algún «No sé»",
         f'=SUMPRODUCT(--(COUNTIF(OFFSET($E${primera},ROW($E${primera}:$E${ultima})-ROW($E${primera}),0,1,6),"No sé")>0))'),
        ("Marcadas como útiles para el caso de IA",
         f'=COUNTIF($J${primera}:$J${ultima},"Sí")'),
    ]
    wf.cell(row=fila, column=1, value="Resumen").font = f(True, 11, AZUL)
    for k, (etq, formula) in enumerate(resumen, start=1):
        wf.cell(row=fila + k, column=1, value=etq).font = f(size=10)
        wf.merge_cells(start_row=fila + k, start_column=1, end_row=fila + k, end_column=3)
        c = wf.cell(row=fila + k, column=4, value=formula)
        c.font = f(True, 11, "C00000" if k in (2, 3, 4) else "000000")
        c.alignment = Alignment(horizontal="center")
        c.border = BORDE
    wf.cell(row=fila + len(resumen) + 2, column=1,
            value="Las tres cifras en rojo son la agenda de las próximas dos semanas.").font = \
        f(size=9, italic=True, color=GRIS)

    wf.freeze_panes = "E5"
    wf.page_setup.orientation = "landscape"
    wf.sheet_properties.pageSetUpPr.fitToPage = True
    wf.page_setup.fitToWidth = 1
    wf.page_setup.fitToHeight = 0

    # ============================ BLUEPRINT ============================
    wb_.column_dimensions["A"].width = 3
    wb_.column_dimensions["B"].width = 26
    wb_.column_dimensions["C"].width = 82
    wb_.column_dimensions["D"].width = 46

    wb_["B2"] = "Blueprint del flujo analítico"
    wb_["B2"].font = f(True, 16, AZUL)
    wb_["B3"] = "Taller de arquitectura en OCI · módulo 4 · la fecha del taller"
    wb_["B3"].font = f(size=10, color=GRIS)
    wb_["B4"] = "Prioridad elegida:"
    wb_["B4"].font = f(True, 10)
    c = wb_.cell(row=4, column=3)
    c.fill = FILL_INPUT
    c.border = BORDE

    r = 6
    for etiqueta, ayuda, alto in CASILLAS:
        ce = wb_.cell(row=r, column=2, value=etiqueta)
        ce.font = f(True, 10, "FFFFFF")
        ce.fill = FILL_HEAD
        ce.alignment = Alignment(vertical="center", wrap_text=True)
        ce.border = BORDE
        ci = wb_.cell(row=r, column=3)
        ci.fill = FILL_INPUT
        ci.border = BORDE
        ci.alignment = Alignment(vertical="top", wrap_text=True)
        ca = wb_.cell(row=r, column=4, value=ayuda)
        ca.font = f(size=9, italic=True, color=GRIS)
        ca.alignment = Alignment(vertical="top", wrap_text=True)
        wb_.row_dimensions[r].height = alto
        r += 1

    r += 1
    wb_.cell(row=r, column=2, value="Primer entregable (2 semanas)").font = f(True, 11, AZUL)
    r += 1
    for etq in ("Qué se construye", "Quién", "Para cuándo", "Cómo se sabe que sirvió"):
        ce = wb_.cell(row=r, column=2, value=etq)
        ce.font = f(True, 10, "FFFFFF")
        ce.fill = FILL_HEAD
        ce.border = BORDE
        ci = wb_.cell(row=r, column=3)
        ci.fill = FILL_INPUT
        ci.border = BORDE
        wb_.row_dimensions[r].height = 26
        r += 1

    wb_.page_setup.orientation = "portrait"
    wb_.sheet_properties.pageSetUpPr.fitToPage = True
    wb_.page_setup.fitToWidth = 1
    wb_.page_setup.fitToHeight = 0

    # ============================ LEEME ============================
    ws_leeme.column_dimensions["A"].width = 3
    ws_leeme.column_dimensions["B"].width = 28
    ws_leeme.column_dimensions["C"].width = 92
    ws_leeme["B2"] = "Cómo se usa este archivo"
    ws_leeme["B2"].font = f(True, 16, AZUL)
    ws_leeme["B3"] = "Taller de arquitectura en OCI · módulo 4 · Datos y analítica operacional"
    ws_leeme["B3"].font = f(size=10, color=GRIS)

    bloques = [
        ("En la sesión", None),
        ("Minuto 19", "Hoja «Fuentes». Se recorre el inventario para la prioridad elegida. "
                      "Las casillas se ponen rojas solas donde falta dueño, la calidad es mala "
                      "o alguien respondió «No sé»."),
        ("Minuto 29", "Hoja «Blueprint». Las seis casillas, en orden, empezando por la decisión."),
        ("Minuto 37", "Las cuatro filas del primer entregable. Con nombre y fecha."),
        ("", None),
        ("La regla del bloque", None),
        ("Primero la decisión", "Una métrica sin decisión asociada es decoración. Por eso la "
                                "casilla 1 es la decisión y no las fuentes."),
        ("«No sé» vale", "Es la respuesta más útil del inventario: marca dónde hay trabajo real "
                         "antes de construir nada."),
        ("", None),
        ("Qué se edita", None),
        ("Celdas amarillas", "Todo lo demás se calcula o es texto de apoyo."),
        ("", None),
        ("Después de la sesión", None),
        ("Entrega", "Este archivo va en la memoria del bloque, dentro de las 48 horas. "
                    "Las tres cifras en rojo del resumen son la agenda de las dos semanas siguientes."),
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
            ws_leeme.row_dimensions[r].height = 32
        r += 1

    wb.active = 1
    wb.save(ruta)


def construir_md():
    lineas = [
        "# Blueprint del flujo analítico — plantilla",
        "",
        "Versión en Markdown del lienzo. **En vivo se usa el Excel**",
        "(`blueprint/Blueprint_Datos.xlsx`); esta versión sirve para imprimir,",
        "para dibujarlo en el tablero o para pegarlo en la memoria.",
        "",
        "> **El orden de las casillas no es casual.** Empieza por la decisión y termina en",
        "> los responsables. Casi todo el mundo empieza por los datos y termina con un",
        "> tablero que nadie abre.",
        "",
        "**Prioridad elegida:** ______________________",
        "",
    ]
    for etiqueta, ayuda, _ in CASILLAS:
        lineas += [f"## {etiqueta}", "", f"> {ayuda}", "", "", ""]
    lineas += [
        "## Primer entregable (2 semanas)", "",
        "| | |", "|---|---|",
        "| **Qué se construye** | |",
        "| **Quién** | |",
        "| **Para cuándo** | |",
        "| **Cómo se sabe que sirvió** | |",
        "",
        "## Inventario de fuentes", "",
        "Se llena en la hoja «Fuentes» del Excel. Columnas:", "",
        "| " + " | ".join(c[0] for c in COLUMNAS_FUENTES) + " |",
        "|" + "---|" * len(COLUMNAS_FUENTES),
        "| " + " | ".join("" for _ in COLUMNAS_FUENTES) + " |",
        "",
        "Fuentes precargadas como hipótesis de trabajo (todas por validar con la organización):", "",
    ]
    for cid, nombre, sistema, tipo in FUENTES:
        lineas.append(f"- **{cid}** {nombre} — origen: {sistema} · tipo: {tipo}")
    lineas.append("")
    (AQUI.parent / "docs" / "04-BLUEPRINT.md").write_text("\n".join(lineas), encoding="utf-8")


if __name__ == "__main__":
    ids = [f[0] for f in FUENTES]
    assert len(ids) == len(set(ids)), "IDs duplicados"
    construir_xlsx(AQUI / "Blueprint_Datos.xlsx")
    construir_md()
    print(f"Generado: {len(FUENTES)} fuentes precargadas, {len(CASILLAS)} casillas.")
