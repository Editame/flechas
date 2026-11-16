extends Node

## Cliente HTTP de la API de niveles (servidor local o remoto).
##
## Uso:
##   API_Client.siguiente("dificil")   -> emite nivel_listo(datos)
##   API_Client.pool("medio", 8)       -> emite nivel_listo(datos) con uno del pool
##   API_Client.salud()
##
## Cada llamada usa su propia HTTPRequest, asi no se mezclan respuestas.

signal nivel_listo(datos: Dictionary)
signal salud_ok(datos: Dictionary)
signal error(mensaje: String)

const BASE_POR_DEFECTO := "http://127.0.0.1:8077/flechas/v1"

var _base: String = BASE_POR_DEFECTO

func _ready() -> void:
	cargar_url_servidor()

func cargar_url_servidor() -> void:
	if has_node("/root/Sesion"):
		_base = get_node("/root/Sesion").get_url_servidor()
	_base = _base.strip_edges()
	while _base.ends_with("/"):
		_base = _base.substr(0, _base.length() - 1)
	if _base.is_empty():
		_base = BASE_POR_DEFECTO
	# si solo dieron host:puerto, anadir el prefijo de la API
	if not _base.contains("/flechas/"):
		_base += "/flechas/v1"

func url_base() -> String:
	return _base

## Pide el siguiente nivel pregenerado de esa dificultad (instantaneo).
func siguiente(dificultad: String) -> void:
	_pedir("GET", "/siguiente/" + dificultad, {}, "siguiente")

## Pide un nivel cualquiera del pool de esa dificultad.
func pool(dificultad: String, cantidad: int = 8) -> void:
	_pedir("POST", "/pool", {"dificultad": dificultad, "cantidad": cantidad}, "pool")

## Genera un nivel concreto por semilla (desafio diario, depuracion).
func generar(dificultad: String, semilla: int) -> void:
	_pedir("POST", "/generar",
			{"dificultad": dificultad, "semilla": semilla, "guardar": false}, "generar")

## Comprueba la conexion contra el endpoint estandar /health.
func health() -> void:
	_pedir("GET", "/health", {}, "salud")

func _pedir(metodo: String, ruta: String, cuerpo: Dictionary, tipo: String) -> void:
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	var url := _base + ruta
	print("[api] ", metodo, " ", url)
	var cabeceras := PackedStringArray(["Content-Type: application/json"])
	var err := OK
	if metodo == "GET":
		err = req.request(url, cabeceras, HTTPClient.METHOD_GET)
	else:
		err = req.request(url, cabeceras, HTTPClient.METHOD_POST, JSON.stringify(cuerpo))
	if err != OK:
		req.queue_free()
		printerr("[api] fallo al iniciar la peticion (", err, "): ", url)
		error.emit("Sin conexion")
		return
	req.request_completed.connect(_al_completar.bind(req, tipo, ruta))

func _al_completar(resultado: int, codigo: int, _cabeceras: PackedStringArray,
		cuerpo: PackedByteArray, req: HTTPRequest, tipo: String, ruta: String) -> void:
	var url_completa := _base + ruta
	req.queue_free()
	if resultado != HTTPRequest.RESULT_SUCCESS:
		printerr("[api] sin respuesta (", resultado, "): ", url_completa)
		error.emit("Sin respuesta")
		return
	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK:
		error.emit("Respuesta no valida del servidor")
		return
	if codigo != 200:
		var detalle := ""
		if json.data is Dictionary:
			detalle = str(json.data.get("detail", ""))
		printerr("[api] HTTP ", codigo, " ", detalle, "  (", url_completa, ")")
		error.emit("Error %d" % codigo)
		return
	print("[api] ok ", ruta)
	if tipo == "salud":
		salud_ok.emit(json.data)
		return
	if tipo == "pool":
		var niveles: Array = []
		if json.data is Dictionary:
			niveles = json.data.get("niveles", [])
		if niveles.is_empty():
			error.emit("El pool vino vacio")
			return
		nivel_listo.emit(niveles[0])
		return
	if tipo == "generar":
		if json.data is Dictionary and json.data.has("nivel"):
			nivel_listo.emit(json.data["nivel"])
		else:
			error.emit("Respuesta de /generar no valida")
		return
	nivel_listo.emit(json.data)
