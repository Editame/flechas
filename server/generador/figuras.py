"""Figuras (lienzos) como listas de celdas. Puerto de figuras.gd."""
from __future__ import annotations
from typing import List, Tuple

Celda = Tuple[int, int]


def _asegurar_par(celdas: List[Celda]) -> List[Celda]:
    """Si el número de celdas es impar, quita una celda con menos vecinos
    (los caminos de longitud >= 2 requieren área par para teselar sin huecos)."""
    if len(celdas) % 2 == 0:
        return celdas
    s = set(celdas)
    mejor = celdas[-1]
    minv = 5
    for c in celdas:
        v = sum(1 for d in [(1, 0), (-1, 0), (0, 1), (0, -1)] if (c[0] + d[0], c[1] + d[1]) in s)
        if v < minv:
            minv = v
            mejor = c
    celdas = [c for c in celdas if c != mejor]
    return celdas


def rectangulo(filas: int, columnas: int) -> List[Celda]:
    return [(f, c) for f in range(filas) for c in range(columnas)]


def ele(filas: int, columnas: int, recorte: int) -> List[Celda]:
    res = []
    for f in range(filas):
        for c in range(columnas):
            if f < recorte and c >= columnas - recorte:
                continue
            res.append((f, c))
    return _asegurar_par(res)


def marco(filas: int, columnas: int) -> List[Celda]:
    res = []
    for f in range(filas):
        for c in range(columnas):
            if f == 0 or f == filas - 1 or c == 0 or c == columnas - 1:
                res.append((f, c))
    return _asegurar_par(res)


def te(filas: int, columnas: int) -> List[Celda]:
    res = []
    for f in range(2):
        for c in range(columnas):
            res.append((f, c))
    col_ini = (columnas - 2) // 2
    for f in range(2, filas):
        for c in range(col_ini, col_ini + 2):
            res.append((f, c))
    return _asegurar_par(res)


def _desde_patron(patron: List[str]) -> List[Celda]:
    res = []
    for f, fila in enumerate(patron):
        for c, ch in enumerate(fila):
            if ch == "#":
                res.append((f, c))
    return _asegurar_par(res)


def corazon() -> List[Celda]:
    patron = [
        " ####   #### ",
        "##############",
        "##############",
        "##############",
        "##############",
        " ############ ",
        "  ##########  ",
        "   ########   ",
        "    ######    ",
        "     ####     ",
        "      ##      ",
    ]
    return _desde_patron(patron)


def bounding_box(forma: List[Celda]) -> Tuple[int, int]:
    maxf = max(c[0] for c in forma)
    maxc = max(c[1] for c in forma)
    return maxf + 1, maxc + 1
