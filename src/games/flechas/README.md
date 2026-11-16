# Flechas

Juego de puzzles: cada flecha sale por su rayo si no hay ninguna celda ocupada
delante. Incluye:

- `menu.tscn`: tarjeta del desafío diario, progreso, niveles y jugar.
- `juego.tscn`: partida (tablero, pista, victoria).
- `diario.tscn`: calendario secuencial (un nivel por fecha, en orden).
- `pack.gd`: lee los ZIP offline (clásico + diario).
- `core/`: reglas y generador (Tablero, Flecha, Métricas, Grafo).
- `cargador_*.gd`: restos del modo API (solo desarrollo).

## Niveles

Los niveles van en `assets/packs/flechas_clasico.zip` (1.000) y
`assets/packs/flechas_diario.zip` (2026–2027). Se generan con
`flechas-servidor/tools/generar_packs.py` y se bundlean en la app.

## Añadir/actualizar niveles

1. Ejecuta el generador de packs en el repo del servidor.
2. Copia los ZIP a `assets/packs/`.
3. Reexporta la app (el `include_filter` ya los mete).
