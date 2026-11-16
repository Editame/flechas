extends VBoxContainer

## ConfiguraciÃ³n de la URL del servidor de generaciÃ³n de niveles.
## Se guarda en user://server_config.cfg para persistencia.

signal guardado(url: String)

@onready var _lineedit = $VBox/LineEditURL
@onready var _btn_guardar = $VBox/Botones/BtnGuardar
@onready var _btn_cancelar = $VBox/Botones/BtnCancelar

const RUTA_CONFIG := "user://server_config.cfg"

func _ready() -> void:
	cargar_configuracion()
	
	_btn_guardar.pressed.connect(_guardar)
	_btn_cancelar.pressed.connect(_cancelar)
	
	if has_node("Atras"):
		$Atras.pressed.connect(_cancelar)

func cargar_configuracion() -> void:
	var config = ConfigFile.new()
	if config.load(RUTA_CONFIG) == OK:
		var url = config.get_value("server", "url", "http://127.0.0.1:8077/flechas/v1")
		_lineedit.text = url

func _guardar() -> void:
	var url = _lineedit.text.strip_edges()
	if url.is_empty():
		url = "http://127.0.0.1:8077/flechas/v1"
	
	var config = ConfigFile.new()
	config.set_value("server", "url", url)
	config.save(RUTA_CONFIG)
	
	emit_signal("guardado", url)
	_cancelar()

func _cancelar() -> void:
	if has_node("/root/Sesion"):
		get_node("/root/Sesion").configurar_servidor(_lineedit.text.strip_edges())
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
