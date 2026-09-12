"""
Genera la salida formal del bloque 8 desde una única fuente de datos:

  - Hoja_de_Ruta.xlsx      -> se proyecta y se llena EN VIVO.
      · Hoja «Selección»:    los candidatos que dejaron los cinco bloques.
                             La hoja no deja pasar más de dos sin decirlo.
      · Hoja «Hoja de ruta»: iniciativa -> horizonte -> dueño -> métrica -> fecha.
      · Hoja «Compromiso»:   la página que se lee en voz alta al final.
  - HOJA-DE-RUTA.md     -> la misma hoja en Markdown, para imprimir.

    python generar_hoja_de_ruta.py
Después abrir el Excel y guardarlo una vez para que calcule.

La mecánica que se explica en la sala:

    Una línea con dueño, fecha y métrica con valor objetivo es un compromiso.
    Una línea sin dueño o sin fecha es un deseo, y la hoja la declara
    NO EJECUTABLE en rojo. No lo dice el facilitador: lo dice la hoja.
    Y tiene dos salidas válidas — completarla, o borrarla. Dejarla, no.
"""

from pathlib import Path

from openpyxl import Workbook
from openpyxl.formatting.rule import FormulaRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

AQUI = Path(__file__).parent

# Nombres de hoja entrecomillados: van dentro de fórmulas y llevan tilde y espacios.
SEL = "'Selección'"
RUT = "'Hoja de ruta'"

HORIZONTES = ["0-30 días", "31-60 días", "61-90 días"]

# --- Candidatos que dejan los cinco bloques técnicos -------------------------
# No son recomendaciones: son lo que la jornada produjo. La sala elige DOS.
# (id, de dónde viene, candidato, tipo, qué trae ya hecho, precondición)
CANDIDATOS = [
    ("K-01", "módulo 1", "Backlog priorizado de elasticidad y costo",
     "Plataforma",
     "Cinco líneas ordenadas por impacto y esfuerzo, votadas en sala y con dueño.",
     "Que las cinco líneas hayan salido con dueño. Una línea sin dueño no entra."),
    ("K-02", "módulo 2", "Quick wins de seguridad",
     "Transversal",
     "Controles de esfuerzo bajo que el checklist clasificó solo, con su dominio.",
     "Por su bajo esfuerzo NO compiten por un lugar: se ejecutan en paralelo."),
    ("K-03", "Bloques 5 y 6", "Caso de IA con su blueprint de datos",
     "Datos/IA",
     "Ficha del caso, experimento de dos semanas con criterio de parada, "
     "inventario de fuentes con dueño y calidad.",
     "Que las fuentes del caso existan y tengan dueño. Si no, primero hay un "
     "proyecto de datos y el caso de IA viene después."),
    ("K-04", "módulo 5", "Modelo de observabilidad mínimo viable",
     "Plataforma",
     "Matriz señal → umbral → responsable → acción para un servicio, y la lista "
     "de señales que despiertan a alguien sin acción escrita.",
     "La primera lista se resuelve escribiendo, no construyendo: es la más barata "
     "de todo el plan."),
    ("K-05", "módulo 1", "Benchmark de costo sobre una carga representativa",
     "Plataforma",
     "Metodología y alcance discutidos; responde el punto abierto  de julio.",
     "Exige elegir la carga y acordar los criterios antes de medir nada."),
    ("K-06", "La sala", "Iniciativa propuesta por la organización",
     "",
     "Lo que el grupo traiga y no haya salido de ningún bloque.",
     "Compite con las anteriores en igualdad de condiciones. No se suma: desplaza."),
]

COLUMNAS_SEL = [
    ("ID", 7, None),
    ("De dónde viene", 14, None),
    ("Candidato", 42, None),
    ("Tipo", 14, '"Plataforma,Datos/IA,Transversal"'),
    ("Qué trae ya hecho", 44, None),
    ("Precondición", 40, None),
    ("¿Entra al plan?", 14, '"Sí,En paralelo,No"'),
    ("Por qué (una frase)", 34, "input"),
    ("Dueño propuesto", 20, "input"),
]

COLUMNAS_RUTA = [
    ("Línea", 8, None),
    ("Iniciativa", 32, "mixta"),          # las 6 primeras se traen de «Selección»
    ("Horizonte", 13, f'"{",".join(HORIZONTES)}"'),
    ("Qué queda listo al final del horizonte", 40, "input"),
    ("Dueño en la organización", 20, "input"),
    ("Dueño en Oracle", 18, "input"),
    ("Dependencia", 26, "input"),
    ("Métrica de éxito", 28, "input"),
    ("Valor de partida", 14, "input"),
    ("Valor objetivo", 14, "input"),
    ("Fecha de revisión", 15, "fecha"),
    ("Estado", 15, '"Acordado,Por confirmar,En riesgo,Descartado"'),
    ("Clasificación", 18, "formula"),
    ("Notas", 26, "input"),
]

