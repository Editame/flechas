extends Control

## Ajustes: apariencia, sonido, cuenta, legal y (si la bandera esta activa)
## configuracion del servidor.

func _ready() -> void:
	Tema.aplicar(Config.tema)
	$Fondo.color = Tema.fondo(Config.tema)
	_refrescar_textos()
	$Panel/VBox/Volver.pressed.connect(_volver)
	$Panel/VBox/Scroll/Contenido/FilaIdioma/OpIdioma.item_selected.connect(_cambiar_idioma)
	$Panel/VBox/Scroll/Contenido/FilaTema/OpTema.item_selected.connect(_cambiar_tema)
	$Panel/VBox/Scroll/Contenido/FSonido/Chk.toggled.connect(func(v): Config.set_sonido(v))
	$Panel/VBox/Scroll/Contenido/FVibracion/Chk.toggled.connect(func(v): Config.set_vibracion(v))
	$Panel/VBox/Scroll/Contenido/FEfectos/Chk.toggled.connect(func(v): Config.set_efectos(v))
	$Panel/VBox/Scroll/Contenido/BtnGuardar.pressed.connect(_proximamente.bind("guardar_progreso"))
	$Panel/VBox/Scroll/Contenido/BtnTerminos.pressed.connect(_proximamente.bind("terminos"))
	$Panel/VBox/Scroll/Contenido/BtnPrivacidad.pressed.connect(_proximamente.bind("privacidad"))
	$Panel/VBox/Scroll/Contenido/BtnServidor.pressed.connect(_abrir_servidor)
	$Panel/VBox/Scroll/Contenido/Reiniciar.pressed.connect(func(): $Confirmar.popup_centered())
	$Confirmar.confirmed.connect(_reiniciar_progreso)

func _reiniciar_progreso() -> void:
	if has_node("/root/Progreso"):
		get_node("/root/Progreso").reiniciar_todo()
	_volver()

func _refrescar_textos() -> void:
	$Panel/VBox/Titulo.text = I18n.t("ajustes")
	$Panel/VBox/Scroll/Contenido/SecApariencia.text = I18n.t("apariencia")
	$Panel/VBox/Scroll/Contenido/FilaIdioma/Lbl.text = I18n.t("idioma")
	$Panel/VBox/Scroll/Contenido/FilaTema/Lbl.text = I18n.t("tema")
	$Panel/VBox/Scroll/Contenido/SecSonido.text = I18n.t("sonido")
	$Panel/VBox/Scroll/Contenido/FSonido/Lbl.text = I18n.t("sonido")
	$Panel/VBox/Scroll/Contenido/FVibracion/Lbl.text = I18n.t("vibracion")
	$Panel/VBox/Scroll/Contenido/FEfectos/Lbl.text = I18n.t("efectos")
	$Panel/VBox/Scroll/Contenido/SecCuenta.text = I18n.t("cuenta_seccion")
	$Panel/VBox/Scroll/Contenido/BtnGuardar.text = I18n.t("guardar_progreso")
	$Panel/VBox/Scroll/Contenido/SecLegal.text = I18n.t("legal")
	$Panel/VBox/Scroll/Contenido/BtnTerminos.text = I18n.t("terminos")
	$Panel/VBox/Scroll/Contenido/BtnPrivacidad.text = I18n.t("privacidad")
	$Panel/VBox/Scroll/Contenido/SecAvanzado.text = I18n.t("avanzado")
	$Panel/VBox/Scroll/Contenido/BtnServidor.text = I18n.t("servidor")
	$Panel/VBox/Scroll/Contenido/Reiniciar.text = I18n.t("reiniciar_progreso")
	$Panel/VBox/Volver.text = I18n.t("volver")
	$Confirmar.dialog_text = I18n.t("confirmar_reinicio")
	$Confirmar.ok_button_text = I18n.t("si")
	$Confirmar.cancel_button_text = I18n.t("no")

	$Panel/VBox/Scroll/Contenido/BtnServidor.visible = Features.servidor_visible()
	$Panel/VBox/Scroll/Contenido/SecAvanzado.visible = Features.servidor_visible()

	for seccion in ["SecApariencia", "SecSonido", "SecCuenta", "SecLegal", "SecAvanzado"]:
		if has_node("Panel/VBox/Scroll/Contenido/" + seccion):
			get_node("Panel/VBox/Scroll/Contenido/" + seccion).add_theme_color_override(
					"font_color", Tema.texto_suave(Config.tema))

	for fila in ["BtnGuardar", "BtnTerminos", "BtnPrivacidad", "BtnServidor", "Reiniciar"]:
		if has_node("Panel/VBox/Scroll/Contenido/" + fila):
			Tema.estilizar_secundario(get_node("Panel/VBox/Scroll/Contenido/" + fila), Config.tema)

	var op_idi: OptionButton = $Panel/VBox/Scroll/Contenido/FilaIdioma/OpIdioma
	op_idi.set_block_signals(true)
	op_idi.clear()
	op_idi.add_item(I18n.t("espanol"), Config.Idioma.ES)
	op_idi.add_item(I18n.t("ingles"), Config.Idioma.EN)
	op_idi.select(Config.idioma)
	op_idi.set_block_signals(false)

	var op_tema: OptionButton = $Panel/VBox/Scroll/Contenido/FilaTema/OpTema
	op_tema.set_block_signals(true)
	op_tema.clear()
	op_tema.add_item(I18n.t("tema_neon"), 0)
	op_tema.add_item(I18n.t("tema_cristal"), 1)
	op_tema.add_item(I18n.t("tema_pizarra"), 2)
	op_tema.add_item(I18n.t("tema_amanecer"), 3)
	op_tema.select(Config.tema)
	op_tema.set_block_signals(false)

	$Panel/VBox/Scroll/Contenido/FSonido/Chk.button_pressed = Config.sonido
	$Panel/VBox/Scroll/Contenido/FVibracion/Chk.button_pressed = Config.vibracion
	$Panel/VBox/Scroll/Contenido/FEfectos/Chk.button_pressed = Config.efectos

func _cambiar_idioma(idx: int) -> void:
	Config.set_idioma(idx)
	_refrescar_textos()

func _cambiar_tema(idx: int) -> void:
	Config.set_tema(idx)
	$Fondo.color = Tema.fondo(Config.tema)

func _abrir_servidor() -> void:
	var modal = load("res://src/ui/modal_config_servidor.tscn").instantiate()
	modal.guardado.connect(func(u):
		if has_node("/root/Sesion"):
			get_node("/root/Sesion").configurar_servidor(u))
	add_child(modal)

func _proximamente(clave: String) -> void:
	var d := AcceptDialog.new()
	d.title = I18n.t(clave)
	d.dialog_text = I18n.t("proximamente_texto")
	d.ok_button_text = "OK"
	add_child(d)
	d.popup_centered(Vector2i(420, 160))

func _volver() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
