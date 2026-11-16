extends Control

## Inicio: tarjeta grande del desafio diario, lista de niveles y boton de jugar.

const MESES := ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN",
		"JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]

const DIARIO_FONDO := Color("#241a3d")
const DIARIO_FONDO_2 := Color("#2e2150")
const DIARIO_ACENTO := Color("#ffb703")
const DIARIO_TEXTO := Color("#fff4e6")
const DIARIO_SUAVE := Color("#c9b8e8")

func _ready() -> void:
	$Contenido/Header/Ajustes.pressed.connect(_abrir_ajustes)
	$Contenido/Jugar.pressed.connect(_jugar)
	$Contenido/Diario.pressed.connect(_abrir_diario)
	_construir_diario()
	_construir_stats()
	if has_node("/root/Config"):
		get_node("/root/Config").cambiado.connect(_refrescar_tema)
	if has_node("/root/Progreso"):
		get_node("/root/Progreso").actualizado.connect(_actualizar_menu)
	_refrescar_tema()

func _refrescar_tema() -> void:
	var t := Config.tema
	Tema.aplicar(t)
	$Fondo.color = Tema.fondo(t)
	Tema.estilizar_secundario($Contenido/Header/Ajustes, t)
	$Contenido/Header/Ajustes.add_theme_font_size_override("font_size", 24)
	$Contenido/Header/Titulo.add_theme_color_override("font_color", Tema.texto(t))
	$Contenido/Sub.add_theme_color_override("font_color", Tema.texto_suave(t))
	$Contenido/NivelesTitulo.add_theme_color_override("font_color", Tema.texto_suave(t))
	$Contenido/Pie/Marca.add_theme_color_override("font_color", Tema.texto(t))
	$Contenido/Pie/Version.add_theme_color_override("font_color", Tema.texto_suave(t))
	$Contenido/Consejo/Texto.add_theme_color_override("font_color", Tema.texto_suave(t))
	_estilar_diario()
	_estilar_stats()
	for i in 3:
		var v: VBoxContainer = $Contenido/Stats/Centro/HBox.get_child(i)
		(v.get_node("Valor") as Label).add_theme_color_override("font_color", Tema.texto(t))
		(v.get_node("Etiqueta") as Label).add_theme_color_override("font_color", Tema.texto_suave(t))
	_actualizar_menu()

func _estilar_diario() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = DIARIO_FONDO
	normal.border_color = Color(DIARIO_ACENTO.r, DIARIO_ACENTO.g, DIARIO_ACENTO.b, 0.75)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(28)
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 16
	normal.shadow_offset = Vector2(0, 8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = DIARIO_FONDO_2
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = DIARIO_FONDO.darkened(0.1)
	$Contenido/Diario.add_theme_stylebox_override("normal", normal)
	$Contenido/Diario.add_theme_stylebox_override("hover", hover)
	$Contenido/Diario.add_theme_stylebox_override("pressed", pressed)
	$Contenido/Diario.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _construir_diario() -> void:
	if $Contenido/Diario.get_child_count() > 0:
		return
	var deco := Label.new()
	deco.name = "Deco"
	deco.text = "★"
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.offset_right = -18.0
	deco.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	deco.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deco.add_theme_font_size_override("font_size", 150)
	deco.add_theme_color_override("font_color", Color(1.0, 0.72, 0.01, 0.12))
	$Contenido/Diario.add_child(deco)

	var margen := MarginContainer.new()
	margen.name = "Margen"
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 22)
	$Contenido/Diario.add_child(margen)

	var v := VBoxContainer.new()
	v.name = "VBox"
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	margen.add_child(v)

	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var etq := Label.new()
	etq.name = "Etiqueta"
	etq.text = "DESAFÍO DIARIO"
	etq.add_theme_font_size_override("font_size", 14)
	etq.add_theme_color_override("font_color", DIARIO_ACENTO)
	etq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(etq)
	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(relleno)
	var hoy := Label.new()
	hoy.name = "Hoy"
	hoy.text = "HOY"
	hoy.add_theme_font_size_override("font_size", 13)
	hoy.add_theme_color_override("font_color", Color(1.0, 0.72, 0.01, 0.85))
	hoy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(hoy)
	v.add_child(fila)

	var dia := Label.new()
	dia.name = "Dia"
	dia.text = "16 NOV"
	dia.add_theme_font_size_override("font_size", 42)
	dia.add_theme_color_override("font_color", DIARIO_TEXTO)
	dia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(dia)

	var frase := Label.new()
	frase.name = "Frase"
	frase.text = "Un nivel nuevo cada día"
	frase.add_theme_font_size_override("font_size", 16)
	frase.add_theme_color_override("font_color", DIARIO_SUAVE)
	frase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(frase)

	var espacio := Control.new()
	espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(espacio)

	var pie := HBoxContainer.new()
	pie.name = "Pie"
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estrellas := Label.new()
	estrellas.name = "Estrellas"
	estrellas.text = "Sin jugar hoy"
	estrellas.add_theme_font_size_override("font_size", 18)
	estrellas.add_theme_color_override("font_color", DIARIO_ACENTO)
	estrellas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.add_child(estrellas)
	var relleno2 := Control.new()
	relleno2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relleno2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.add_child(relleno2)
	var ir := Label.new()
	ir.name = "Ir"
	ir.text = "Jugar  →"
	ir.add_theme_font_size_override("font_size", 20)
	ir.add_theme_color_override("font_color", DIARIO_TEXTO)
	ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.add_child(ir)
	v.add_child(pie)

