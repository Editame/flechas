"""API HTTP del generador de niveles de Flechas.

Endpoints:
  GET  /salud                      -> estado del servicio
  GET  /figuras                    -> lista de figuras disponibles
  POST /generar                    -> genera un nivel (o lote) con parámetros

Ejemplo POST /generar:
  {
    "figura": "rectangulo",   # rectangulo|ele|marco|te|corazon
    "filas": 10, "columnas": 10,
    "recorte": 3,             # solo para 'ele'
    "long_max": 6,
    "cantidad": 1,            # cuántos niveles generar (lote)
    "semilla": 123            # opcional; -1 aleatoria
  }
"""
from __future__ import annotations
from typing import List, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from .generador import generar_relleno, serializar_nivel
from . import figuras

app = FastAPI(title="Flechas - Generador de niveles", version="1.0.0")


class PeticionGenerar(BaseModel):
    figura: str = "rectangulo"
    filas: int = 10
    columnas: int = 10
    recorte: int = 3
    long_max: int = 6
    cantidad: int = 1
    semilla: int = -1


def _construir_forma(p: PeticionGenerar) -> List:
    f = p.figura.lower()
    if f == "rectangulo":
        return figuras.rectangulo(p.filas, p.columnas)
    if f == "ele":
        return figuras.ele(p.filas, p.columnas, p.recorte)
    if f == "marco":
        return figuras.marco(p.filas, p.columnas)
    if f == "te":
        return figuras.te(p.filas, p.columnas)
    if f == "corazon":
        return figuras.corazon()
    raise HTTPException(status_code=400, detail=f"Figura desconocida: {p.figura}")


@app.get("/salud")
def salud():
    return {"ok": True, "servicio": "generador-flechas", "version": "1.0.0"}


@app.get("/figuras")
def listar_figuras():
    return {"figuras": ["rectangulo", "ele", "marco", "te", "corazon"]}


@app.post("/generar")
def generar(p: PeticionGenerar):
    forma = _construir_forma(p)
    filas, columnas = figuras.bounding_box(forma)
    niveles = []
    for i in range(max(1, p.cantidad)):
        semilla = p.semilla if p.semilla >= 0 else -1
        # Si es lote con semilla fija, deriva una por índice para variar.
        if p.semilla >= 0 and p.cantidad > 1:
            semilla = p.semilla + i * 100003
        nivel = generar_relleno(forma, filas, columnas, p.long_max, semilla)
        if nivel is None:
            raise HTTPException(status_code=500,
                                detail=f"No se pudo generar nivel {i+1} (figura no teselable?)")
        niveles.append(serializar_nivel(i + 1, nivel, forma))
    return {
        "figura": p.figura,
        "filas": filas,
        "columnas": columnas,
        "cantidad": len(niveles),
        "niveles": niveles,
    }