# Columnas de la hoja de ruta que convierten una línea en un compromiso.
# Si falta cualquiera de ellas, la clasificación dice «No ejecutable». Y «falta»
# incluye escribir `[VALIDAR]`: esa marca significa «sin verificar», así que una
# línea base en [VALIDAR] es una línea sin línea base, no una línea completa.
OBLIGATORIAS = {"E": "dueño", "K": "fecha", "H": "métrica", "J": "valor objetivo"}

FUENTE, AZUL, GRIS = "Arial", "1F3864", "595959"
FILL_HEAD = PatternFill("solid", start_color=AZUL)
FILL_INPUT = PatternFill("solid", start_color="FFF2CC")
FILL_CALC = PatternFill("solid", start_color="D9E1F2")
FILL_ALERTA = PatternFill("solid", start_color="FFC7CE")
FILL_ELEGIDA = PatternFill("solid", start_color="C6EFCE")
BORDE = Border(*(Side(style="thin", color="BFBFBF"),) * 4)

COLORES_CLASIF = {
    "Ejecutable": ("C6EFCE", "006100"),
    "No ejecutable": ("FFC7CE", "9C0006"),
    "En riesgo": ("FCE4D6", "C65911"),
    "Sin línea base": ("FFEB9C", "7F6000"),
    "Por confirmar": ("BDD7EE", "1F3864"),
    "Descartada": ("D9D9D9", "595959"),
}


def f(bold=False, size=10, color="000000", italic=False):
    return Font(name=FUENTE, bold=bold, size=size, color=color, italic=italic)


