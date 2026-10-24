class_name Tablero
extends RefCounted

## Estado del tablero y reglas del juego. Lógica pura (sin nodos Godot).
##
## - `jugables`: conjunto de celdas que EXISTEN (forma arbitraria del tablero).
##    Se representa como Dictionary<Vector2i, true> para O(1).
## - `ocupacion`: Dictionary<Vector2i, id_flecha>.
## - `flechas`: Dictionary<id, Flecha>.

const RESULTADO_EXITOSA := "exitosa"
const RESULTADO_BLOQUEADA := "bloqueada"
const RESULTADO_INVALIDA := "invalida"

var filas: int
var columnas: int
var jugables: Dictionary = {}      # Vector2i -> true
var ocupacion: Dictionary = {}     # Vector2i -> int (id flecha)
var flechas: Dictionary = {}       # int -> Flecha

func _init(p_filas: int, p_columnas: int) -> void:
	filas = p_filas
	columnas = p_columnas

## Marca una celda como jugable (parte del tablero).
func agregar_celda(celda: Vector2i) -> void:
	jugables[celda] = true

## Crea un tablero rectangular lleno (todas las celdas jugables).
static func rectangular(p_filas: int, p_columnas: int) -> Tablero:
	var t := Tablero.new(p_filas, p_columnas)
	for f in p_filas:
		for c in p_columnas:
			t.agregar_celda(Vector2i(f, c))
	return t

func es_jugable(celda: Vector2i) -> bool:
	return jugables.has(celda)

func esta_ocupada(celda: Vector2i) -> bool:
	return ocupacion.has(celda)

## Coloca una flecha en el tablero (ocupa sus celdas). No valida solapamiento
## salvo asercion basica; el generador es quien garantiza validez.
func colocar(flecha: Flecha) -> void:
	flechas[flecha.id] = flecha
	for celda in flecha.celdas:
		ocupacion[celda] = flecha.id

## Quita una flecha del tablero (libera sus celdas).
func quitar(id: int) -> void:
	var flecha: Flecha = flechas.get(id)
	if flecha == null:
		return
	for celda in flecha.celdas:
		ocupacion.erase(celda)
	flechas.erase(id)

func cantidad_flechas() -> int:
	return flechas.size()

func esta_vacio() -> bool:
	return flechas.is_empty()

## ¿La flecha puede salir? La CABEZA se desliza en la dirección de su último
## segmento hasta salir del área jugable. Si CUALQUIER celda de ese recorrido
## está ocupada —incluido su PROPIO cuerpo— no puede salir (auto-bloqueo).
func puede_salir(id: int) -> bool:
	var flecha: Flecha = flechas.get(id)
	if flecha == null:
		return false
	var paso := flecha.direccion_salida()
	var actual := flecha.cabeza() + paso
	while es_jugable(actual):
		# Cualquier celda ocupada bloquea, INCLUSO si es de la propia flecha
		# (una flecha no puede atravesar su propio cuerpo para salir).
		if esta_ocupada(actual):
			return false
		actual += paso
	return true

## Intenta sacar una flecha. Si puede, la quita y devuelve EXITOSA.
func intentar_sacar(id: int) -> String:
	if not flechas.has(id):
		return RESULTADO_INVALIDA
	if puede_salir(id):
		quitar(id)
		return RESULTADO_EXITOSA
	return RESULTADO_BLOQUEADA

## ¿Hay al menos una flecha que pueda salir ahora mismo?
func hay_movimiento_posible() -> bool:
	for id in flechas.keys():
		if puede_salir(id):
			return true
	return false

## ¿El jugador ganó? (tablero vacío)
func victoria() -> bool:
	return esta_vacio()

## ¿Atascado? Quedan flechas pero ninguna puede salir.
func atascado() -> bool:
	return not esta_vacio() and not hay_movimiento_posible()

## Copia profunda para simulaciones.
func clonar() -> Tablero:
	var t := Tablero.new(filas, columnas)
	t.jugables = jugables.duplicate()
	t.ocupacion = ocupacion.duplicate()
	for id in flechas.keys():
		t.flechas[id] = (flechas[id] as Flecha).clonar()
	return t
