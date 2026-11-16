class_name Tema
extends RefCounted

## Paleta del jugador web, portada a Godot.
## Fondo muy oscuro, paneles azulados, acento azul y flechas de colores vivos.

const FONDO := Color("#0b1020")
const PANEL := Color("#131a2e")
const PANEL_2 := Color("#1a2340")
const LINEA := Color("#26314f")
const TEXTO := Color("#e8edf7")
const TEXTO_SUAVE := Color("#93a0bd")
const ACENTO := Color("#6c8cff")
const OK := Color("#3ddc97")
const MAL := Color("#ff5d73")
const AVISO := Color("#ffc857")

## Colores de las flechas (los mismos del jugador web).
const PALETA: Array[Color] = [
	Color("#5b8cff"), Color("#3ddc97"), Color("#ffc857"), Color("#ff7b9c"),
	Color("#b388ff"), Color("#4dd0e1"), Color("#f48fb1"), Color("#9ccc65"),
	Color("#ffab40"), Color("#80cbc4"), Color("#ce93d8"), Color("#90a4ae"),
]
const ROJO_COLISION := Color("#ff5d73")

static func paleta() -> Array[Color]:
	return PALETA

## Fondo del tablero (siempre oscuro).
static func fondo(_tema: int) -> Color:
	return FONDO

## Color de una flecha segun el id.
static func color_flecha(_tema: int, id: int) -> Color:
	return PALETA[id % PALETA.size()]

## Punto de la malla (como en las referencias).
static func color_punto(_tema: int) -> Color:
	return Color(0.58, 0.66, 0.84, 0.18)
