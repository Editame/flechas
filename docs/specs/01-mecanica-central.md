# 01 — Mecánica central: salida y bloqueo de flechas

## Objetivo
Implementar y probar la regla base: una flecha sale del tablero si su recorrido
en su dirección está libre; si otra flecha lo obstruye, queda bloqueada.

## Requisitos
- **RF-01.1** El tablero conoce sus celdas jugables (forma arbitraria) y qué
  flecha ocupa cada celda.
- **RF-01.2** Una flecha ocupa 1+ celdas contiguas en línea (longitud variable)
  y apunta a una de 4 direcciones.
- **RF-01.3** `intentar_sacar(flecha)` devuelve EXITOSA si todo el recorrido
  hasta salir del área jugable está libre; BLOQUEADA si hay otra flecha.
- **RF-01.4** Al salir, se liberan TODAS las celdas de la flecha.
- **RF-01.5** El juego detecta VICTORIA (tablero vacío) y ATASCADO (ninguna
  flecha puede salir).

## Fuera de alcance (de este spec)
- Generación de niveles (spec 02) y render/animación (spec 03).

## Pruebas mínimas
- Flecha con camino libre sale.
- Flecha con otra en el camino se bloquea.
- Flecha larga que solo cabe si el recorrido completo está libre.
- Sacar una flecha desbloquea a otra que dependía de ella.
- Detección de atascado con un ciclo A↔B.
