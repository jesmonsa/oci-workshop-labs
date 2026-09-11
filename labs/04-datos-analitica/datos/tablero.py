#!/usr/bin/env python3
"""
Genera el tablero operacional a partir de resultados.json.

    python tablero.py --entrada resultados.json --salida tablero.html

Un solo archivo HTML, sin dependencias externas, sin llamadas a internet: se abre
con doble clic y funciona sin red. Eso importa por dos razones — se puede proyectar
aunque la sala no tenga wifi, y es el patrón de **analítica embebida**: un tablero
que se incrusta dentro de un producto sin arrastrar una plataforma de BI detrás.

Ese es el mensaje comercial del bloque: esto no es un tablero para la organización, es una
capacidad que la organización le puede vender a sus clientes.
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import sys
from pathlib import Path

# Paleta validada con el verificador de la guía de visualización: los dos tonos
# pasan todas las verificaciones (banda de luminosidad, croma, separación para
# daltonismo y contraste) en modo claro y oscuro.
SERIE_1 = "var(--serie-1)"   # azul  — volumen, p50
SERIE_2 = "var(--serie-2)"   # naranja — tasas, p95

CSS = """
:root {
  color-scheme: light;
  --plano: #f9f9f7;  --superficie: #fcfcfb;
  --tinta: #0b0b0b;  --tinta-2: #52514e;  --tinta-3: #898781;
  --rejilla: #e1e0d9; --eje: #c3c2b7; --borde: rgba(11,11,11,0.10);
  --serie-1: #2a78d6; --serie-2: #eb6834;
  --critico: #d03b3b; --alerta: #fab219; --bien: #0ca30c;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    color-scheme: dark;
    --plano: #0d0d0d; --superficie: #1a1a19;
    --tinta: #ffffff; --tinta-2: #c3c2b7; --tinta-3: #898781;
    --rejilla: #2c2c2a; --eje: #383835; --borde: rgba(255,255,255,0.10);
    --serie-1: #3987e5; --serie-2: #d95926;
  }
}
:root[data-theme="dark"] {
  color-scheme: dark;
  --plano: #0d0d0d; --superficie: #1a1a19;
  --tinta: #ffffff; --tinta-2: #c3c2b7; --tinta-3: #898781;
  --rejilla: #2c2c2a; --eje: #383835; --borde: rgba(255,255,255,0.10);
  --serie-1: #3987e5; --serie-2: #d95926;
}
* { box-sizing: border-box; }
body {
  margin: 0; padding: 28px 24px 48px;
  background: var(--plano); color: var(--tinta);
  font: 14px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif;
}
.contenedor { max-width: 1180px; margin: 0 auto; }
header { margin-bottom: 22px; }
h1 { font-size: 21px; margin: 0 0 4px; letter-spacing: -0.01em; }
.sub { color: var(--tinta-2); font-size: 13px; }
.aviso {
  margin-top: 12px; padding: 9px 12px; font-size: 12px; color: var(--tinta-2);
  background: var(--superficie); border: 1px solid var(--borde);
  border-left: 3px solid var(--alerta); border-radius: 4px;
}
.rejilla { display: grid; gap: 16px; grid-template-columns: repeat(12, 1fr); }
.tarjeta {
  background: var(--superficie); border: 1px solid var(--borde);
  border-radius: 8px; padding: 16px 18px; min-width: 0;
}
.c3 { grid-column: span 3; } .c4 { grid-column: span 4; }
.c6 { grid-column: span 6; } .c8 { grid-column: span 8; } .c12 { grid-column: span 12; }
@media (max-width: 880px) {
  .c3 { grid-column: span 6; } .c4, .c6, .c8 { grid-column: span 12; }
}
.kpi-etiqueta { font-size: 12px; color: var(--tinta-2); margin-bottom: 6px; }
.kpi-valor { font-size: 30px; font-weight: 600; letter-spacing: -0.02em; line-height: 1.1; }
.kpi-nota { font-size: 11.5px; color: var(--tinta-3); margin-top: 5px; }
h2 { font-size: 14px; margin: 0 0 2px; font-weight: 600; }
.pie-grafico { font-size: 11.5px; color: var(--tinta-3); margin: 10px 0 0; }
.leyenda { display: flex; gap: 14px; font-size: 12px; color: var(--tinta-2); margin: 0 0 6px; }
.leyenda span { display: inline-flex; align-items: center; gap: 6px; }
.punto { width: 9px; height: 9px; border-radius: 2px; display: inline-block; }
svg { display: block; width: 100%; height: auto; overflow: visible; }
.eje-txt { font-size: 10.5px; fill: var(--tinta-3); }
.etiq-dato { font-size: 11px; fill: var(--tinta-2); font-weight: 600; }
table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
th {
  text-align: left; font-weight: 600; color: var(--tinta-2); font-size: 11.5px;
  text-transform: uppercase; letter-spacing: 0.03em;
  padding: 0 10px 7px 0; border-bottom: 1px solid var(--eje);
}
td { padding: 7px 10px 7px 0; border-bottom: 1px solid var(--rejilla); font-variant-numeric: tabular-nums; }
td.num, th.num { text-align: right; }
.marca { font-weight: 600; color: var(--critico); }
.desplaza { overflow-x: auto; }
#globo {
  position: fixed; pointer-events: none; opacity: 0; transition: opacity .12s;
  background: var(--tinta); color: var(--plano); font-size: 12px;
  padding: 6px 9px; border-radius: 5px; white-space: nowrap; z-index: 9;
}
footer { margin-top: 26px; font-size: 11.5px; color: var(--tinta-3); }
"""

JS = """
const globo = document.getElementById('globo');
document.querySelectorAll('[data-info]').forEach(el => {
  el.addEventListener('mouseenter', e => {
    globo.textContent = el.dataset.info;
    globo.style.opacity = 1;
  });
  el.addEventListener('mousemove', e => {
    globo.style.left = Math.min(e.clientX + 14, innerWidth - globo.offsetWidth - 8) + 'px';
    globo.style.top = (e.clientY - 34) + 'px';
  });
  el.addEventListener('mouseleave', () => { globo.style.opacity = 0; });
});
"""


def e(t) -> str:
    return html.escape(str(t), quote=True)


def miles(n) -> str:
    return f"{int(n):,}".replace(",", ".")


# --- Gráficos ----------------------------------------------------------------

def grafico_linea(puntos: list[tuple[str, float]], color: str, unidad: str = "",
                  decimales: int = 0, alto: int = 168) -> str:
    """Una serie, un eje. Nunca dos escalas en el mismo gráfico."""
    if not puntos:
        return '<p class="pie-grafico">Sin datos.</p>'
    ancho, izq, der, arriba, abajo = 720, 44, 14, 12, 26
    ax, ay = ancho - izq - der, alto - arriba - abajo
    valores = [v for _, v in puntos]
    vmax, vmin = max(valores), min(valores)
    if vmax == vmin:
        vmax, vmin = vmax + 1, max(0, vmin - 1)
    holgura = (vmax - vmin) * 0.12
    tope, piso = vmax + holgura, max(0, vmin - holgura)

    def cx(i): return izq + (ax * i / max(len(puntos) - 1, 1))
    def cy(v): return arriba + ay - ay * (v - piso) / (tope - piso)

    partes = []
    for k in range(4):
        v = piso + (tope - piso) * k / 3
        y = cy(v)
        partes.append(f'<line x1="{izq}" y1="{y:.1f}" x2="{izq+ax}" y2="{y:.1f}" '
                      f'stroke="var(--rejilla)" stroke-width="1"/>')
        partes.append(f'<text class="eje-txt" x="{izq-8}" y="{y+3.5:.1f}" text-anchor="end">'
                      f'{v:,.{decimales}f}</text>'.replace(",", "."))

    d = " ".join(f"{'M' if i == 0 else 'L'}{cx(i):.1f},{cy(v):.1f}"
                 for i, (_, v) in enumerate(puntos))
    partes.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="2" '
                  f'stroke-linejoin="round" stroke-linecap="round"/>')

    # Etiquetas directas, selectivas: solo el máximo y el último punto.
    i_max = valores.index(vmax)
    destacados = {i_max, len(puntos) - 1}
    for i, (etq, v) in enumerate(puntos):
        radio = 4 if i in destacados else 3
        partes.append(
            f'<circle cx="{cx(i):.1f}" cy="{cy(v):.1f}" r="{radio}" fill="{color}" '
            f'stroke="var(--superficie)" stroke-width="2" '
            f'data-info="{e(etq)}: {v:,.{decimales}f}{e(unidad)}" style="pointer-events:all"/>'
            .replace(",", "."))
        if i in destacados:
            ancla = "end" if i == len(puntos) - 1 else "middle"
            dx = -6 if i == len(puntos) - 1 else 0
            partes.append(f'<text class="etiq-dato" x="{cx(i)+dx:.1f}" y="{cy(v)-10:.1f}" '
                          f'text-anchor="{ancla}">{v:,.{decimales}f}{e(unidad)}</text>'
                          .replace(",", "."))

    for i in (0, len(puntos) // 2, len(puntos) - 1):
        partes.append(f'<text class="eje-txt" x="{cx(i):.1f}" y="{alto-8}" '
                      f'text-anchor="middle">{e(puntos[i][0][5:])}</text>')

    return (f'<svg viewBox="0 0 {ancho} {alto}" role="img" '
            f'aria-label="Serie de {len(puntos)} puntos">{"".join(partes)}</svg>')


def grafico_barras(filas: list[tuple[str, float]], color: str, unidad: str = "",
                   decimales: int = 0) -> str:
    """Barras horizontales: magnitud por categoría, una sola serie."""
    if not filas:
        return '<p class="pie-grafico">Sin datos.</p>'
    ancho, izq, alto_barra, sep = 720, 210, 20, 12
    alto = len(filas) * (alto_barra + sep) + 8
    vmax = max(v for _, v in filas) or 1
    disponible = ancho - izq - 74
    partes = []
    for i, (etq, v) in enumerate(filas):
        y = i * (alto_barra + sep)
        largo = max(2, disponible * v / vmax)
        partes.append(f'<text class="eje-txt" x="{izq-10}" y="{y+alto_barra*0.72:.0f}" '
                      f'text-anchor="end" fill="var(--tinta-2)">{e(etq)}</text>')
        partes.append(
            f'<rect x="{izq}" y="{y}" width="{largo:.1f}" height="{alto_barra}" rx="4" '
            f'fill="{color}" data-info="{e(etq)}: {v:,.{decimales}f}{e(unidad)}" '
            f'style="pointer-events:all"/>'.replace(",", "."))
        partes.append(f'<text class="etiq-dato" x="{izq+largo+8:.1f}" '
                      f'y="{y+alto_barra*0.72:.0f}">{v:,.{decimales}f}{e(unidad)}</text>'
                      .replace(",", "."))
    return (f'<svg viewBox="0 0 {ancho} {alto}" role="img" '
            f'aria-label="{len(filas)} categorías">{"".join(partes)}</svg>')


def grafico_barras_pares(filas: list[tuple[str, float, float]], unidad: str = "") -> str:
    """Dos series comparables, MISMA unidad y MISMO eje (p50 y p95 en minutos)."""
    if not filas:
        return '<p class="pie-grafico">Sin datos.</p>'
    ancho, izq, alto_barra, sep_par, sep_grupo = 720, 110, 17, 2, 16
    alto = len(filas) * (alto_barra * 2 + sep_par + sep_grupo)
    vmax = max(max(a, b) for _, a, b in filas) or 1
    disponible = ancho - izq - 78
    partes = []
    for i, (etq, p50, p95) in enumerate(filas):
        y = i * (alto_barra * 2 + sep_par + sep_grupo)
        partes.append(f'<text class="eje-txt" x="{izq-10}" y="{y+alto_barra+2:.0f}" '
                      f'text-anchor="end" fill="var(--tinta-2)">{e(etq)}</text>')
        for k, (v, color, nombre) in enumerate(((p50, SERIE_1, "p50"), (p95, SERIE_2, "p95"))):
            yy = y + k * (alto_barra + sep_par)
            largo = max(2, disponible * v / vmax)
            partes.append(
                f'<rect x="{izq}" y="{yy}" width="{largo:.1f}" height="{alto_barra}" rx="4" '
                f'fill="{color}" data-info="{e(etq)} · {nombre}: {v:,.0f}{e(unidad)}" '
                f'style="pointer-events:all"/>'.replace(",", "."))
            partes.append(f'<text class="etiq-dato" x="{izq+largo+8:.1f}" '
                          f'y="{yy+alto_barra*0.75:.0f}">{v:,.0f}{e(unidad)}</text>'
                          .replace(",", "."))
    return (f'<svg viewBox="0 0 {ancho} {alto}" role="img" '
            f'aria-label="p50 y p95 por canal">{"".join(partes)}</svg>')


def tabla(columnas: list[str], filas: list[list], numericas: set[int],
          marcar: int | None = None) -> str:
    if not filas:
        return '<p class="pie-grafico">Sin datos. Que a veces es la mejor noticia.</p>'
    th = "".join(f'<th class="{"num" if i in numericas else ""}">{e(c)}</th>'
                 for i, c in enumerate(columnas))
    cuerpo = []
    for j, fila in enumerate(filas):
        tds = "".join(
            f'<td class="{"num " if i in numericas else ""}'
            f'{"marca" if (marcar is not None and j == 0 and i == marcar) else ""}">{e(v)}</td>'
            for i, v in enumerate(fila))
        cuerpo.append(f"<tr>{tds}</tr>")
    return (f'<div class="desplaza"><table><thead><tr>{th}</tr></thead>'
            f'<tbody>{"".join(cuerpo)}</tbody></table></div>')


# --- Ensamblado --------------------------------------------------------------

def construir(datos: dict) -> str:
    k = datos["kpis"]
    diario = [(f["dia"], f["emitidos"]) for f in datos["volumen_diario"]]
    tasas = [(f["dia"], f["tasa_rechazo"]) for f in datos["tasa_rechazo_diaria"]]
    motivos = [(f["motivo"], f["rechazados"]) for f in datos["motivos_rechazo"][:7]]
    canales = [(f["canal"], f["p50_min"], f["p95_min"]) for f in datos["percentiles_por_canal"]]

    riesgo = tabla(
        ["Cliente", "Rechazo 7 días", "Antes", "Documentos 7 días"],
        [[f'cliente_{f["cliente_id"]}', f'{f["rechazo_7d"]} %',
          f'{f["rechazo_previo"]} %', miles(f["documentos_7d"])]
         for f in datos["clientes_en_riesgo"][:6]],
        {1, 2, 3}, marcar=1)

    atascados = tabla(
        ["Cliente", "Canal", "Detenidos", "El más viejo"],
        [[f'cliente_{f["cliente_id"]}', f["canal"], miles(f["detenidos"]),
          f'{f["horas_el_mas_viejo"]} h'] for f in datos["atascados"][:8]],
        {2, 3})

    tiempos = tabla(
        ["Consulta", "Peso", "Motor transaccional", "Acelerador", "Diferencia"],
        [[t["titulo"], t["peso"],
          f'{t["innodb_s"]:.2f} s',
          (f'{t["acelerador_s"]:.2f} s' if t.get("acelerador_s") else "no medido"),
          (f'{t["innodb_s"]/t["acelerador_s"]:.1f}×'
           if t.get("acelerador_s") else "—")]
         for t in datos.get("tiempos", [])],
        {2, 3, 4})

    sin_acelerador = not any(t.get("acelerador_s") for t in datos.get("tiempos", []))
    aviso = ""
    if sin_acelerador:
        aviso = ('<div class="aviso"><strong>Sin acelerador analítico en esta corrida.</strong> '
                 'Los tiempos de la tabla del pie son del motor transaccional. La comparación '
                 'contra el acelerador no se midió y por eso no se presenta ninguna cifra.</div>')

    kpis = [
        ("Documentos emitidos", miles(k["documentos_30d"]), "últimos 30 días"),
        ("Tasa de rechazo", f'{k["tasa_rechazo_30d"]} %', "últimos 30 días, agregada"),
        ("Validación p95", f'{k["p95_peor_canal"]} min', f'canal {k["canal_peor_p95"]}, el más lento'),
        ("Detenidos ahora", miles(k["detenidos"]), "más de 4 horas en proceso"),
    ]
    tarjetas_kpi = "".join(
        f'<div class="tarjeta c3"><div class="kpi-etiqueta">{e(t)}</div>'
        f'<div class="kpi-valor">{e(v)}</div><div class="kpi-nota">{e(n)}</div></div>'
        for t, v, n in kpis)

    generado = datos.get("generado", dt.datetime.now().isoformat(timespec="minutes"))
    filas_totales = miles(datos.get("filas_totales", 0))

    return f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Documentos electrónicos — tablero operacional</title>
<style>{CSS}</style></head><body>
<div id="globo"></div>
<div class="contenedor">
<header>
  <h1>Documentos electrónicos — tablero operacional</h1>
  <div class="sub">{e(datos.get("fuente", "MySQL HeatWave"))} · {filas_totales} documentos ·
     generado {e(generado)}</div>
  <div class="aviso">Datos <strong>sintéticos</strong>, generados para el taller.
     No contienen información de la organización ni de sus clientes.</div>
  {aviso}
</header>

<div class="rejilla">
  {tarjetas_kpi}

  <div class="tarjeta c8">
    <h2>Documentos emitidos por día</h2>
    <p class="pie-grafico">Decisión: ¿la capacidad contratada alcanza para lo que viene?</p>
    {grafico_linea(diario, SERIE_1)}
  </div>

  <div class="tarjeta c4">
    <h2>Motivos de rechazo</h2>
    <p class="pie-grafico">Decisión: ¿dónde se pone el esfuerzo esta semana?</p>
    {grafico_barras(motivos, SERIE_1)}
  </div>

  <div class="tarjeta c6">
    <h2>Tasa de rechazo diaria — agregada</h2>
    <p class="pie-grafico">Nada alarmante en el agregado. Mírela junto a la tabla de al lado.</p>
    {grafico_linea(tasas, SERIE_2, " %", 2)}
  </div>

  <div class="tarjeta c6">
    <h2>Clientes cuyo rechazo empeoró esta semana</h2>
    <p class="pie-grafico">El promedio de la izquierda escondía esto.</p>
    {riesgo}
  </div>

  <div class="tarjeta c6">
    <h2>Tiempo de validación por canal</h2>
    <div class="leyenda">
      <span><i class="punto" style="background:{SERIE_1}"></i>p50 (la mitad de los casos)</span>
      <span><i class="punto" style="background:{SERIE_2}"></i>p95 (los peores)</span>
    </div>
    {grafico_barras_pares(canales, " min")}
    <p class="pie-grafico">Decisión: ¿qué canal incumple el compromiso de servicio?</p>
  </div>

  <div class="tarjeta c6">
    <h2>Documentos detenidos hace más de 4 horas</h2>
    <p class="pie-grafico">Decisión: ¿qué hay que destrabar hoy?</p>
    {atascados}
  </div>

  <div class="tarjeta c12">
    <h2>Cuánto tardó cada consulta</h2>
    <p class="pie-grafico">Medido en esta corrida, sobre {filas_totales} filas.
       Las cifras son de este laboratorio: no se extrapolan a otra configuración.</p>
    {tiempos}
  </div>
</div>

<footer>
  Tablero de un solo archivo, sin dependencias ni llamadas externas: es el patrón de
  analítica embebida. Se genera con <code>tablero.py</code> a partir de
  <code>resultados.json</code>.
</footer>
</div>
<script>{JS}</script>
</body></html>"""


def main() -> int:
    p = argparse.ArgumentParser(description="Genera el tablero HTML")
    p.add_argument("--entrada", default="resultados.json")
    p.add_argument("--salida", default="tablero.html")
    args = p.parse_args()

    ruta = Path(args.entrada)
    if not ruta.exists():
        print(f"No existe {ruta}. Correr primero medir_consultas.py, o usar "
              f"resultados-ejemplo.json.", file=sys.stderr)
        return 1

    datos = json.loads(ruta.read_text(encoding="utf-8"))
    Path(args.salida).write_text(construir(datos), encoding="utf-8")
    print(f"Tablero generado: {args.salida}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
