extends Control

## Modal para configurar la URL base de la API de niveles, con boton para
## probar la conexion contra /health.

signal guardado(url: String)

const URL_POR_DEFECTO := "http://127.0.0.1:8077/flechas/v1"
const OK_COLOR := Color("#3ddc97")
const MAL_COLOR := Color("#ff5d73")

@onready var _lineedit: LineEdit = $Panel/VBox/VBoxConfig/LineEditURL
@onready var _btn_probar: Button = $Panel/VBox/VBoxConfig/BtnProbar
@onready var _lbl_estado: Label = $Panel/VBox/VBoxConfig/LblEstado
@onready var _btn_guardar: Button = $Panel/VBox/VBoxConfig/Botones/BtnGuardar
@onready var _btn_cancelar: Button = $Panel/VBox/VBoxConfig/Botones/BtnCancelar

func _ready() -> void:
	_lineedit.text = get_node("/root/Sesion").get_url_servidor() if has_node("/root/Sesion") else URL_POR_DEFECTO
	_btn_guardar.pressed.connect(_guardar)
	_btn_cancelar.pressed.connect(_cerrar)
	_btn_probar.pressed.connect(_probar)
	if has_node("/root/API_Client"):
		var api := get_node("/root/API_Client")
		api.salud_ok.connect(_on_salud)
		api.error.connect(_on_error)

func _probar() -> void:
	_lbl_estado.text = "Probando..."
	_lbl_estado.add_theme_color_override("font_color", Color("#93a0bd"))
	if not has_node("/root/API_Client"):
		_lbl_estado.text = "Cliente API no disponible"
		return
	get_node("/root/Sesion").configurar_servidor(_url())
	get_node("/root/API_Client").health()

func _on_salud(datos: Dictionary) -> void:
	var n := int(datos.get("niveles", 0))
	_lbl_estado.text = "Conectado · %d niveles disponibles" % n
	_lbl_estado.add_theme_color_override("font_color", OK_COLOR)

func _on_error(mensaje: String) -> void:
	_lbl_estado.text = "No se pudo conectar: " + mensaje
	_lbl_estado.add_theme_color_override("font_color", MAL_COLOR)

func _url() -> String:
	var url := _lineedit.text.strip_edges()
	return URL_POR_DEFECTO if url.is_empty() else url

func _guardar() -> void:
	if has_node("/root/Sesion"):
		get_node("/root/Sesion").configurar_servidor(_url())
	guardado.emit(_url())
	_cerrar()

func _cerrar() -> void:
	queue_free()
