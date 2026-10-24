class_name Tema
extends RefCounted

## Paleta: fondo blanco grisáceo suave, flechas AZUL TURQUESA.
## Tema por defecto: flechas turquesa. Tema COLORES: variados.

const FONDO_BASE := Color(0.94, 0.95, 0.96)      # blanco grisáceo suave
const NAVY := Color(0.078, 0.110, 0.227)         # #141C3A azul marino oscuro (de la referencia)
const ACENTO := Color(0.078, 0.110, 0.227)       # navy para UI
const TEXTO := Color(0.12, 0.16, 0.28)
const TEXTO_SUAVE := Color(0.45, 0.48, 0.55)

const PASTEL: Array[Color] = [
	Color(0.13, 0.62, 0.64),   # turquesa
	Color(0.42, 0.62, 0.86),   # azul
	Color(0.55, 0.72, 0.42),   # verde
	Color(0.90, 0.60, 0.35),   # naranja
	Color(0.66, 0.52, 0.82),   # morado
	Color(0.90, 0.45, 0.55),   # rosa
	Color(0.40, 0.72, 0.70),   # verde agua
]

const ROJO_COLISION := Color(0.87, 0.25, 0.28)

## Fondo (blanco grisáceo en ambos temas).
static func fondo(_tema: int) -> Color:
	return FONDO_BASE

## Color de una flecha (por su id) según el tema.
static func color_flecha(tema: int, id: int) -> Color:
	match tema:
		Config.Tema.COLORES:
			return PASTEL[id % PASTEL.size()]
		_:
			return NAVY

## Color del punto/nodo del dot-grid.
static func color_punto(_tema: int) -> Color:
	return Color(0.20, 0.28, 0.30, 0.12)
