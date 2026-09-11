# Plantillas de los entregables

Cada módulo del taller termina con un entregable que se llena **en vivo** y se clasifica
solo. No son formularios pasivos: la hoja marca en rojo lo que falta y arma las listas de
trabajo sin que nadie las ordene a mano.

| Plantilla | Qué hace de especial |
|---|---|
| [Checklist de seguridad](checklist-seguridad) | 39 controles en 9 dominios. Convierte «no sé» en riesgo a validar, y «no» de bajo esfuerzo en quick win. Propone un mínimo por ambiente: 13 controles obligatorios en desarrollo, 25 en pruebas, 30 en producción. |
| [Ficha de caso de IA](ficha-caso-ia) | Ocho candidatos puntuados con cuatro criterios ponderados, y una ficha de 18 campos para el que gane. El criterio «datos» pesa 25 % porque es donde fracasan casi todos los casos de IA. |
| [Blueprint de datos](blueprint-datos) | Inventario de fuentes con dueño, frecuencia y calidad, más un lienzo de seis casillas que empieza por la decisión y no por los datos. Marca en rojo lo que no tiene dueño. |
| [Matriz de observabilidad](matriz-observabilidad) | 16 señales en 10 categorías. Calcula la cobertura y marca sola toda alarma que despierte a alguien sin tener acción escrita. |

## Cómo se generan

Cada plantilla sale de un script de Python que es la **fuente única**: produce el Excel y su
versión en Markdown. Para adaptarla, se edita la lista de controles o de señales dentro del
script y se vuelve a ejecutar.

```bash
pip install openpyxl
cd checklist-seguridad && python generar_checklist.py
```

Después hay que **abrir el Excel y guardarlo una vez** para que calcule: los archivos escritos
por la librería llevan las fórmulas, pero sin valores en caché.

## Por qué un script y no un Excel a mano

Un Excel editado a mano se desincroniza de su versión en texto en la segunda revisión, y nadie
sabe cuál de las dos vale. Con un generador, la lista de controles vive en un solo lugar,
el cambio queda en el historial y las dos salidas siempre coinciden.
