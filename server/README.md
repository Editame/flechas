# Generador de niveles — Flechas (server)

Servicio en **Python (FastAPI)** que genera niveles del juego Flechas: rellena
una figura al 100% con flechas (caminos que pueden doblar, longitud ≥ 2) y
garantiza que sean **resolubles** (validación por grafo de dependencias / DAG).

Es una **herramienta de desarrollo**: genera los niveles que luego se empaquetan
dentro del APK del juego (el teléfono NO se comunica con este servicio; juega
offline con los niveles ya incluidos).

## Estructura

```
server/
├─ generador/
│  ├─ core.py         # modelo (Flecha camino, Tablero), regla de salida, grafo
│  ├─ figuras.py      # figuras (rectangulo, ele, marco, te, corazon)
│  ├─ generador.py    # relleno 100% con caminos que doblan + validación DAG
│  └─ api.py          # API HTTP (FastAPI)
├─ requirements.txt
├─ Dockerfile
└─ docker-compose.yml
```

## Correr local (sin Docker)

```bash
cd server
pip install -r requirements.txt
uvicorn generador.api:app --host 0.0.0.0 --port 8080
```

## Correr con Docker

```bash
cd server
docker compose up -d --build
```

Escucha en el puerto **8080**.

## API

- `GET /salud` — estado del servicio.
- `GET /figuras` — figuras disponibles.
- `POST /generar` — genera nivel(es).

Ejemplo:

```bash
curl -X POST http://localhost:8080/generar \
  -H "Content-Type: application/json" \
  -d '{"figura":"corazon","long_max":6,"cantidad":1,"semilla":42}'
```

Parámetros de `/generar`:

| Campo     | Tipo | Descripción |
|-----------|------|-------------|
| figura    | str  | rectangulo, ele, marco, te, corazon |
| filas     | int  | filas (para figuras paramétricas) |
| columnas  | int  | columnas |
| recorte   | int  | solo para `ele` |
| long_max  | int  | longitud máxima de cada flecha |
| cantidad  | int  | cuántos niveles generar (lote) |
| semilla   | int  | reproducibilidad; -1 = aleatoria |

Devuelve JSON con los niveles (mismo formato que consume el juego en
`src/levels/`).
