extends VBoxContainer

## Selector de niveles que consume la API del servidor.
## Pide 5 niveles de las dificultades más altas (super y maximo) y los muestra.
## Al seleccionar uno, se carga en la escena de juego.

signal nivel_seleccionado(id: String)

@onready var _label_estado = $VBox/LabelEstado
@onready var _grid = $VBox/GridContainer
@onready var _panel_carga = $PanelCarga

var _niveles_cargados: Array = []
var _api_client: API_Client = null

func _ready() -> void:
	# Conectar al API client global
	if has_node("/root/API_Client"):
		_api_client = get_node("/root/API_Client")
		_api_client.respuesta.connect(_on_respuesta_api)
		_api_client.error.connect(_on_error_api)
	
	# Botón de atrás
	if has_node("Atras"):
		$Atras.pressed.connect(_ir_menu)
	
	# Cargar niveles desde la API
	cargar_niveles()

func _ir_menu() -> void:
	get_tree().change_scene_to_file("res://src/games/flechas/menu.tscn")

func cargar_niveles() -> void:
	_panel_carga.visible = true
	_grid.get_children().clear()
	_niveles_cargados.clear()
	
	var params = {
		"cantidad": 5,
		"dificultad": "super"  # Pedimos primero super, luego maximo si hace falta
	}
	
	if _api_client:
		_api_client.pedir_pool(params)

func _on_respuesta_api(data):
	_panel_carga.visible = false
	
	if not data.has("niveles") or data["niveles"].is_empty():
		_label_estado.text = "No se encontraron niveles de esta dificultad"
		return
	
	_niveles_cargados = data["niveles"]
	
	# Si necesitamos más niveles (mix de super y maximo)
	var super_count = 0
	for n in _niveles_cargados:
		if n.dificultad == "super":
			super_count += 1
	
	# Si tenemos menos de 5 y necesitamos más, pedir maximo
	if _niveles_cargados.size() < 5 and super_count < 5:
		var params2 = {
			"cantidad": 5,
			"dificultad": "maximo"
		}
		_api_client.pedir_pool(params2)

func _on_error_api(mensaje):
	_label_estado.text = "Error: " + mensaje
	_label_estado.add_theme_color_override("font_color", Color.RED)

func _on_grid_item_pressed(id: String) -> void:
	nivel_seleccionado.emit(id)
	get_tree().change_scene_to_file("res://src/games/flechas/juego.tscn")
