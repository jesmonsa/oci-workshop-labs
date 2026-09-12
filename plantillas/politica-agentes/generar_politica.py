"""
Genera la salida formal del módulo 6 desde una única fuente de datos:

  - Politica_Agentes.xlsx  -> se proyecta y se llena EN VIVO.
      · Hoja «Servidores»: qué servidor MCP, con qué madurez, contra qué ambiente.
      · Hoja «Resultado»: lo prohibido, lo pendiente de aprobar y la política final.
  - POLITICA.md            -> la misma plantilla en Markdown.

    python generar_politica.py
Después abrir el Excel y guardarlo una vez para que calcule.

La mecánica que se explica en la sala:

    Un servidor MCP es una lista de cosas que un agente va a poder hacer contra un
    sistema tuyo. La pregunta no es si el agente es confiable: es qué permisos tiene
    la conexión que usa, en qué ambiente, y quién autorizó ampliarlos.

    La hoja marca sola, en rojo, dos combinaciones que no deberían existir:
    una prueba de concepto apuntando a producción, y una herramienta que escribe
    sin nadie que apruebe.
"""

from pathlib import Path

from openpyxl import Workbook
from openpyxl.formatting.rule import FormulaRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

AQUI = Path(__file__).parent

# Servidores candidatos. La columna de madurez viene precargada porque es el dato
# que más cuesta averiguar y el que más decisiones cambia — pero se verifica antes
# de cada taller: este ecosistema se mueve rápido y lo que hoy es prueba de
# concepto puede ser producto en seis meses.
SERVIDORES = [
    ("MCP-01", "SQLcl (servidor MCP local)",
     "Cinco herramientas sobre una conexión guardada: listar conexiones, conectar, "
     "desconectar, ejecutar SQL y ejecutar comandos de SQLcl.",
     "Producto", "Sí"),
    ("MCP-02", "Servidor MCP gestionado de base de datos en la nube",
     "Acceso a bases de datos por HTTPS con identidad de la nube y catálogos de "
     "herramientas gobernados.",
     "Producto", "Sí"),
    ("MCP-03", "Punto de acceso MCP incorporado en el servicio de datos REST",
     "Alternativa por HTTPS sin proceso local.",
     "Producto", "Sí"),
    ("MCP-04", "Servidor MCP de infraestructura (uso general)",
     "Decenas de herramientas para consultar y administrar recursos del tenancy.",
     "Prueba de concepto", "Sí"),
    ("MCP-05", "Servidor MCP de operación de infraestructura",
     "Aprovisionar, administrar, monitorear y asegurar recursos por conversación.",
     "Prueba de concepto", "Sí"),
    ("MCP-06", "Servidor MCP de recuperación ante desastres",
     "Consulta y operación de planes de recuperación.",
     "Prueba de concepto", "Sí"),
    ("MCP-07", "Agente propio con catálogo cerrado de solo lectura",
     "Construido en casa, con un catálogo acotado y un validador determinista.",
     "Propio", "No"),
    ("MCP-08", "Agent Skills (conocimiento, no herramientas)",
     "No expone herramientas ni ejecuta nada: aporta documentación de referencia "
     "al agente de código.",
     "Producto", "No"),
]

COLUMNAS = [
    ("ID", 8, None),
    ("Servidor o componente", 34, None),
    ("Qué expone", 46, None),
    ("Madurez declarada", 17, '"Producto,Preview,Prueba de concepto,Propio,No sé"'),
    ("¿Puede escribir?", 13, '"Sí,No,No sé"'),
    ("¿Lo vamos a usar?", 15, '"Sí,No,Todavía no"'),
    ("Ambiente permitido", 18, '"Ninguno,Solo local,Desarrollo,Pruebas,Producción"'),
    ("Usuario o identidad", 22, "input"),
    ("Nivel de restricción", 16, "input"),
    ("¿Queda registro?", 14, '"Sí,Parcial,No,No sé"'),
    ("Quién aprueba ampliar", 22, "input"),
    ("Estado", 20, "formula"),
    ("Notas", 26, "input"),
]

