extends Control

## Ajustes de inicio: idioma, tema, sonido, vibración, efectos.

func _ready() -> void:
	_refrescar_textos()
	$Panel/VBox/Volver.pressed.connect(_volver)
	$Panel/VBox/FilaIdioma/OpIdioma.item_selected.connect(_cambiar_idioma)
	$Panel/VBox/FilaTema/OpTema.item_selected.connect(_cambiar_tema)
	$Panel/VBox/FSonido/Chk.toggled.connect(func(v): Config.set_sonido(v))
	$Panel/VBox/FVibracion/Chk.toggled.connect(func(v): Config.set_vibracion(v))
	$Panel/VBox/FEfectos/Chk.toggled.connect(func(v): Config.set_efectos(v))
	$Panel/VBox/Reiniciar.pressed.connect(func(): $Confirmar.popup_centered())
	$Confirmar.confirmed.connect(_reiniciar_progreso)

func _reiniciar_progreso() -> void:
	if has_node("/root/Progreso"):
		get_node("/root/Progreso").reiniciar_todo()
	_volver()   # vuelve al menú, que ya mostrará Nivel 1

func _refrescar_textos() -> void:
	$Panel/VBox/Titulo.text = I18n.t("ajustes")
	$Panel/VBox/FilaIdioma/Lbl.text = I18n.t("idioma")
	$Panel/VBox/FilaTema/Lbl.text = I18n.t("tema")
	$Panel/VBox/FSonido/Lbl.text = I18n.t("sonido")
	$Panel/VBox/FVibracion/Lbl.text = I18n.t("vibracion")
	$Panel/VBox/FEfectos/Lbl.text = I18n.t("efectos")
	$Panel/VBox/Reiniciar.text = I18n.t("reiniciar_progreso")
	$Panel/VBox/Volver.text = I18n.t("volver")
	$Confirmar.dialog_text = I18n.t("confirmar_reinicio")
	$Confirmar.ok_button_text = I18n.t("si")
	$Confirmar.cancel_button_text = I18n.t("no")

	var op_idi: OptionButton = $Panel/VBox/FilaIdioma/OpIdioma
	op_idi.clear()
	op_idi.add_item(I18n.t("espanol"), Config.Idioma.ES)
	op_idi.add_item(I18n.t("ingles"), Config.Idioma.EN)
	op_idi.select(Config.idioma)

	var op_tema: OptionButton = $Panel/VBox/FilaTema/OpTema
	op_tema.clear()
	op_tema.add_item(I18n.t("tema_azul"), Config.Tema.AZUL_OSCURO)
	op_tema.add_item(I18n.t("tema_colores"), Config.Tema.COLORES)
	op_tema.select(Config.tema)

	$Panel/VBox/FSonido/Chk.button_pressed = Config.sonido
	$Panel/VBox/FVibracion/Chk.button_pressed = Config.vibracion
	$Panel/VBox/FEfectos/Chk.button_pressed = Config.efectos

func _cambiar_idioma(idx: int) -> void:
	Config.set_idioma(idx)
	_refrescar_textos()

func _cambiar_tema(idx: int) -> void:
	Config.set_tema(idx)

func _volver() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