func _actualizar_menu() -> void:
	$Contenido/Pie/Version.text = Version.etiqueta()
	var nivel := 1
	var maximo := 1
	var total_estrellas := 0
	if has_node("/root/Progreso"):
		var p = get_node("/root/Progreso")
		nivel = p.nivel_actual
		maximo = p.nivel_maximo
		total_estrellas = p.estrellas_totales
		_set_stat(0, str(p.niveles_resueltos), I18n.t("est_niveles"))
		_set_stat(1, str(p.perfectos), I18n.t("est_perfectos"))
		_set_stat(2, _formato_tiempo(p.tiempo_total_seg), I18n.t("est_tiempo"))
	$Contenido/Sub.text = "Nivel máximo %d  ·  %d estrellas" % [maximo, total_estrellas]
	$Contenido/Jugar.text = "Jugar  ·  Nivel %d" % nivel
	_actualizar_diario()
	_construir_niveles(nivel)

func _construir_stats() -> void:
	if $Contenido/Stats.get_child_count() > 0:
		return
	var centro := CenterContainer.new()
	centro.name = "Centro"
	var h := HBoxContainer.new()
	h.name = "HBox"
	h.add_theme_constant_override("separation", 18)
	for clave in ["niveles", "perfectos", "tiempo"]:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var valor := Label.new()
		valor.name = "Valor"
		valor.text = "0"
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		valor.add_theme_font_size_override("font_size", 26)
		var etq := Label.new()
		etq.name = "Etiqueta"
		etq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etq.add_theme_font_size_override("font_size", 13)
		v.add_child(valor)
		v.add_child(etq)
		h.add_child(v)
	centro.add_child(h)
	$Contenido/Stats.add_child(centro)

func _estilar_stats() -> void:
	var t := Config.tema
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tema.panel(t)
	sb.border_color = Tema.linea(t)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(16)
	$Contenido/Stats.add_theme_stylebox_override("panel", sb)

func _set_stat(i: int, valor: String, etiqueta: String) -> void:
	var v: VBoxContainer = $Contenido/Stats/Centro/HBox.get_child(i)
	(v.get_node("Valor") as Label).text = valor
	(v.get_node("Etiqueta") as Label).text = etiqueta

func _formato_tiempo(seg: float) -> String:
	var mins := int(seg / 60.0)
	if mins >= 60:
		return "%dh %02dm" % [int(mins / 60.0), mins % 60]
	return "%d min" % mins

func _actualizar_diario() -> void:
	var fecha := _fecha_hoy()
	var dia := int(fecha.substr(8, 2))
	var mes: String = MESES[int(fecha.substr(5, 2)) - 1]
	$Contenido/Diario/Margen/VBox/Dia.text = "%d %s" % [dia, mes]
	var hechas := 0
	if has_node("/root/Progreso"):
		hechas = get_node("/root/Progreso").diario_estrellas(fecha)
	var estrellas: Label = $Contenido/Diario/Margen/VBox/Pie/Estrellas
	if hechas > 0:
		estrellas.text = _texto_estrellas(hechas)
	else:
		estrellas.text = "Sin jugar hoy"

func _texto_estrellas(n: int) -> String:
	var s := ""
	for i in 3:
		s += "★" if i < n else "☆"
	return s

func _construir_niveles(nivel: int) -> void:
	for hijo in $Contenido/Niveles.get_children():
		hijo.free()
	var t := Config.tema
	for i in 6:
		var n := nivel + i
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 88)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tema.panel_2(t)
		sb.set_corner_radius_all(18)
		sb.border_color = Tema.acento(t) if i == 0 else Tema.linea(t)
		sb.set_border_width_all(2 if i == 0 else 1)
		if i == 0:
			sb.shadow_color = Color(Tema.acento(t).r, Tema.acento(t).g, Tema.acento(t).b, 0.25)
			sb.shadow_size = 8
		panel.add_theme_stylebox_override("panel", sb)
		var lbl := Label.new()
		lbl.text = str(n)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color",
				Tema.texto(t) if i == 0 else Tema.texto_suave(t))
		panel.add_child(lbl)
		$Contenido/Niveles.add_child(panel)

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
