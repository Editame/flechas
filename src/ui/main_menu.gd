extends Control

## Menu principal: un solo modo (ir pasando niveles).
## El nivel y su dificultad los decide juego.gd; aqui solo se arranca.

func _ready() -> void:
	_refrescar_textos()
	$Header/Config.pressed.connect(_abrir_config)
	$Header/Opciones.pressed.connect(_abrir_ajustes)
	$Centro/Jugar.pressed.connect(_jugar)

func _refrescar_textos() -> void:
	$Titulo.text = "Flechas"
	$Centro/Jugar.text = "Jugar"
	if has_node("Version"):
		$Version.text = Version.etiqueta()
	var nivel := 1
	if has_node("/root/Progreso"):
		nivel = get_node("/root/Progreso").nivel_actual
	$Centro/Jugar.text = "Jugar  ·  Nivel %d" % nivel
	if has_node("/root/Progreso"):
		var p = get_node("/root/Progreso")
		$Sub.text = "Nivel máximo %d  ·  %d estrellas" % [p.nivel_maximo, p.estrellas_totales]
	else:
		$Sub.text = ""

func _abrir_config() -> void:
	var modal = load("res://src/ui/modal_config_servidor.tscn").instantiate()
	modal.guardado.connect(func(u):
		if has_node("/root/Sesion"):
			get_node("/root/Sesion").configurar_servidor(u))
	add_child(modal)

func _abrir_ajustes() -> void:
	get_tree().change_scene_to_file("res://src/ui/ajustes.tscn")

func _jugar() -> void:
	var nivel := 1
	if has_node("/root/Progreso"):
		nivel = get_node("/root/Progreso").nivel_actual
	if has_node("/root/Sesion"):
		var sesion = get_node("/root/Sesion")
		sesion.nivel_actual = nivel
		sesion.nivel_actual_id = ""
	get_tree().change_scene_to_file("res://src/game/juego.tscn")
