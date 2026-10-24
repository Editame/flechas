extends Control

## Menú principal: un solo modo (infinito). Botón "Jugar" que continúa desde el
## nivel guardado. Header con opciones. Muestra nivel máximo alcanzado.

func _ready() -> void:
	_refrescar_textos()
	$Header/Opciones.pressed.connect(_abrir_ajustes)
	$Centro/Jugar.pressed.connect(_jugar)

func _refrescar_textos() -> void:
	$Titulo.text = I18n.t("app_titulo")
	$Header/Opciones.text = "⚙"
	# Versión desde la fuente única (project.godot), no escrita a mano: así no
	# puede quedar desincronizada con el build instalado.
	if has_node("Version"):
		$Version.text = Version.etiqueta()
	var nivel := 1
	if has_node("/root/Progreso"):
		nivel = get_node("/root/Progreso").nivel_actual
	$Centro/Jugar.text = "▶  %s %d" % [I18n.t("jugar_nivel"), nivel]
	# Subtítulo: progreso alcanzado.
	if has_node("/root/Progreso"):
		var p = get_node("/root/Progreso")
		$Sub.text = "%s %d  ·  ★ %d" % [I18n.t("nivel"), p.nivel_maximo, p.estrellas_totales]
	else:
		$Sub.text = ""

func _abrir_ajustes() -> void:
	get_tree().change_scene_to_file("res://src/ui/ajustes.tscn")

func _jugar() -> void:
	var nivel := 1
	if has_node("/root/Progreso"):
		nivel = get_node("/root/Progreso").nivel_actual
	if has_node("/root/Sesion"):
		get_node("/root/Sesion").nivel_actual = nivel
	get_tree().change_scene_to_file("res://src/game/juego.tscn")
