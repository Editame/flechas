extends Control

## Menu principal: tarjetas de modos (Desafio diario + Clasico), boton de
## jugar y barra visual de proximos niveles.

const MESES := ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN",
		"JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]

const DIARIO_FONDO := Color("#241a3d")
const DIARIO_ACENTO := Color("#ffb703")
const DIARIO_TEXTO := Color("#fff4e6")

func _ready() -> void:
	$Ajustes.pressed.connect(_abrir_ajustes)
	$Jugar.pressed.connect(_jugar)
	if has_node("/root/Config"):
		get_node("/root/Config").cambiado.connect(_refrescar_tema)
	if has_node("/root/Progreso"):
		get_node("/root/Progreso").actualizado.connect(_actualizar_menu)
	_refrescar_tema()

## Aplica el tema visual elegido y refresca los datos del menu.
func _refrescar_tema() -> void:
	var t := Config.tema
	Tema.aplicar(t)
	if has_node("Fondo"):
		$Fondo.color = Tema.fondo(t)
	Tema.estilizar_secundario($Ajustes, t)
	$Ajustes.add_theme_font_size_override("font_size", 26)
	$Titulo.add_theme_color_override("font_color", Tema.texto(t))
	$Sub.add_theme_color_override("font_color", Tema.texto_suave(t))
	$ProximosTitulo.add_theme_color_override("font_color", Tema.texto_suave(t))
	$Marca.add_theme_color_override("font_color", Tema.texto(t))
	$Version.add_theme_color_override("font_color", Tema.texto_suave(t))
	_actualizar_menu()

func _actualizar_menu() -> void:
	if has_node("Version"):
		$Version.text = Version.etiqueta()
	var nivel := 1
	var maximo := 1
	var estrellas := 0
	if has_node("/root/Progreso"):
		var p = get_node("/root/Progreso")
		nivel = p.nivel_actual
		maximo = p.nivel_maximo
		estrellas = p.estrellas_totales
	$Sub.text = "Nivel máximo %d  ·  %d estrellas" % [maximo, estrellas]
	$Jugar.text = "Jugar  ·  Nivel %d" % nivel
	_construir_tarjetas(nivel)
	_construir_proximos(nivel)

func _construir_tarjetas(nivel: int) -> void:
	for hijo in $ModosScroll/Modos.get_children():
		hijo.free()
	var t := Config.tema
	var fecha := _fecha_hoy()
	var dia := int(fecha.substr(8, 2))
	var mes: String = MESES[int(fecha.substr(5, 2)) - 1]
	var pie_diario := "Sin jugar hoy"
	var hechas := 0
	if has_node("/root/Progreso"):
		hechas = get_node("/root/Progreso").diario_estrellas(fecha)
	if hechas > 0:
		pie_diario = "%d/3 estrellas" % hechas
	var diaria := _crear_tarjeta("DESAFÍO DIARIO", "%d %s" % [dia, mes], pie_diario,
			DIARIO_FONDO, DIARIO_ACENTO, _abrir_diario)
	$ModosScroll/Modos.add_child(diaria)
	var clasica := _crear_tarjeta("CLÁSICO", "Nivel %d" % nivel, "Sigue avanzando",
			Tema.panel_2(t), Tema.acento(t), _jugar)
	$ModosScroll/Modos.add_child(clasica)

func _crear_tarjeta(etiqueta: String, titulo: String, pie: String,
		fondo: Color, acento: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(252, 188)
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = fondo
	normal.border_color = Color(acento.r, acento.g, acento.b, 0.55)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(26)
	normal.shadow_color = Color(0, 0, 0, 0.30)
	normal.shadow_size = 12
	normal.shadow_offset = Vector2(0, 6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fondo.lightened(0.07)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 18)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(v)
	b.add_child(margen)

	var l_etq := Label.new()
	l_etq.text = etiqueta
	l_etq.add_theme_font_size_override("font_size", 14)
	l_etq.add_theme_color_override("font_color", acento)
	l_etq.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var l_tit := Label.new()
	l_tit.text = titulo
	l_tit.add_theme_font_size_override("font_size", 34)
	l_tit.add_theme_color_override("font_color", DIARIO_TEXTO if fondo == DIARIO_FONDO else Tema.texto(Config.tema))
	l_tit.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var espacio := Control.new()
	espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var l_pie := Label.new()
	l_pie.text = pie
	l_pie.add_theme_font_size_override("font_size", 16)
	l_pie.add_theme_color_override("font_color", acento)
	l_pie.mouse_filter = Control.MOUSE_FILTER_IGNORE

	v.add_child(l_etq)
	v.add_child(l_tit)
	v.add_child(espacio)
	v.add_child(l_pie)
	return b

func _construir_proximos(nivel: int) -> void:
	for hijo in $Proximos.get_children():
		hijo.free()
	var t := Config.tema
	for i in 5:
		var n := nivel + i
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(102, 72)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tema.panel_2(t)
		sb.set_corner_radius_all(16)
		sb.border_color = Tema.acento(t) if i == 0 else Tema.linea(t)
		sb.set_border_width_all(2 if i == 0 else 1)
		panel.add_theme_stylebox_override("panel", sb)
		var lbl := Label.new()
		lbl.text = str(n)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color",
				Tema.texto(t) if i == 0 else Tema.texto_suave(t))
		panel.add_child(lbl)
		$Proximos.add_child(panel)

func _fecha_hoy() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

func _abrir_diario() -> void:
	get_tree().change_scene_to_file("res://src/ui/desafio_diario.tscn")

func _abrir_ajustes() -> void:
	get_tree().change_scene_to_file("res://src/ui/ajustes.tscn")

func _jugar() -> void:
	var nivel := 1
	if has_node("/root/Progreso"):
		nivel = get_node("/root/Progreso").nivel_actual
	if has_node("/root/Sesion"):
		var sesion = get_node("/root/Sesion")
		sesion.modo = "clasico"
		sesion.fecha_diaria = ""
		sesion.nivel_actual = nivel
		sesion.nivel_actual_id = ""
	get_tree().change_scene_to_file("res://src/game/juego.tscn")
