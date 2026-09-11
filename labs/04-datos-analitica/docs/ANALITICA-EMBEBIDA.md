# Analítica embebida: de eficiencia interna a capacidad vendible

Material de apoyo. Se usa si la conversación del minuto 19 toma este rumbo —y con
la organización es probable, porque venden software a otras empresas.

---

## 1. La diferencia que importa

| | Tablero interno | Analítica embebida |
|---|---|---|
| Quién lo ve | El equipo de la organización | **Los clientes de la organización**, dentro del producto que ya usan |
| Dónde vive | Una herramienta aparte, con su propio acceso | Dentro del ERP, el WHS, el portal B2B |
| Qué produce | Eficiencia interna | Diferenciación, y en algunos casos ingreso |
| Costo por usuario | Licencias de BI | Ninguna adicional si se genera desde la aplicación |
| Quién responde por el dato | El área que lo usa | la organización, ante su cliente |

La última fila es la que cambia todo. Enseñarle un número a un cliente es una promesa
contractual, no un reporte interno.

---

## 2. Tres formas de hacerlo, de menor a mayor esfuerzo

### A. Vista generada (lo que se demostró)

Una consulta produce datos, un generador produce una página, la aplicación la sirve.
Sin plataforma de BI detrás, sin licencias por usuario, funciona sin conexión.

- **Cuándo:** indicadores acotados y conocidos, que cambian con poca frecuencia.
- **Límite:** el usuario no explora; ve lo que se decidió mostrar.
- **Lo que la organización vio en la preparación** es exactamente esto: un archivo, sin dependencias.

### B. Consultas en vivo desde la aplicación

La aplicación consulta la base analítica al abrir la pantalla, con el filtro del
cliente ya aplicado.

- **Cuándo:** el usuario necesita filtrar por fechas o dimensiones.
- **Requisito:** que la consulta responda rápido con el cliente mirando. Aquí es donde
  un acelerador analítico deja de ser un lujo — la alternativa es precalcular.

### C. Plataforma de BI incrustada

Un producto de analítica embebido con su propio control de acceso.

- **Cuándo:** el cliente quiere construir sus propios análisis.
- **Costo real:** licenciamiento y un modelo de identidad que tiene que coincidir con
  el de la aplicación. Rara vez es por donde se empieza.

> **Recomendación de partida:** A para el primer entregable, B cuando el uso lo pida.
> Empezar por C es la forma más común de gastar seis meses antes de que un cliente vea
> el primer número.

---

## 3. Lo que no se puede improvisar: el aislamiento

Si cada cliente ve lo suyo, hay una sola regla y no admite matices:

> **El filtro por cliente se aplica en la capa de datos y viene de la identidad de
> quien consulta. Nunca de un parámetro que llegue del navegador.**

Un identificador de cliente en la URL o en el cuerpo de la petición es una invitación a
cambiarlo por el del vecino. Es el mismo principio que en el módulo 3: el alcance se
fija fuera de la capa que recibe la petición.

Checklist mínimo antes de mostrarle un número a un cliente final:

- [ ] Toda tabla del modelo analítico tiene el identificador de cliente.
- [ ] Toda consulta lo filtra, y el filtro no es opcional.
- [ ] El identificador sale del token de sesión, no de la petición.
- [ ] Hay una prueba automática que intenta ver datos de otro cliente **y falla**.
- [ ] Los registros muestran qué cliente consultó qué y cuándo (controles L-01 y M-03).
- [ ] Los datos agregados no permiten deducir los de otro cliente (cuidado con los
      promedios del sector cuando hay pocos participantes).

La última es la más olvidada: "su desempeño frente al promedio del sector" con tres
clientes en el sector es, en la práctica, publicar los datos de los otros dos.

---

## 4. Qué preguntar en la sesión

Si el tema surge, estas cuatro preguntas ordenan la conversación sin alargarla:

1. ¿Cuál de sus productos tiene clientes que ya piden reportes por correo o por ticket?
   *(Ahí hay demanda demostrada, y un costo operativo actual que se puede medir.)*
2. ¿Ese reporte se lo arma alguien a mano hoy? ¿Cuántas horas al mes?
3. ¿Lo cobrarían aparte o sería parte del valor del producto?
4. ¿Qué número **no** les mostrarían a sus clientes, y por qué?

> La cuarta es la más reveladora: define el alcance mejor que cualquier lista de
> requisitos.
