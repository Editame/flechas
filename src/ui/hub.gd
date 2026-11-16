extends Control

## Hub de Editame: lee src/games/catalogo.json y dibuja una tarjeta por juego.
## Tipos: "godot" (escena), "externo" (url/paquete) y "pronto" (placeholder).

func _ready() -> void:
	$Contenido/Header/Ajustes.pressed.connect(_abrir_ajustes)
	if has_node("/root/Config"):
		get_node("/root/Config").cambiado.connect(_refrescar_tema)
	if has_node("/root/ProgresoFlechas"):
		get_node("/root/ProgresoFlechas").actualizado.connect(_refrescar_tema)
	_refrescar_tema()

func _refrescar_tema() -> void:
	var t := Config.tema
	Tema.aplicar(t)
	$Fondo.color = Tema.fondo(t)
	Tema.estilizar_secundario($Contenido/Header/Ajustes, t)
	$Contenido/Header/Ajustes.add_theme_font_size_override("font_size", 24)
	$Contenido/Header/Titulo.add_theme_color_override("font_color", Tema.texto(t))
	$Contenido/Sub.add_theme_color_override("font_color", Tema.texto_suave(t))
	$Contenido/Pie/Marca.add_theme_color_override("font_color", Tema.texto(t))
	$Contenido/Pie/Version.add_theme_color_override("font_color", Tema.texto_suave(t))
	$Contenido/Pie/Version.text = Version.etiqueta()
	_construir_juegos()

func _construir_juegos() -> void:
	var grid: GridContainer = $Contenido/JuegosCentro/Juegos
	grid.columns = 2 if size.x >= 700.0 else 1
	for hijo in grid.get_children():
		hijo.free()
	for juego in _leer_catalogo():
		var tipo := str(juego.get("tipo", "pronto"))
		if tipo == "pronto":
			grid.add_child(_crear_placeholder(juego))
		else:
			grid.add_child(_crear_tarjeta(juego))

func _leer_catalogo() -> Array:
	var ruta := "res://src/games/catalogo.json"
	if not FileAccess.file_exists(ruta):
		return []
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return []
	return data.get("juegos", [])

func _crear_tarjeta(juego: Dictionary) -> Button:
	var id := str(juego.get("id", ""))
	var titulo := str(juego.get("titulo", "Juego"))
	var desc := str(juego.get("descripcion", ""))
	var fondo := Color(str(juego.get("fondo", "#241a3d")))
	var acento := Color(str(juego.get("acento", "#ffb703")))
	var texto := Color(str(juego.get("texto", "#fff4e6")))
	var suave := Color(str(juego.get("suave", "#c9b8e8")))

	var b := Button.new()
	b.custom_minimum_size = Vector2(330, 220)
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = fondo
	normal.border_color = Color(acento.r, acento.g, acento.b, 0.75)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(26)
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 14
	normal.shadow_offset = Vector2(0, 6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fondo.lightened(0.07)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_abrir_juego.bind(juego))

	var deco := Label.new()
	deco.text = "→"
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.offset_right = -14.0
	deco.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	deco.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deco.add_theme_font_size_override("font_size", 140)
	deco.add_theme_color_override("font_color", Color(acento.r, acento.g, acento.b, 0.13))
	b.add_child(deco)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 20)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	margen.add_child(v)
	b.add_child(margen)

	var etq := Label.new()
	etq.text = "JUEGO"
	if id == "flechas":
		etq.text = "FLECHAS"
	etq.add_theme_font_size_override("font_size", 14)
	etq.add_theme_color_override("font_color", acento)
	etq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(etq)

	var tit := Label.new()
	tit.text = titulo
	tit.add_theme_font_size_override("font_size", 34)
	tit.add_theme_color_override("font_color", texto)
	tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tit)

	var sub := Label.new()
	if id == "flechas" and has_node("/root/ProgresoFlechas"):
		var p = get_node("/root/ProgresoFlechas")
		sub.text = "Nivel %d  ·  %d estrellas" % [p.nivel_actual, p.estrellas_totales]
	else:
		sub.text = desc
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", suave)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sub)

	var esp := Control.new()
	esp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	esp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(esp)

	var pie := HBoxContainer.new()
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jugar := Label.new()
	jugar.text = "Jugar" if str(juego.get("tipo", "godot")) == "godot" else "Abrir"
	jugar.add_theme_font_size_override("font_size", 18)
	jugar.add_theme_color_override("font_color", texto)
	jugar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.add_child(jugar)
	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.add_child(relleno)
	var flecha := Label.new()
	flecha.text = "→"
	flecha.add_theme_font_size_override("font_size", 22)
	flecha.add_theme_color_override("font_color", acento)
	flecha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.add_child(flecha)
	v.add_child(pie)
	return b

func _crear_placeholder(juego: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(330, 220)
	var t := Config.tema
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tema.panel_2(t)
	sb.border_color = Tema.linea(t)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(26)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var mas := Label.new()
	mas.text = "+"
	mas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mas.add_theme_font_size_override("font_size", 56)
	mas.add_theme_color_override("font_color", Tema.texto_suave(t))
	v.add_child(mas)
	var prx := Label.new()
	prx.text = "PRÓXIMAMENTE"
	prx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prx.add_theme_font_size_override("font_size", 14)
	prx.add_theme_color_override("font_color", Tema.texto_suave(t))
	v.add_child(prx)
	var otro := Label.new()
	otro.text = str(juego.get("descripcion", "Otro juego en camino."))
	otro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	otro.add_theme_font_size_override("font_size", 14)
	otro.add_theme_color_override("font_color", Tema.texto_suave(t))
	v.add_child(otro)
	return p

func _abrir_juego(juego: Dictionary) -> void:
	var tipo := str(juego.get("tipo", "godot"))
	if tipo == "externo":
		var url := str(juego.get("url", ""))
		if url.is_empty() and not str(juego.get("paquete", "")).is_empty():
			url = "https://play.google.com/store/apps/details?id=" + str(juego.get("paquete"))
		if not url.is_empty():
			OS.shell_open(url)
		return
	var escena := str(juego.get("escena", ""))
	if not escena.is_empty():
		get_tree().change_scene_to_file(escena)

func _abrir_ajustes() -> void:
	get_tree().change_scene_to_file("res://src/ui/ajustes.tscn")
