extends Node

## Carga offline de los niveles de Flechas: dos ZIP con un index.json y un JSON
## compacto por nivel. Si el pack no existe (desarrollo) se cae a la API.

const RUTA_CLASICO := "res://assets/packs/flechas_clasico.zip"
const RUTA_DIARIO := "res://assets/packs/flechas_diario.zip"

var _zip_clasico: ZIPReader
var _zip_diario: ZIPReader
var _idx_clasico: Dictionary = {}
var _idx_diario: Dictionary = {}

func _ready() -> void:
	_abrir(RUTA_CLASICO, true)
	_abrir(RUTA_DIARIO, false)

func _abrir(ruta: String, clasico: bool) -> void:
	var z := ZIPReader.new()
	if z.open(ruta) != OK:
		push_warning("[pack] no se pudo abrir " + ruta)
		return
	var datos := z.read_file("index.json")
	if datos.is_empty():
		push_warning("[pack] sin index.json en " + ruta)
		return
	var idx = JSON.parse_string(datos.get_string_from_utf8())
	if typeof(idx) != TYPE_DICTIONARY:
		push_warning("[pack] index invalido en " + ruta)
		return
	if clasico:
		_zip_clasico = z
		_idx_clasico = idx.get("niveles", {})
		print("[pack] clasico: ", _idx_clasico.size(), " niveles")
	else:
		_zip_diario = z
		_idx_diario = idx.get("fechas", {})
		print("[pack] diario: ", _idx_diario.size(), " fechas")

func total_clasico() -> int:
	return _idx_clasico.size()

func nivel_clasico(numero: int) -> Dictionary:
	var info = _idx_clasico.get(str(numero))
	if info == null:
		return {}
	return _leer(_zip_clasico, str(info.get("archivo", "")))

func nivel_diario(fecha: String) -> Dictionary:
	var info = _idx_diario.get(fecha)
	if info == null:
		return {}
	return _leer(_zip_diario, str(info.get("archivo", "")))

func _leer(z: ZIPReader, archivo: String) -> Dictionary:
	if z == null or archivo.is_empty():
		return {}
	var datos := z.read_file(archivo)
	if datos.is_empty():
		return {}
	var data = JSON.parse_string(datos.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data