def construir_xlsx(ruta):
    wb = Workbook()
    ws_leeme = wb.active
    ws_leeme.title = "Leeme"
    ws = wb.create_sheet("Selección")
    wr = wb.create_sheet("Hoja de ruta")
    wc = wb.create_sheet("Compromiso")

    # Rangos de «Selección»: 6 candidatos + 3 filas libres para lo que traiga la sala.
    S_PRIM = 5
    S_ULT = S_PRIM + len(CANDIDATOS) + 2
    rs = lambda col: f"{SEL}!${col}${S_PRIM}:${col}${S_ULT}"

    # Rangos de «Hoja de ruta»: 2 iniciativas x 3 horizontes + 4 filas libres.
    R_PRIM = 6
    R_FIJAS = 6
    R_ULT = R_PRIM + R_FIJAS + 3
    rr = lambda col: f"{RUT}!${col}${R_PRIM}:${col}${R_ULT}"

    # ============================ SELECCIÓN ============================
    ws["A1"] = "Selección de iniciativas — Taller de arquitectura en OCI · Bloque 8"
    ws["A1"].font = f(True, 14, AZUL)
    ws["A2"] = ("Lo que dejaron los cinco bloques técnicos. Se eligen DOS: una de plataforma y "
                "otra de datos/IA. Los quick wins de seguridad van en paralelo y no compiten.")
    ws["A2"].font = f(size=9, color=GRIS, italic=True)

    for j, (nombre, ancho, _) in enumerate(COLUMNAS_SEL, start=1):
        c = ws.cell(row=4, column=j, value=nombre)
        c.font = f(True, 10, "FFFFFF")
        c.fill = FILL_HEAD
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        c.border = BORDE
        ws.column_dimensions[get_column_letter(j)].width = ancho
    ws.row_dimensions[4].height = 34

    for i in range(len(CANDIDATOS) + 3):
        r = S_PRIM + i
        datos = CANDIDATOS[i] if i < len(CANDIDATOS) else ("", "", "", "", "", "")
        for j, v in enumerate(datos, start=1):
            c = ws.cell(row=r, column=j, value=v)
            c.font = f(bold=(j == 1), size=10 if j <= 4 else 9,
                       color="000000" if j <= 5 else GRIS)
            c.alignment = Alignment(vertical="top", wrap_text=True,
                                    horizontal="center" if j in (1, 2, 4) else "left")
            c.border = BORDE
        for j, (_, _, tipo) in enumerate(COLUMNAS_SEL, start=1):
            if tipo == "input" or (tipo and tipo.startswith('"')):
                c = ws.cell(row=r, column=j)
                c.fill = FILL_INPUT
                c.border = BORDE
                c.font = f()
                c.alignment = Alignment(vertical="top", wrap_text=True,
                                        horizontal="center" if j in (4, 7) else "left")
        # Auxiliar: numera 1, 2, 3… las que entran al plan. La hoja de ruta las lee de aquí.
        ws.cell(row=r, column=11,
                value=f'=IF($G{r}="Sí",COUNTIF($G${S_PRIM}:$G{r},"Sí"),"")'
                ).font = f(size=8, color="A6A6A6")
        ws.row_dimensions[r].height = 46

    ws.column_dimensions["K"].hidden = True

    for j, (_, _, tipo) in enumerate(COLUMNAS_SEL, start=1):
        if tipo and tipo.startswith('"'):
            dv = DataValidation(type="list", formula1=tipo, allow_blank=True)
            ws.add_data_validation(dv)
            letra = get_column_letter(j)
            dv.add(f"{letra}{S_PRIM}:{letra}{S_ULT}")

    ws.conditional_formatting.add(
        f"A{S_PRIM}:I{S_ULT}",
        FormulaRule(formula=[f'$G{S_PRIM}="Sí"'], fill=FILL_ELEGIDA))
    ws.conditional_formatting.add(
        f"H{S_PRIM}:H{S_ULT}",
        FormulaRule(formula=[f'AND($G{S_PRIM}="Sí",$H{S_PRIM}="")'], fill=FILL_ALERTA))

    fila = S_ULT + 2
    ws.cell(row=fila, column=1, value="Cuenta de la selección").font = f(True, 11, AZUL)
    cuentas = [
        ("Iniciativas seleccionadas (máximo 2)", f'=COUNTIF({rs("G")},"Sí")', True),
        ("De plataforma", f'=COUNTIFS({rs("G")},"Sí",{rs("D")},"Plataforma")', False),
        ("De datos/IA", f'=COUNTIFS({rs("G")},"Sí",{rs("D")},"Datos/IA")', False),
        ("En paralelo (no compiten por un lugar)", f'=COUNTIF({rs("G")},"En paralelo")', False),
        ("Descartadas explícitamente", f'=COUNTIF({rs("G")},"No")', False),
    ]
    for k, (etq, formula, destacar) in enumerate(cuentas, start=1):
        c1 = ws.cell(row=fila + k, column=1, value=etq)
        c1.font = f(bold=destacar)
        ws.merge_cells(start_row=fila + k, start_column=1, end_row=fila + k, end_column=2)
        c2 = ws.cell(row=fila + k, column=3, value=formula)
        c2.font = f(True, 11, "C00000" if destacar else "000000")
        c2.alignment = Alignment(horizontal="center")
        c2.border = BORDE

    fila += len(cuentas) + 2
    c = ws.cell(row=fila, column=1, value=(
        f'=IF(COUNTIF({rs("G")},"Sí")=0,'
        f'"Todavía no hay plan: no se ha marcado ninguna iniciativa.",'
        f'IF(COUNTIF({rs("G")},"Sí")>2,'
        f'"Son "&COUNTIF({rs("G")},"Sí")&". La propuesta ejecutiva dice máximo dos, '
        f'una de plataforma y otra de datos/IA, para preservar foco. Hay que bajar a dos.",'
        f'IF(COUNTIF({rs("G")},"Sí")=1,'
        f'"Va una. Falta la otra: si la primera es de plataforma, la segunda es de datos/IA.",'
        f'IF(AND(COUNTIFS({rs("G")},"Sí",{rs("D")},"Plataforma")>=1,'
        f'COUNTIFS({rs("G")},"Sí",{rs("D")},"Datos/IA")>=1),'
        f'"Dos iniciativas, una de plataforma y otra de datos/IA. Foco preservado: '
        f'se pasa a la hoja de ruta.",'
        f'"Son dos, pero del mismo tipo. Es una decisión válida si se escribe por qué."))))'))
    c.font = f(True, 11, AZUL)
    c.alignment = Alignment(wrap_text=True, vertical="center")
    ws.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=6)
    ws.row_dimensions[fila].height = 32

    ws.cell(row=fila + 2, column=1, value=(
        "Elegir dos no es renunciar al resto: es reconocer cuántas cosas puede empezar de "
        "verdad un equipo en 90 días. Lo que no entra no se borra — queda en las memorias "
        "de cada bloque, con su dueño, esperando la siguiente conversación.")
        ).font = f(size=9, italic=True, color=GRIS)
    ws.merge_cells(start_row=fila + 2, start_column=1, end_row=fila + 2, end_column=6)
    ws.row_dimensions[fila + 2].height = 28

    ws.auto_filter.ref = f"A4:I{S_ULT}"
    ws.freeze_panes = "C5"
    ws.page_setup.orientation = "landscape"
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.print_title_rows = "4:4"

    # ============================ HOJA DE RUTA ============================
    wr["A1"] = "Hoja de ruta de 90 días — Taller de arquitectura en OCI · Bloque 8"
    wr["A1"].font = f(True, 14, AZUL)
    wr["A2"] = ("Una línea sin dueño, sin fecha o sin métrica con valor objetivo no es un "
                "compromiso: es un deseo. La columna Clasificación lo dice sola, en rojo.")
    wr["A2"].font = f(size=9, color=GRIS, italic=True)

    c = wr.cell(row=3, column=1, value=(
        f'="Seleccionadas: "&COUNTIF({rs("G")},"Sí")&" de 2 permitidas.   ·   '
        f'En paralelo: "&COUNTIF({rs("G")},"En paralelo")&"   ·   '
        f'Líneas sin dueño, sin fecha o sin métrica: "&COUNTIF({rr("M")},"No ejecutable")'))
    c.font = f(True, 11, AZUL)
    wr.merge_cells(start_row=3, start_column=1, end_row=3, end_column=8)

    for j, (nombre, ancho, _) in enumerate(COLUMNAS_RUTA, start=1):
        c = wr.cell(row=5, column=j, value=nombre)
        c.font = f(True, 10, "FFFFFF")
        c.fill = FILL_HEAD
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        c.border = BORDE
        wr.column_dimensions[get_column_letter(j)].width = ancho
    wr.row_dimensions[5].height = 38

    for i in range(R_FIJAS + 4):
        r = R_PRIM + i

        c = wr.cell(row=r, column=1, value=f"L-{i + 1:02d}")
        c.font = f(True)
        c.alignment = Alignment(horizontal="center", vertical="top")
        c.border = BORDE

        # Las seis primeras filas traen el nombre de la iniciativa desde «Selección».
        # Las cuatro últimas quedan libres, por si una iniciativa necesita un cuarto tramo.
        if i < R_FIJAS:
            quien = 1 if i < 3 else 2
            buscar = f'MATCH({quien},{rs("K")},0)'
            c = wr.cell(row=r, column=2,
                        value=f'=IFERROR(INDEX({rs("C")},{buscar}),"")')
            c.font = f(True, 10, AZUL)
            c.fill = FILL_CALC
            wr.cell(row=r, column=3, value=HORIZONTES[i % 3]).font = f()
            wr.cell(row=r, column=3).fill = FILL_INPUT
        else:
            c = wr.cell(row=r, column=2)
            c.fill = FILL_INPUT
        c.alignment = Alignment(vertical="top", wrap_text=True)
        c.border = BORDE

        for j, (_, _, tipo) in enumerate(COLUMNAS_RUTA, start=1):
            if j <= 2:
                continue
            if tipo in ("input", "fecha") or (tipo and tipo.startswith('"')):
                c = wr.cell(row=r, column=j)
                c.fill = FILL_INPUT
                c.border = BORDE
                c.font = f()
                c.alignment = Alignment(vertical="top", wrap_text=True,
                                        horizontal="center" if j in (3, 9, 10, 11, 12) else "left")
                if tipo == "fecha":
                    c.number_format = "dd/mm/yyyy"

        # Clasificación. El orden de las preguntas es el criterio del taller:
        # primero se pregunta si es ejecutable, y solo después qué tan buena es.
        # `[VALIDAR]` es la marca del proyecto para «esto todavía no está
        # verificado», así que en un campo obligatorio cuenta como vacío. Sin esta
        # comprobación, una línea con la métrica o el valor objetivo en [VALIDAR]
        # salía «Ejecutable», que es exactamente lo contrario de lo que significa.
        def pendiente(col):
            return f'OR(${col}{r}="",ISNUMBER(SEARCH("[VALIDAR]",${col}{r})))'

        c = wr.cell(row=r, column=13, value=(
            f'=IF($B{r}="","",'
            f'IF($L{r}="Descartado","Descartada",'
            f'IF(OR({pendiente("E")},{pendiente("K")},{pendiente("H")},{pendiente("J")}),'
            f'"No ejecutable",'
            f'IF($L{r}="En riesgo","En riesgo",'
            f'IF({pendiente("I")},"Sin línea base",'
            f'IF($L{r}<>"Acordado","Por confirmar","Ejecutable"))))))'))
        c.font = f(True)
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        c.border = BORDE

        # Auxiliar para la lista roja de la hoja «Compromiso».
        wr.cell(row=r, column=16,
                value=f'=IF($M{r}="No ejecutable",'
                      f'COUNTIF($M${R_PRIM}:$M{r},"No ejecutable"),"")'
                ).font = f(size=8, color="A6A6A6")
        wr.row_dimensions[r].height = 40

    wr.column_dimensions["P"].hidden = True

    for j, (_, _, tipo) in enumerate(COLUMNAS_RUTA, start=1):
        if tipo and tipo.startswith('"'):
            dv = DataValidation(type="list", formula1=tipo, allow_blank=True)
            wr.add_data_validation(dv)
            letra = get_column_letter(j)
            dv.add(f"{letra}{R_PRIM}:{letra}{R_ULT}")

    dv_fecha = DataValidation(
        type="date", operator="between",
        formula1="DATE(2026,9,15)", formula2="DATE(2027,1,31)",
        allow_blank=True, showErrorMessage=True, errorTitle="Fecha fuera del plan",
        error="La fecha de revisión va entre el la fecha del taller y el 31 de enero "
              "de 2027. Una revisión más allá de eso ya no es esta hoja de ruta.")
    wr.add_data_validation(dv_fecha)
    dv_fecha.add(f"K{R_PRIM}:K{R_ULT}")

    for etiqueta, (fondo, texto) in COLORES_CLASIF.items():
        wr.conditional_formatting.add(
            f"M{R_PRIM}:M{R_ULT}",
            FormulaRule(formula=[f'$M{R_PRIM}="{etiqueta}"'],
                        fill=PatternFill("solid", start_color=fondo),
                        font=Font(name=FUENTE, bold=True, color=texto)))

    # Cada casilla que falta se pinta sola. El veredicto no es una sorpresa al final:
    # se ve mientras se llena, columna por columna.
    for letra in OBLIGATORIAS:
        wr.conditional_formatting.add(
            f"{letra}{R_PRIM}:{letra}{R_ULT}",
            FormulaRule(formula=[f'AND($B{R_PRIM}<>"",${letra}{R_PRIM}="")'],
                        fill=FILL_ALERTA))

    fila = R_ULT + 2
    wr.cell(row=fila, column=1, value=(
        "Las casillas rojas son exactamente lo que falta para que la línea sea un "
        "compromiso: dueño, fecha de revisión, métrica y valor objetivo. Valor de partida "
        "no la bloquea, pero sin él nadie va a poder decir si mejoró.")
        ).font = f(size=9, italic=True, color=GRIS)
    wr.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=10)
    wr.row_dimensions[fila].height = 28

    wr.auto_filter.ref = f"A5:N{R_ULT}"
    wr.freeze_panes = "D6"
    wr.page_setup.orientation = "landscape"
    wr.sheet_properties.pageSetUpPr.fitToPage = True
    wr.page_setup.fitToWidth = 1
    wr.page_setup.fitToHeight = 0
    wr.print_title_rows = "5:5"

    # ============================ COMPROMISO ============================
    wc["A1"] = "El compromiso — se lee en voz alta antes de salir de la sala"
    wc["A1"].font = f(True, 14, AZUL)
    wc["A2"] = ("Todo lo de esta hoja se calcula. Lo único que se escribe son las cuatro "
                "casillas de la siguiente conversación, al final.")
    wc["A2"].font = f(size=9, color=GRIS, italic=True)
    for col, ancho in zip("ABCDEFG", [30, 13, 13, 16, 16, 20, 40]):
        wc.column_dimensions[col].width = ancho

    # --- Las dos iniciativas
    wc["A4"] = "Las dos iniciativas"
    wc["A4"].font = f(True, 11, AZUL)
    cabeza = ["", "Iniciativa", "", "", "Tipo", "Dueño propuesto", "Líneas ejecutables"]
    for j, h in enumerate(cabeza, start=1):
        if h:
            c = wc.cell(row=5, column=j, value=h)
            c.font = f(True, 9, "FFFFFF")
            c.fill = FILL_HEAD
            c.alignment = Alignment(horizontal="center", wrap_text=True)
            c.border = BORDE
    wc.merge_cells(start_row=5, start_column=2, end_row=5, end_column=4)

    for k in (1, 2):
        r = 5 + k
        buscar = f'MATCH({k},{rs("K")},0)'
        c = wc.cell(row=r, column=1, value=f"Iniciativa {k}")
        c.font = f(True, 10)
        c.border = BORDE
        c2 = wc.cell(row=r, column=2,
                     value=f'=IFERROR(INDEX({rs("C")},{buscar}),"— sin seleccionar —")')
        c2.font = f(True, 11, AZUL)
        c2.alignment = Alignment(vertical="center", wrap_text=True)
        c2.border = BORDE
        wc.merge_cells(start_row=r, start_column=2, end_row=r, end_column=4)
        for col, formula in (
                (5, f'=IFERROR(INDEX({rs("D")},{buscar}),"")'),
                (6, f'=IFERROR(INDEX({rs("I")},{buscar}),"")'),
                (7, f'=IF($B{r}="— sin seleccionar —","",'
                    f'COUNTIFS({rr("B")},$B{r},{rr("M")},"Ejecutable"))')):
            c3 = wc.cell(row=r, column=col, value=formula)
            c3.font = f(size=10)
            c3.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
            c3.border = BORDE
        wc.row_dimensions[r].height = 30

    # --- Cuenta de la hoja de ruta
    wc["A9"] = "Cuenta de la hoja de ruta"
    wc["A9"].font = f(True, 11, AZUL)
    kpis = [
        ("Líneas escritas", f'=COUNTIF({rr("B")},"?*")', False, None),
        ("Ejecutables (dueño, fecha y métrica con objetivo)",
         f'=COUNTIF({rr("M")},"Ejecutable")', False, None),
        ("NO EJECUTABLES: deseos, no compromisos",
         f'=COUNTIF({rr("M")},"No ejecutable")', True,
         "Se completan ahora o se borran de la hoja. Dejarlas es la tercera opción, "
         "y no es válida."),
        ("Sin línea base (no se sabrá si mejoró)",
         f'=COUNTIF({rr("M")},"Sin línea base")', False, None),
        ("Por confirmar", f'=COUNTIF({rr("M")},"Por confirmar")', False, None),
        ("En riesgo", f'=COUNTIF({rr("M")},"En riesgo")', False, None),
        ("Líneas en los primeros 30 días",
         f'=COUNTIFS({rr("C")},"{HORIZONTES[0]}",{rr("B")},"?*")', False,
         "Si son cero, el plan empieza dentro de un mes y para entonces nadie se acuerda."),
        ("Personas distintas con algo a su nombre",
         f'=IF(COUNTA({rr("E")})=0,0,'
         f'SUMPRODUCT(({rr("E")}<>"")/COUNTIF({rr("E")},{rr("E")}&"")))', False,
         "Si es 1, no hay un plan: hay una persona con una lista."),
    ]
    for i, (etq, formula, destacar, nota) in enumerate(kpis, start=10):
        c1 = wc.cell(row=i, column=1, value=etq)
        c1.font = f(bold=destacar)
        c1.border = BORDE
        wc.merge_cells(start_row=i, start_column=1, end_row=i, end_column=5)
        c2 = wc.cell(row=i, column=6, value=formula)
        c2.font = f(True, 11, "C00000" if destacar else "000000")
        c2.alignment = Alignment(horizontal="center")
        c2.border = BORDE
        if nota:
            wc.cell(row=i, column=7, value=nota).font = \
                f(size=9, italic=True, color="C00000" if destacar else GRIS)

    fila = 10 + len(kpis) + 1
    c = wc.cell(row=fila, column=1, value=(
        f'=IF(COUNTIF({rr("M")},"No ejecutable")>0,'
        f'"Hay "&COUNTIF({rr("M")},"No ejecutable")&" línea(s) sin dueño, sin fecha o sin '
        f'métrica con valor objetivo. Eso no se puede revisar en 30 días porque no hay quién '
        f'ni cuándo. Se completa ahora, en la sala.",'
        f'IF(COUNTIF({rr("M")},"Ejecutable")=0,'
        f'"Ninguna línea está acordada todavía. La hoja sigue siendo un borrador.",'
        f'"Todas las líneas tienen dueño, fecha y métrica con valor objetivo. Esto se puede '
        f'revisar el día que dice la hoja."))'))
    c.font = f(True, 11)
    c.alignment = Alignment(wrap_text=True, vertical="center")
    wc.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=7)
    wc.row_dimensions[fila].height = 34
    wc.conditional_formatting.add(
        f"A{fila}:G{fila}",
        FormulaRule(formula=[f'COUNTIF({rr("M")},"No ejecutable")>0'], fill=FILL_ALERTA))

    # --- La lista roja: qué le falta a cada línea, con nombre y apellido
    fila += 2
    c = wc.cell(row=fila, column=1, value="Lo que falta, línea por línea")
    c.font = f(True, 11, COLORES_CLASIF["No ejecutable"][1])
    c.fill = PatternFill("solid", start_color=COLORES_CLASIF["No ejecutable"][0])
    wc.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=7)
    fila += 1
    for j, h in enumerate(("N.º", "Línea", "Iniciativa", "", "Horizonte", "Le falta", ""),
                          start=1):
        if h:
            c = wc.cell(row=fila, column=j, value=h)
            c.font = f(True, 9, "FFFFFF")
            c.fill = FILL_HEAD
            c.alignment = Alignment(horizontal="center")
            c.border = BORDE
    wc.merge_cells(start_row=fila, start_column=3, end_row=fila, end_column=4)
    wc.merge_cells(start_row=fila, start_column=6, end_row=fila, end_column=7)
    fila += 1
    for k in range(1, 9):
        buscar = f'MATCH({k},{rr("P")},0)'
        idx = lambda col: f'INDEX({rr(col)},{buscar})'
        wc.cell(row=fila, column=1,
                value=f'=IF(ISNUMBER({buscar}),{k},"")').font = f(size=9)
        wc.cell(row=fila, column=2,
                value=f'=IFERROR({idx("A")},"")').font = f(True, 9)
        c3 = wc.cell(row=fila, column=3, value=f'=IFERROR({idx("B")},"")')
        c3.font = f(size=9)
        c3.alignment = Alignment(wrap_text=True, vertical="center")
        wc.merge_cells(start_row=fila, start_column=3, end_row=fila, end_column=4)
        c5 = wc.cell(row=fila, column=5, value=f'=IFERROR({idx("C")},"")')
        c5.font = f(size=9)
        c5.alignment = Alignment(horizontal="center", vertical="center")
        # El «le falta» se arma solo: la hoja no se limita a reprobar, dice qué corregir.
        c6 = wc.cell(row=fila, column=6, value=(
            f'=IFERROR(MID('
            f'IF({idx("E")}="",", dueño","")&'
            f'IF({idx("K")}="",", fecha de revisión","")&'
            f'IF({idx("H")}="",", métrica de éxito","")&'
            f'IF({idx("J")}="",", valor objetivo","")'
            f',3,200),"")'))
        c6.font = f(True, 9, "9C0006")
        c6.alignment = Alignment(wrap_text=True, vertical="center")
        wc.merge_cells(start_row=fila, start_column=6, end_row=fila, end_column=7)
        for j in range(1, 8):
            wc.cell(row=fila, column=j).border = BORDE
        wc.row_dimensions[fila].height = 24
        fila += 1

    # --- La siguiente conversación
    fila += 1
    wc.cell(row=fila, column=1, value="La siguiente conversación").font = f(True, 11, AZUL)
    fila += 1
    wc.cell(row=fila, column=1, value=(
        "Sin fecha aquí, el plan de 90 días se revisa el día 91 — que es como decir nunca.")
        ).font = f(size=9, italic=True, color=GRIS)
    wc.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=7)
    fila += 1
    for etq in ("Fecha de la primera revisión conjunta",
                "Quién convoca",
                "Qué se revisa (las métricas de la hoja, nada más)",
                "Quién asiste por cada parte"):
        ce = wc.cell(row=fila, column=1, value=etq)
        ce.font = f(True, 10, "FFFFFF")
        ce.fill = FILL_HEAD
        ce.alignment = Alignment(vertical="center", wrap_text=True)
        ce.border = BORDE
        wc.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=3)
        ci = wc.cell(row=fila, column=4)
        ci.fill = FILL_INPUT
        ci.border = BORDE
        ci.alignment = Alignment(vertical="center", wrap_text=True)
        wc.merge_cells(start_row=fila, start_column=4, end_row=fila, end_column=7)
        wc.row_dimensions[fila].height = 26
        fila += 1

    fila += 1
    c = wc.cell(row=fila, column=1, value=(
        "Esta hoja se fotografía antes de salir de la sala y viaja en la memoria del bloque, "
        "dentro de las 48 horas. Es el único documento de la jornada que compromete a alguien "
        "a algo con una fecha."))
    c.font = f(size=9, italic=True, color=GRIS)
    c.alignment = Alignment(wrap_text=True, vertical="top")
    wc.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=7)
    wc.row_dimensions[fila].height = 30

    wc.page_setup.orientation = "portrait"
    wc.sheet_properties.pageSetUpPr.fitToPage = True
    wc.page_setup.fitToWidth = 1
    wc.page_setup.fitToHeight = 0

    # ============================ LEEME ============================
    ws_leeme.column_dimensions["A"].width = 3
    ws_leeme.column_dimensions["B"].width = 30
    ws_leeme.column_dimensions["C"].width = 92
    ws_leeme["B2"] = "Cómo se usa este archivo"
    ws_leeme["B2"].font = f(True, 16, AZUL)
    ws_leeme["B3"] = "Taller de arquitectura en OCI · Bloque 8 · Taller de priorización y hoja de ruta"
    ws_leeme["B3"].font = f(size=10, color=GRIS)

    bloques = [
        ("En la sesión", None),
        ("Minuto 10", "Hoja «Selección». Los candidatos que dejaron los cinco bloques. "
                      "Se marca «Sí» en máximo DOS: una de plataforma y otra de datos/IA. "
                      "La cuenta del final avisa sola si se pasan."),
        ("Minuto 20", "Hoja «Hoja de ruta». Las dos iniciativas ya aparecen solas, con sus "
                      "tres horizontes. Se llena de izquierda a derecha, línea por línea."),
        ("Minuto 40", "Hoja «Compromiso». Ya está todo calculado: se lee en voz alta."),
        ("Minuto 46", "Las cuatro casillas de la siguiente conversación. Con fecha."),
        ("", None),
        ("La regla del bloque", None),
        ("Sin dueño y sin fecha es un deseo",
         "Si una línea no tiene dueño, fecha de revisión o métrica con valor objetivo, la "
         "hoja la declara NO EJECUTABLE en rojo. Hay dos formas de arreglarlo: completarla, "
         "o borrarla de la hoja. Las dos son respuestas válidas; dejarla como está, no."),
        ("Máximo dos",
         "Una de plataforma y otra de datos/IA. No es austeridad: es lo que un equipo puede "
         "empezar de verdad en 90 días. Lo que no entra no se pierde — queda en las memorias "
         "de cada bloque, con su dueño."),
        ("Los quick wins van aparte",
         "Los controles de seguridad de esfuerzo bajo se marcan «En paralelo». Por su costo "
         "no compiten por un lugar entre las dos iniciativas."),
        ("Un dueño es una persona",
         "No un área, no un comité. Si la cuenta de «personas distintas» da 1, no hay un "
         "plan: hay una persona con una lista."),
        ("", None),
        ("Qué se edita", None),
        ("Celdas amarillas", "En «Selección»: tipo, si entra, por qué y dueño propuesto. En "
                             "«Hoja de ruta»: todo salvo la línea, el nombre de la iniciativa "
                             "y la clasificación. En «Compromiso»: solo las cuatro casillas "
                             "del final."),
        ("Celdas azules", "El nombre de la iniciativa se trae de «Selección». Si cambia allá, "
                          "cambia aquí."),
        ("", None),
        ("Después de la sesión", None),
        ("Entrega", "Este archivo va en la memoria del bloque, dentro de las 48 horas, junto "
                    "con las cinco memorias técnicas. La fecha de revisión que quedó escrita "
                    "es el siguiente compromiso de Oracle, no del cliente."),
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
            ws_leeme.row_dimensions[r].height = 44
        r += 1

    wb.active = 1
    wb.save(ruta)


def construir_md():
    lineas = [
        "# Hoja de ruta de 90 días — plantilla",
        "",
        "Versión en Markdown de la salida del bloque 8. **En vivo se usa el Excel**",
        "(`hoja-de-ruta/Hoja_de_Ruta.xlsx`), que cuenta las iniciativas seleccionadas",
        "y marca en rojo toda línea sin dueño, sin fecha o sin métrica con valor objetivo.",
        "Esta versión sirve para imprimir, para dibujarla en el tablero o para pegarla en la",
        "memoria.",
        "",
        "> **El criterio del taller.** Una línea sin dueño y sin fecha es un deseo, no un",
        "> compromiso. La hoja no lo discute: lo declara.",
        "",
        "## Cómo se elige (explicarlo antes de marcar nada, 60 segundos)",
        "",
        "1. Sobre la mesa están las salidas de los cinco bloques técnicos.",
        "2. Se eligen **máximo dos iniciativas**: una de plataforma y otra de datos/IA.",
        "   Es lo que dice la propuesta ejecutiva, y el motivo es preservar foco.",
        "3. Los **quick wins de seguridad** van en paralelo: por su bajo esfuerzo no",
        "   compiten por un lugar.",
        "4. Cada iniciativa se parte en tres horizontes y cada tramo lleva dueño, métrica",
        "   y fecha. **Nada entra sin dueño.**",
        "",
        "## Clasificación (se calcula sola)",
        "",
        "| Clasificación | Cuándo |",
        "|---|---|",
        "| **Ejecutable** | Tiene dueño, fecha de revisión, métrica con valor objetivo y valor de partida |",
        "| **No ejecutable** | Le falta dueño, fecha o métrica con valor objetivo. *Es un deseo* |",
        "| **Sin línea base** | Lo demás está, pero no se sabe de cuánto se parte |",
        "| **En riesgo** | El grupo la marcó así |",
        "| **Por confirmar** | Completa, pero el estado todavía no es «Acordado» |",
        "| **Descartada** | Se sacó del plan en la sala |",
        "",
        "## Candidatos que deja la jornada",
        "",
        "| ID | De dónde viene | Candidato | Tipo | Qué trae ya hecho |",
        "|---|---|---|---|---|",
    ]
    for cid, origen, candidato, tipo, trae, _ in CANDIDATOS:
        lineas.append(f"| **{cid}** | {origen} | {candidato} | {tipo or '—'} | {trae} |")
    lineas += [
        "",
        "**Precondiciones que conviene decir en voz alta:**",
        "",
    ]
    for cid, _, candidato, _, _, precondicion in CANDIDATOS:
        lineas.append(f"- **{cid}** ({candidato}): {precondicion}")
    lineas += [
        "",
        "## Selección (se llena en la sesión)",
        "",
        "| # | Iniciativa | Tipo | Por qué esta | Dueño |",
        "|---|---|---|---|---|",
        "| 1 | | Plataforma | | |",
        "| 2 | | Datos/IA | | |",
        "",
        "**En paralelo (no compiten):** ___",
        "",
        "## Hoja de ruta",
        "",
        "Columnas del Excel, en el mismo orden:",
        "",
        "| " + " | ".join(c[0] for c in COLUMNAS_RUTA) + " |",
        "|" + "---|" * len(COLUMNAS_RUTA),
    ]
    for k in (1, 2):
        for h in HORIZONTES:
            celdas = [""] * len(COLUMNAS_RUTA)
            celdas[0] = f"L-{(k - 1) * 3 + HORIZONTES.index(h) + 1:02d}"
            celdas[1] = f"Iniciativa {k}"
            celdas[2] = h
            lineas.append("| " + " | ".join(celdas) + " |")
    lineas += [
        "",
        "## La siguiente conversación",
        "",
        "| | |",
        "|---|---|",
        "| **Fecha de la primera revisión conjunta** | |",
        "| **Quién convoca** | |",
        "| **Qué se revisa** | Las métricas de esta hoja, nada más |",
        "| **Quién asiste por cada parte** | |",
        "",
        "> Sin fecha aquí, el plan de 90 días se revisa el día 91 — que es como decir nunca.",
        "",
    ]
    (AQUI / "HOJA-DE-RUTA.md").write_text("\n".join(lineas),
                                                             encoding="utf-8")


if __name__ == "__main__":
    ids = [c[0] for c in CANDIDATOS]
    assert len(ids) == len(set(ids)), "IDs duplicados"
    assert len(HORIZONTES) == 3, "La hoja de ruta se arma con tres horizontes"
    tipos = {c[3] for c in CANDIDATOS if c[3]}
    assert tipos <= {"Plataforma", "Datos/IA", "Transversal"}, f"tipo desconocido: {tipos}"
    construir_xlsx(AQUI / "Hoja_de_Ruta.xlsx")
    construir_md()
    print(f"Generado: {len(CANDIDATOS)} candidatos, "
          f"2 iniciativas x {len(HORIZONTES)} horizontes.")
