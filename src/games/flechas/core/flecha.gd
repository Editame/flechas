class_name Flecha
extends RefCounted

## Una flecha del tablero. Es un CAMINO de celdas contiguas (puede DOBLAR
## esquinas, estilo Amaze GO). Lógica pura, sin nodos de Godot.
##
## Convención:
##  - `celdas` está ordenado desde la COLA hacia la CABEZA (el frente que sale).
##  - El camino es una secuencia de celdas contiguas ortogonalmente; entre celdas
##    consecutivas hay pasos de 1 en una de las 4 direcciones (puede cambiar de
##    dirección = doblar).
##  - La CABEZA es celdas[-1]. La flecha SALE siguiendo la dirección del último
##    segmento (de la penúltima celda a la cabeza) y luego en línea recta hasta
##    el borde.

var id: int
var celdas: Array[Vector2i]  # ordenadas cola -> cabeza
var color: Color

func _init(p_id: int, p_celdas: Array[Vector2i], p_color: Color = Color.WHITE) -> void:
	id = p_id
	celdas = p_celdas.duplicate()
	color = p_color

func cabeza() -> Vector2i:
	return celdas[celdas.size() - 1]

func cola() -> Vector2i:
	return celdas[0]

func longitud() -> int:
	return celdas.size()

## Dirección de SALIDA: la del último segmento (penúltima -> cabeza).
func direccion_salida() -> Vector2i:
	if celdas.size() < 2:
		return Vector2i(0, 1)  # fallback (no debería pasar; longitud >= 2)
	return celdas[celdas.size() - 1] - celdas[celdas.size() - 2]

func ocupa(celda: Vector2i) -> bool:
	return celdas.has(celda)

func clonar() -> Flecha:
	return Flecha.new(id, celdas.duplicate(), color)

func _to_string() -> String:
	return "Flecha#%d[len=%d cabeza=%s dir=%s]" % [
		id, longitud(), str(cabeza()), str(direccion_salida())
	]
