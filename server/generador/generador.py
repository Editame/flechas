"""Generador de niveles: rellena una figura al 100% con caminos que doblan
(longitud >= 2) y valida solubilidad. Puerto de generador.gd, optimizado."""
from __future__ import annotations
import random
import sys
from typing import Dict, List, Optional, Tuple

from .core import Tablero, Flecha, orden_solucion, DIRS

Celda = Tuple[int, int]

# Sube el límite de recursión para tableros grandes (backtracking profundo).
sys.setrecursionlimit(100000)


class Nivel:
    def __init__(self, tablero: Tablero, solucion: List[int], semilla: int):
        self.tablero = tablero
        self.solucion = solucion
        self.semilla = semilla


def _primera_libre(tablero: Tablero) -> Optional[Celda]:
    mejor = None
    for c in tablero.jugables:
        if c not in tablero.ocupacion:
            if mejor is None or c < mejor:
                mejor = c
    return mejor


def _caminos_desde(tablero: Tablero, rng: random.Random, ancla: Celda,
                   long_max: int, intentos: int = 10) -> List[List[Celda]]:
    """Genera varios caminos candidatos desde `ancla` (cola) que pueden doblar."""
    resultado: List[List[Celda]] = []
    for _ in range(intentos):
        camino = [ancla]
        usadas = {ancla}
        objetivo = rng.randint(2, long_max)
        actual = ancla
        while len(camino) < objetivo:
            dirs = DIRS[:]
            rng.shuffle(dirs)
            avanzo = False
            for d in dirs:
                sig = (actual[0] + d[0], actual[1] + d[1])
                if sig in tablero.jugables and sig not in tablero.ocupacion and sig not in usadas:
                    camino.append(sig)
                    usadas.add(sig)
                    actual = sig
                    avanzo = True
                    break
            if not avanzo:
                break
        if len(camino) >= 2 and camino not in resultado:
            resultado.append(camino)
    # Prioriza caminos más largos (rellenan mejor / menos fragmentos).
    resultado.sort(key=len, reverse=True)
    return resultado


def _rellenar_bt(tablero: Tablero, rng: random.Random, long_max: int,
                 acc: List[Flecha]) -> bool:
    ancla = _primera_libre(tablero)
    if ancla is None:
        return True  # relleno completo
    for celdas in _caminos_desde(tablero, rng, ancla, long_max):
        id = len(acc)
        flecha = Flecha(id, celdas)
        tablero.colocar(flecha)
        acc.append(flecha)
        if _rellenar_bt(tablero, rng, long_max, acc):
            return True
        acc.pop()
        tablero.quitar(id)
    return False


def generar_relleno(forma: List[Celda], filas: int, columnas: int,
                    long_max: int = 6, semilla: int = -1,
                    intentos: int = 200) -> Optional[Nivel]:
    """Genera un nivel rellenando la figura al 100% con caminos que doblan,
    resoluble. Prueba varias semillas derivadas hasta lograrlo."""
    base = semilla if semilla >= 0 else random.randint(0, 2**31)
    for intento in range(intentos):
        s = base + intento * 6151
        rng = random.Random(s)
        tablero = Tablero(filas, columnas)
        for c in forma:
            tablero.agregar_celda(c)
        acc: List[Flecha] = []
        if not _rellenar_bt(tablero, rng, long_max, acc):
            continue
        solucion = orden_solucion(tablero)
        if not solucion:
            continue
        return Nivel(tablero, solucion, s)
    return None


def serializar_nivel(numero: int, nivel: Nivel, forma: List[Celda]) -> dict:
    t = nivel.tablero
    flechas = []
    for id, f in t.flechas.items():
        flechas.append({
            "id": f.id,
            "celdas": [[c[0], c[1]] for c in f.celdas],
        })
    return {
        "numero": numero,
        "filas": t.filas,
        "columnas": t.columnas,
        "forma": [[c[0], c[1]] for c in forma],
        "flechas": flechas,
        "solucion": nivel.solucion,
        "semilla": nivel.semilla,
    }
