"""
Núcleo del generador de niveles de Flechas (puerto del algoritmo GDScript).

Mecánica: una flecha es un CAMINO de celdas contiguas ortogonales (puede doblar).
Sale deslizando su CABEZA en la dirección del último segmento hasta el borde, si
el camino está libre. Un nivel es resoluble si su grafo de dependencias es un DAG
(se valida con orden topológico dinámico).

El generador rellena una figura al 100% con caminos de longitud >= 2 (backtracking)
y valida solubilidad. Determinista por semilla.
"""
from __future__ import annotations
import random
from typing import Dict, List, Optional, Tuple

Celda = Tuple[int, int]  # (fila, col)

DIRS: List[Celda] = [(-1, 0), (1, 0), (0, -1), (0, 1)]


class Flecha:
    __slots__ = ("id", "celdas")

    def __init__(self, id: int, celdas: List[Celda]):
        self.id = id
        self.celdas = list(celdas)  # cola -> cabeza

    @property
    def cabeza(self) -> Celda:
        return self.celdas[-1]

    @property
    def longitud(self) -> int:
        return len(self.celdas)

    def direccion_salida(self) -> Celda:
        # dirección del último segmento (penúltima -> cabeza)
        a = self.celdas[-2]
        b = self.celdas[-1]
        return (b[0] - a[0], b[1] - a[1])


class Tablero:
    def __init__(self, filas: int, columnas: int):
        self.filas = filas
        self.columnas = columnas
        self.jugables: set[Celda] = set()
        self.ocupacion: Dict[Celda, int] = {}
        self.flechas: Dict[int, Flecha] = {}

    def agregar_celda(self, c: Celda) -> None:
        self.jugables.add(c)

    def es_jugable(self, c: Celda) -> bool:
        return c in self.jugables

    def esta_ocupada(self, c: Celda) -> bool:
        return c in self.ocupacion

    def colocar(self, flecha: Flecha) -> None:
        self.flechas[flecha.id] = flecha
        for c in flecha.celdas:
            self.ocupacion[c] = flecha.id

    def quitar(self, id: int) -> None:
        f = self.flechas.get(id)
        if f is None:
            return
        for c in f.celdas:
            self.ocupacion.pop(c, None)
        self.flechas.pop(id, None)

    def esta_vacio(self) -> bool:
        return not self.flechas

    def puede_salir(self, id: int) -> bool:
        f = self.flechas.get(id)
        if f is None:
            return False
        df, dc = f.direccion_salida()
        af, ac = f.cabeza
        af, ac = af + df, ac + dc
        while (af, ac) in self.jugables:
            occ = self.ocupacion.get((af, ac))
            if occ is not None and occ != id:
                return False
            af, ac = af + df, ac + dc
        return True

    def clonar(self) -> "Tablero":
        t = Tablero(self.filas, self.columnas)
        t.jugables = set(self.jugables)
        t.ocupacion = dict(self.ocupacion)
        t.flechas = {i: Flecha(f.id, f.celdas) for i, f in self.flechas.items()}
        return t


def orden_solucion(tablero: Tablero) -> List[int]:
    """Orden topológico dinámico: saca flechas que puedan salir, en cadena.
    Devuelve el orden si es resoluble, o [] si se atasca (ciclo)."""
    sim = tablero.clonar()
    orden: List[int] = []
    seguridad = len(sim.flechas) + 1
    while sim.flechas and seguridad > 0:
        saco = False
        for id in list(sim.flechas.keys()):
            if sim.puede_salir(id):
                sim.quitar(id)
                orden.append(id)
                saco = True
        if not saco:
            return []
        seguridad -= 1
    return orden if not sim.flechas else []


def es_resoluble(tablero: Tablero) -> bool:
    return bool(orden_solucion(tablero)) or tablero.esta_vacio()
