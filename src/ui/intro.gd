extends Control

## Pantalla de historia (primera vez / "Nuestra historia" en Ajustes).

func _ready() -> void:
	var t := Config.tema
	Tema.aplicar(t)
	$Fondo.color = Tema.fondo(t)
	$Panel/VBox/Header/Marca.add_theme_color_override("font_color", Tema.texto(t))
	$Panel/VBox/Titulo.add_theme_color_override("font_color", Tema.texto(t))
	for nombre in ["P1", "P2", "P3", "P4", "P5"]:
		$Panel/VBox/Scroll/Texto.get_node(nombre).add_theme_color_override(
				"font_color", Tema.texto(t))
	$Panel/VBox/Firma.add_theme_color_override("font_color", Tema.texto_suave(t))
	Tema.estilizar_secundario($Panel/VBox/Header/Saltar, t)
	Tema.estilizar_secundario($Panel/VBox/Sugerencias, t)
	$Panel/VBox/Header/Saltar.add_theme_font_size_override("font_size", 18)
	$Panel/VBox/Sugerencias.add_theme_font_size_override("font_size", 20)
	$Panel/VBox/Header/Saltar.pressed.connect(_entrar)
	$Panel/VBox/Entrar.pressed.connect(_entrar)
	$Panel/VBox/Sugerencias.pressed.connect(_sugerencias)

func _entrar() -> void:
	if has_node("/root/Config"):
		get_node("/root/Config").set_intro_vista(true)
	get_tree().change_scene_to_file("res://src/ui/hub.tscn")

func _sugerencias() -> void:
	var base := "http://127.0.0.1:8077/flechas/v1"
	if has_node("/root/API_Client"):
		base = get_node("/root/API_Client").url_base()
	OS.shell_open(base + "/static/sugerencias.html")
