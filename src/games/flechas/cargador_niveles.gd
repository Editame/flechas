class_name CargadorNiveles
extends RefCounted

## Lee los niveles congelados de src/levels/mundo1.json y los reconstruye como
## Tablero (lógica pura). Separado del render.

const RUTA_MUNDO1 := "res://src/levels/mundo1.json"

## Devuelve un Array de Dictionary con { numero, tablero: Tablero, solucion }.
static func cargar_mundo1() -> Array:
	var f := FileAccess.open(RUTA_MUNDO1, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir " + RUTA_MUNDO1)
		return []
	var texto := f.get_as_text()
	f.close()
	var data = JSON.parse_string(texto)
	if data == null or not data.has("niveles"):
		push_error("mundo1.json inválido")
		return []

	var res: Array = []
	for nivel_data in data["niveles"]:
		res.append(_reconstruir(nivel_data))
	return res

static func _reconstruir(nivel_data: Dictionary) -> Dictionary:
	# Reconstruye el tablero con la FORMA de la figura (no necesariamente rectangular).
	var t := Tablero.new(int(nivel_data["filas"]), int(nivel_data["columnas"]))
	if nivel_data.has("forma"):
		for c in nivel_data["forma"]:
			t.agregar_celda(Vector2i(int(c[0]), int(c[1])))
	else:
		# Compatibilidad: si no hay forma, asumir rectangular lleno.
		for f in t.filas:
			for col in t.columnas:
				t.agregar_celda(Vector2i(f, col))
	for fd in nivel_data["flechas"]:
		var celdas: Array[Vector2i] = []
		for c in fd["celdas"]:
			celdas.append(Vector2i(int(c[0]), int(c[1])))
		var flecha := Flecha.new(
			int(fd["id"]), celdas,
			Generador.COLORES_SUAVES[int(fd["id"]) % Generador.COLORES_SUAVES.size()])
		t.colocar(flecha)
	return {
		"numero": int(nivel_data["numero"]),
		"tablero": t,
		"solucion": nivel_data.get("solucion", []),
	}
