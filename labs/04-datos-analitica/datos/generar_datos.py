#!/usr/bin/env python3
"""
Generador de datos sintéticos de documentos electrónicos — módulo 4.

    python generar_datos.py --filas 3000000 --salida documentos.csv

Produce un CSV sin encabezado, en el orden de columnas de esquema.sql, listo para
importar con mysqlsh. Todo es inventado: no hay ni un dato de la organización ni de sus
clientes, y conviene decirlo en voz alta en la sesión.

Dos cosas están puestas a propósito, y NO se anuncian en la sala:

  1. El cliente 47 empeora su tasa de rechazo del 5 % al 22 % en los últimos diez
     días, casi todo por un mismo motivo.
  2. El canal LOTE tiene una cola de validación mucho peor que los demás, y ahí se
     concentran los documentos detenidos.

Sin hallazgos que encontrar, un tablero solo demuestra que sabemos dibujar barras.
Que la sala los descubra sola es lo que convierte la demo en un argumento.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import random
import sys

CLIENTES = 120
CLIENTE_CON_PROBLEMA = 47
DIAS_DEL_PROBLEMA = 10

TIPOS = (("FACTURA", 0.82), ("NOTA_CREDITO", 0.14), ("NOTA_DEBITO", 0.04))
CANALES = (("API", 0.62), ("PORTAL", 0.23), ("LOTE", 0.15))
CIUDADES = (("Bogotá", 0.30), ("Ciudad de México", 0.24), ("Medellín", 0.14),
            ("Cali", 0.10), ("Barranquilla", 0.08), ("Lima", 0.05), ("Santiago", 0.03))

MOTIVOS = (
    ("NIT del receptor no existe", 0.26),
    ("Fecha fuera del rango permitido", 0.19),
    ("Error en cálculo de impuestos", 0.16),
    ("Documento duplicado", 0.13),
    ("Falta información obligatoria", 0.11),
    ("Resolución de facturación vencida", 0.08),
    ("Formato de anexo inválido", 0.07),
)

# Minutos de validación por canal: (mediana aproximada, factor de cola)
PERFIL_CANAL = {
    "API": (2.0, 1.6),
    "PORTAL": (6.0, 2.0),
    "LOTE": (18.0, 4.5),   # el canal con problema: mediana alta y cola larga
}


def elegir(opciones: tuple, azar: random.Random) -> str:
    r = azar.random()
    acumulado = 0.0
    for valor, peso in opciones:
        acumulado += peso
        if r <= acumulado:
            return valor
    return opciones[-1][0]


def pesos_clientes(azar: random.Random) -> list[float]:
    """Distribución tipo Zipf: pocos clientes concentran la mayor parte del volumen,
    que es como se comportan las carteras de clientes de verdad."""
    crudos = [1.0 / (i ** 0.85) for i in range(1, CLIENTES + 1)]
    total = sum(crudos)
    return [c / total for c in crudos]


def acumulados(pesos: list[float]) -> list[float]:
    salida, suma = [], 0.0
    for p in pesos:
        suma += p
        salida.append(suma)
    return salida


def cliente_aleatorio(acum: list[float], azar: random.Random) -> int:
    r = azar.random()
    bajo, alto = 0, len(acum) - 1
    while bajo < alto:
        medio = (bajo + alto) // 2
        if acum[medio] < r:
            bajo = medio + 1
        else:
            alto = medio
    return bajo + 1


def factor_del_dia(fecha: dt.date) -> float:
    """Estacionalidad: menos volumen los fines de semana, pico al cierre de mes."""
    factor = 1.0
    if fecha.weekday() == 5:
        factor *= 0.35
    elif fecha.weekday() == 6:
        factor *= 0.18
    dia_siguiente = fecha + dt.timedelta(days=1)
    if dia_siguiente.day == 1:          # último día del mes
        factor *= 2.1
    elif fecha.day >= 27:
        factor *= 1.4
    return factor


def hora_habil(azar: random.Random) -> tuple[int, int, int]:
    """Las emisiones se concentran en horario laboral, con dos picos."""
    hora = azar.choice(
        [8, 9, 9, 10, 10, 10, 11, 11, 12, 13, 14, 14, 15, 15, 15, 16, 16, 17, 18, 20, 23])
    return hora, azar.randrange(60), azar.randrange(60)


def generar(filas: int, meses: int, salida: str, semilla: int) -> None:
    azar = random.Random(semilla)
    acum = acumulados(pesos_clientes(azar))

    hoy = dt.date.today()
    inicio = hoy - dt.timedelta(days=meses * 30)
    dias = [inicio + dt.timedelta(days=i) for i in range((hoy - inicio).days + 1)]

    factores = [factor_del_dia(d) for d in dias]
    suma_factores = sum(factores)
    por_dia = [max(1, int(filas * f / suma_factores)) for f in factores]

    documento_id = 1_000_000
    escritas = 0

    with open(salida, "w", newline="", encoding="utf-8") as fh:
        escritor = csv.writer(fh, lineterminator="\n")

        for fecha, cantidad in zip(dias, por_dia):
            dias_atras = (hoy - fecha).days
            reciente = dias_atras < DIAS_DEL_PROBLEMA

            for _ in range(cantidad):
                documento_id += 1
                cliente = cliente_aleatorio(acum, azar)
                tipo = elegir(TIPOS, azar)
                canal = elegir(CANALES, azar)
                ciudad = elegir(CIUDADES, azar)
                hora, minuto, segundo = hora_habil(azar)
                emision = dt.datetime(fecha.year, fecha.month, fecha.day, hora, minuto, segundo)

                # --- estado -------------------------------------------------
                prob_rechazo = 0.05
                if cliente == CLIENTE_CON_PROBLEMA and reciente:
                    prob_rechazo = 0.22            # hallazgo 1
                prob_en_proceso = 0.02 if dias_atras == 0 else (0.004 if dias_atras <= 2 else 0.0005)
                if canal == "LOTE":
                    prob_en_proceso *= 4.0         # hallazgo 2

                r = azar.random()
                if r < prob_rechazo:
                    estado = "RECHAZADO"
                elif r < prob_rechazo + prob_en_proceso:
                    estado = "EN_PROCESO"
                elif r < prob_rechazo + prob_en_proceso + 0.008:
                    estado = "ANULADO"
                else:
                    estado = "ACEPTADO"

                # --- motivo de rechazo --------------------------------------
                if estado == "RECHAZADO":
                    if cliente == CLIENTE_CON_PROBLEMA and reciente and azar.random() < 0.75:
                        motivo = "NIT del receptor no existe"
                    else:
                        motivo = elegir(MOTIVOS, azar)
                else:
                    motivo = r"\N"

                # --- tiempos de validación ----------------------------------
                if estado in ("ACEPTADO", "RECHAZADO"):
                    mediana, cola = PERFIL_CANAL[canal]
                    minutos = max(1, int(azar.lognormvariate(0, 0.55) * mediana))
                    if azar.random() < 0.03:                 # cola larga
                        minutos = int(minutos * cola * azar.uniform(1.5, 4.0))
                    validacion = emision + dt.timedelta(minutes=minutos)
                    fecha_validacion = validacion.strftime("%Y-%m-%d %H:%M:%S")
                    minutos_validacion = minutos
                else:
                    fecha_validacion = r"\N"
                    minutos_validacion = r"\N"

                reintentos = 0
                if estado == "RECHAZADO":
                    reintentos = azar.choices([0, 1, 2, 3], weights=[0.5, 0.3, 0.15, 0.05])[0]

                valor = round(azar.lognormvariate(0, 1.1) * 380_000, 2)

                escritor.writerow([
                    documento_id, cliente, tipo, canal, ciudad, estado, motivo,
                    emision.strftime("%Y-%m-%d %H:%M:%S"), fecha_validacion,
                    minutos_validacion, reintentos, valor,
                ])
                escritas += 1

            if escritas % 250_000 < cantidad:
                print(f"  {escritas:,} filas... ({fecha})", file=sys.stderr)

    print(f"\n{escritas:,} filas en {salida}")
    print(f"Rango: {dias[0]} a {dias[-1]}  ·  {CLIENTES} clientes  ·  semilla {semilla}")
    print("\nSiguiente paso: subir el CSV a Object Storage e importarlo con mysqlsh.")
    print("Ver docs/02-MANUAL-PASO-A-PASO.md, paso 4.")


def main() -> int:
    p = argparse.ArgumentParser(description="Genera documentos electrónicos sintéticos")
    p.add_argument("--filas", type=int, default=3_000_000,
                   help="filas aproximadas (por defecto 3 millones; usar 200000 para la primera prueba)")
    p.add_argument("--meses", type=int, default=6)
    p.add_argument("--salida", default="documentos.csv")
    p.add_argument("--semilla", type=int, default=20260915,
                   help="misma semilla, mismos datos: la demo es reproducible")
    args = p.parse_args()

    generar(args.filas, args.meses, args.salida, args.semilla)
    return 0


if __name__ == "__main__":
    sys.exit(main())
