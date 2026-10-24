class_name CargadorDificiles
extends RefCounted

## Carga los niveles DIFÍCILES pre-generados (src/levels/dificiles.json) y los
## reconstruye como Tablero. El juego los usa para niveles difíciles/súper
## difíciles (que serían lentos de generar en vivo). Los fáciles/medios se
## generan al vuelo.

const RUTA := "res://src/levels/dificiles.json"

static var _pool: Array = []   # cache de niveles reconstruidos
static var _cargado := false

static func _cargar() -> void:
	if _cargado:
		return
	_cargado = true
	if not FileAccess.file_exists(RUTA):
		return
	var f := FileAccess.open(RUTA, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null or not data.has("niveles"):
		return
	for nd in data["niveles"]:
		_pool.append(nd)

## ¿Hay niveles difíciles disponibles?
static func hay() -> bool:
	_cargar()
	return _pool.size() > 0

## Devuelve un nivel difícil del pool (elegido por índice determinista según
## el número de nivel, para reproducibilidad).
static func obtener(numero: int) -> Generador.Nivel:
	_cargar()
	if _pool.is_empty():
		return null
	var nd = _pool[numero % _pool.size()]
	var t := Tablero.new(int(nd["filas"]), int(nd["columnas"]))
	for c in nd["forma"]:
		t.agregar_celda(Vector2i(int(c[0]), int(c[1])))
	for fd in nd["flechas"]:
		var celdas: Array[Vector2i] = []
		for c in fd["celdas"]:
			celdas.append(Vector2i(int(c[0]), int(c[1])))
		var color := Generador.COLORES_SUAVES[int(fd["id"]) % Generador.COLORES_SUAVES.size()]
		t.colocar(Flecha.new(int(fd["id"]), celdas, color))
	var sol: Array = nd.get("solucion", [])
	# Devuelve la SEMILLA con la que se generó realmente (no el nº de nivel),
	# para poder reproducir y auditar el nivel exacto con
	# tools/inspeccionar_semilla.gd.
	return Generador.Nivel.new(t, sol, int(nd.get("semilla", numero)))