FUENTE, AZUL, GRIS = "Arial", "1F3864", "595959"
FILL_HEAD = PatternFill("solid", start_color=AZUL)
FILL_INPUT = PatternFill("solid", start_color="FFF2CC")
BORDE = Border(*(Side(style="thin", color="BFBFBF"),) * 4)

COLORES_ESTADO = {
    "Aprobado": ("C6EFCE", "006100"),
    "NO PERMITIDO": ("FFC7CE", "9C0006"),
    "Falta aprobador": ("FFEB9C", "7F6000"),
    "Falta decidir": ("BDD7EE", "1F3864"),
}


def f(bold=False, size=10, color="000000", italic=False):
    return Font(name=FUENTE, bold=bold, size=size, color=color, italic=italic)


def construir_xlsx(ruta):
    wb = Workbook()
    ws_leeme = wb.active
    ws_leeme.title = "Leeme"
    ws = wb.create_sheet("Servidores")
    wr = wb.create_sheet("Resultado")

    n = len(SERVIDORES)
    PRIMERA, ULTIMA = 5, 5 + n - 1 + 3
    rango = lambda col: f"Servidores!${col}${PRIMERA}:${col}${ULTIMA}"

    # ============================ SERVIDORES ============================
    ws["A1"] = "Política de adopción de agentes — Módulo 6"
    ws["A1"].font = f(True, 14, AZUL)
    ws["A2"] = ("Un servidor MCP es la lista de lo que un agente podrá hacer contra un "
                "sistema tuyo. La columna Estado se calcula sola.")
    ws["A2"].font = f(size=9, color=GRIS, italic=True)

    for j, (nombre, ancho, _) in enumerate(COLUMNAS, start=1):
        c = ws.cell(row=4, column=j, value=nombre)
        c.font = f(True, 10, "FFFFFF")
        c.fill = FILL_HEAD
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        c.border = BORDE
        ws.column_dimensions[get_column_letter(j)].width = ancho
    ws.row_dimensions[4].height = 36

    for i in range(n + 3):
        r = PRIMERA + i
        datos = SERVIDORES[i] if i < n else ("", "", "", "", "")
        for j, v in enumerate(datos, start=1):
            c = ws.cell(row=r, column=j, value=v)
            c.font = f(bold=(j == 1))
            c.alignment = Alignment(vertical="top", wrap_text=True,
                                    horizontal="center" if j in (1, 4, 5) else "left")
            c.border = BORDE
        for j, (_, _, tipo) in enumerate(COLUMNAS, start=1):
            if tipo == "input" or (tipo and tipo.startswith('"')):
                c = ws.cell(row=r, column=j)
                c.fill = FILL_INPUT
                c.border = BORDE
                c.font = f()
                c.alignment = Alignment(vertical="top", wrap_text=True,
                                        horizontal="center" if j in (4, 5, 6, 7, 10) else "left")

        # Estado. Dos combinaciones se marcan como no permitidas, y son el contenido
        # del ejercicio: una prueba de concepto contra producción, y algo que escribe
        # sin que nadie apruebe ampliarlo.
        ws.cell(row=r, column=12, value=(
            f'=IF($B{r}="","",'
            f'IF($F{r}="No","Descartado",'
            f'IF(OR($F{r}="",$G{r}=""),"Falta decidir",'
            f'IF(AND(OR($D{r}="Prueba de concepto",$D{r}="Preview",$D{r}="No sé"),'
            f'$G{r}="Producción"),"NO PERMITIDO",'
            f'IF(AND($E{r}="Sí",$K{r}=""),"Falta aprobador",'
            f'IF(AND($E{r}="Sí",$H{r}=""),"Falta aprobador",'
            f'"Aprobado"))))))')).font = f(True)
        ws.cell(row=r, column=12).alignment = Alignment(horizontal="center", vertical="top")
        ws.cell(row=r, column=12).border = BORDE

        for col, etiqueta in ((15, "NO PERMITIDO"), (16, "Falta aprobador")):
            ws.cell(row=r, column=col,
                    value=f'=IF($L{r}="{etiqueta}",COUNTIF($L${PRIMERA}:$L{r},"{etiqueta}"),"")'
                    ).font = f(size=8, color="A6A6A6")
        ws.row_dimensions[r].height = 46

    for col in ("O", "P"):
        ws.column_dimensions[col].hidden = True

    for j, (_, _, tipo) in enumerate(COLUMNAS, start=1):
        if tipo and tipo.startswith('"'):
            dv = DataValidation(type="list", formula1=tipo, allow_blank=True)
            ws.add_data_validation(dv)
            letra = get_column_letter(j)
            dv.add(f"{letra}{PRIMERA}:{letra}{ULTIMA}")

    for etiqueta, (fondo, texto) in COLORES_ESTADO.items():
        ws.conditional_formatting.add(
            f"L{PRIMERA}:L{ULTIMA}",
            FormulaRule(formula=[f'$L{PRIMERA}="{etiqueta}"'],
                        fill=PatternFill("solid", start_color=fondo),
                        font=Font(name=FUENTE, bold=True, color=texto)))
    # La madurez también se resalta: es el dato que más decisiones cambia.
    ws.conditional_formatting.add(
        f"D{PRIMERA}:D{ULTIMA}",
        FormulaRule(formula=[f'OR($D{PRIMERA}="Prueba de concepto",$D{PRIMERA}="Preview")'],
                    fill=PatternFill("solid", start_color="FFF2CC")))

    ws.auto_filter.ref = f"A4:M{ULTIMA}"
    ws.freeze_panes = "D5"
    ws.page_setup.orientation = "landscape"
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0

    # ============================ RESULTADO ============================
    wr["A1"] = "Política de adopción — se arma sola"
    wr["A1"].font = f(True, 14, AZUL)
    for col, ancho in zip("ABCDEFG", [30, 14, 14, 14, 14, 20, 30]):
        wr.column_dimensions[col].width = ancho

    wr["A3"] = "Indicador"
    wr["B3"] = "Valor"
    for c in (wr["A3"], wr["B3"]):
        c.font = f(True, 10, "FFFFFF")
        c.fill = FILL_HEAD
        c.border = BORDE

    kpis = [
        ("Componentes evaluados", f'=COUNTA({rango("B")})'),
        ("Aprobados", f'=COUNTIF({rango("L")},"Aprobado")'),
        ("NO PERMITIDOS", f'=COUNTIF({rango("L")},"NO PERMITIDO")'),
        ("Falta aprobador", f'=COUNTIF({rango("L")},"Falta aprobador")'),
        ("Falta decidir", f'=COUNTIF({rango("L")},"Falta decidir")'),
        ("Descartados", f'=COUNTIF({rango("L")},"Descartado")'),
        ("Que pueden escribir y se van a usar",
         f'=COUNTIFS({rango("E")},"Sí",{rango("F")},"Sí")'),
    ]
    for i, (etq, fo) in enumerate(kpis, start=4):
        c1 = wr.cell(row=i, column=1, value=etq)
        c1.font = f(bold=(etq == "NO PERMITIDOS"))
        c1.border = BORDE
        c2 = wr.cell(row=i, column=2, value=fo)
        c2.font = f(True, 11, "C00000" if etq in ("NO PERMITIDOS", "Que pueden escribir y se van a usar") else "000000")
        c2.alignment = Alignment(horizontal="center")
        c2.border = BORDE

    wr.cell(row=6, column=3,
            value="Si no es cero, ahí está la conversación: una prueba de concepto "
                  "apuntando a producción.").font = f(size=9, italic=True, color="C00000")
    wr.cell(row=10, column=3,
            value="Cada uno de estos necesita un aprobador con nombre y un ambiente "
                  "acotado.").font = f(size=9, italic=True, color=GRIS)

    fila = 13
    for titulo, aux, filas_n, etiqueta in (
            ("NO PERMITIDOS — madurez insuficiente para el ambiente elegido", "O", 5, "NO PERMITIDO"),
            ("FALTA APROBADOR O IDENTIDAD — escriben sin dueño definido", "P", 6, "Falta aprobador")):
        c = wr.cell(row=fila, column=1, value=titulo)
        c.font = f(True, 11, COLORES_ESTADO[etiqueta][1])
        c.fill = PatternFill("solid", start_color=COLORES_ESTADO[etiqueta][0])
        wr.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=7)
        fila += 1
        for j, h in enumerate(("N.º", "ID", "Componente", "", "", "Ambiente", "Qué hacer"), start=1):
            if h:
                cc = wr.cell(row=fila, column=j, value=h)
                cc.font = f(True, 9, "FFFFFF")
                cc.fill = FILL_HEAD
        wr.merge_cells(start_row=fila, start_column=3, end_row=fila, end_column=5)
        fila += 1
        for k in range(1, filas_n + 1):
            buscar = f"MATCH({k},Servidores!${aux}${PRIMERA}:${aux}${ULTIMA},0)"
            wr.cell(row=fila, column=1, value=f'=IF(ISNUMBER({buscar}),{k},"")').font = f(size=9)
            wr.cell(row=fila, column=2,
                    value=f'=IFERROR(INDEX(Servidores!$A${PRIMERA}:$A${ULTIMA},{buscar}),"")'
                    ).font = f(True, 9)
            c3 = wr.cell(row=fila, column=3,
                         value=f'=IFERROR(INDEX(Servidores!$B${PRIMERA}:$B${ULTIMA},{buscar}),"")')
            c3.font = f(size=9)
            c3.alignment = Alignment(wrap_text=True, vertical="top")
            wr.merge_cells(start_row=fila, start_column=3, end_row=fila, end_column=5)
            wr.cell(row=fila, column=6,
                    value=f'=IFERROR(INDEX(Servidores!$G${PRIMERA}:$G${ULTIMA},{buscar}),"")'
                    ).font = f(size=9)
            c7 = wr.cell(row=fila, column=7)
            c7.fill = FILL_INPUT
            c7.border = BORDE
            wr.row_dimensions[fila].height = 24
            fila += 1
        fila += 1

    # Política por ambiente: la conclusión que se lleva el cliente.
    wr.cell(row=fila, column=1, value="La política, en una frase por ambiente").font = f(True, 11, AZUL)
    fila += 1
    for j, h in enumerate(("Ambiente", "Qué se permite", "", "", "", "Identidad", "Quién aprueba"), start=1):
        if h:
            c = wr.cell(row=fila, column=j, value=h)
            c.font = f(True, 9, "FFFFFF")
            c.fill = FILL_HEAD
    wr.merge_cells(start_row=fila, start_column=2, end_row=fila, end_column=5)
    fila += 1
    for ambiente in ("Equipo local", "Desarrollo", "Pruebas", "Producción"):
        wr.cell(row=fila, column=1, value=ambiente).font = f(True, 9)
        wr.cell(row=fila, column=1).border = BORDE
        for j in (2, 6, 7):
            c = wr.cell(row=fila, column=j)
            c.fill = FILL_INPUT
            c.border = BORDE
        wr.merge_cells(start_row=fila, start_column=2, end_row=fila, end_column=5)
        wr.row_dimensions[fila].height = 30
        fila += 1

    wr.page_setup.orientation = "portrait"
    wr.sheet_properties.pageSetUpPr.fitToPage = True
    wr.page_setup.fitToWidth = 1
    wr.page_setup.fitToHeight = 0

    # ============================ LEEME ============================
    ws_leeme.column_dimensions["A"].width = 3
    ws_leeme.column_dimensions["B"].width = 32
    ws_leeme.column_dimensions["C"].width = 92
    ws_leeme["B2"] = "Cómo se usa este archivo"
    ws_leeme["B2"].font = f(True, 16, AZUL)
    ws_leeme["B3"] = "Módulo 6 · Agentes sobre Oracle: MCP y Agent Skills"
    ws_leeme["B3"].font = f(size=10, color=GRIS)

    bloques = [
        ("En la sesión", None),
        ("Minuto 26", "Hoja «Servidores». Se recorre componente por componente. La lista "
                      "viene precargada; se quita lo que no aplique y se agrega lo propio."),
        ("Por cada uno", "¿Lo vamos a usar? · ¿en qué ambiente? · ¿con qué usuario? · "
                         "¿con qué nivel de restricción? · ¿queda registro? · ¿quién aprueba ampliarlo?"),
        ("Minuto 36", "Hoja «Resultado». Las dos listas ya están armadas y la política por "
                      "ambiente se escribe en cuatro frases."),
        ("", None),
        ("Las dos reglas que la hoja aplica sola", None),
        ("Prueba de concepto + Producción", "→ NO PERMITIDO. No es una opinión sobre la "
         "calidad del software: es que su propio autor dice que no es para producción. "
         "Si alguien quiere usarlo igual, la conversación es con esa frase encima de la mesa."),
        ("Escribe + sin aprobador o sin identidad", "→ falta un nombre. Una herramienta que "
         "puede modificar algo necesita saber con qué usuario lo hace y quién autoriza "
         "ampliar su alcance."),
        ("", None),
        ("La pregunta que más cambia la conversación", None),
        ("¿Con qué usuario conecta?", "El nivel de restricción del servidor limita a la "
         "herramienta, no a la base de datos. Si la conexión guardada es administradora, "
         "el agente tiene permisos de administrador — por muy cerrado que esté el nivel. "
         "El control que de verdad acota el daño es el permiso."),
        ("", None),
        ("Qué se edita", None),
        ("Celdas amarillas", "Todo lo demás se calcula."),
        ("", None),
        ("Antes de usarlo", None),
        ("Verificar la madurez", "La columna «Madurez declarada» viene precargada, pero este "
         "ecosistema se mueve rápido: lo que hoy es prueba de concepto puede ser producto en "
         "seis meses. Se comprueba en la documentación del proveedor antes de cada sesión."),
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
            ws_leeme.row_dimensions[r].height = 46
        r += 1

    wb.active = 1
    wb.save(ruta)


def construir_md():
    filas = "\n".join(
        f"| **{sid}** | {nombre} | {expone} | {madurez} | {escribe} |"
        for sid, nombre, expone, madurez, escribe in SERVIDORES)
    (AQUI / "POLITICA.md").write_text(f"""# Política de adopción de agentes — plantilla

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
{filas}

> **La columna de madurez se verifica antes de cada sesión.** Este ecosistema se
> mueve rápido y lo que hoy es una prueba de concepto puede ser producto en seis meses.

## Lo que se llena en vivo

¿Lo vamos a usar? · Ambiente permitido · **Usuario o identidad** · Nivel de restricción ·
¿Queda registro? · **Quién aprueba ampliar** · Notas.

Las dos columnas en negrita son las que convierten una herramienta en una decisión.

## La política final

Cuatro frases, una por ambiente: equipo local, desarrollo, pruebas y producción.
Si las cuatro dicen lo mismo, no es una política: es una ilusión.
""", encoding="utf-8")


if __name__ == "__main__":
    ids = [s[0] for s in SERVIDORES]
    assert len(ids) == len(set(ids)), "IDs duplicados"
    construir_xlsx(AQUI / "Politica_Agentes.xlsx")
    construir_md()
    print(f"Generado: {len(SERVIDORES)} componentes candidatos.")
