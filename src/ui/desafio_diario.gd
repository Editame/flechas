extends Control

## Desafio diario: calendario del mes. Cada dia tiene un nivel aleatorio
## (semilla = fecha) y solo el dia de hoy se puede jugar.

const FONDO := Color("#1a1330")
const PANEL := Color("#241a3d")
const PANEL2 := Color("#2f2350")
const TEXTO := Color("#fff4e6")
const SUAVE := Color("#b9a8d8")
const ORO := Color("#ffb703")
const OK := Color("#3ddc97")

const MESES := ["ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO",
		"JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"]
const DIAS := ["L", "M", "X", "J", "V", "S", "D"]

var _anio: int = 2026
var _mes: int = 1

func _ready() -> void:
	var hoy := Time.get_date_dict_from_system()
	_anio = int(hoy["year"])
	_mes = int(hoy["month"])
	$Fondo.color = FONDO
	_estilizar()
	$Header/Atras.pressed.connect(_volver)
	$Panel/VBox/Mes/BtnPrev.pressed.connect(_cambiar_mes.bind(-1))
	$Panel/VBox/Mes/BtnNext.pressed.connect(_cambiar_mes.bind(1))
	$Panel/VBox/BtnHoy.pressed.connect(_jugar)
	_construir()

func _estilizar() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = PANEL2
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 18
	$Panel.add_theme_stylebox_override("panel", sb)
	for b in [$Header/Atras, $Panel/VBox/Mes/BtnPrev, $Panel/VBox/Mes/BtnNext]:
		(_estilizar_boton(b, PANEL2, PANEL, TEXTO, 18))
	$Panel/VBox/BtnHoy.add_theme_stylebox_override("normal", _caja(ORO, ORO, 22))
	var hover := _caja(ORO.lightened(0.12), ORO, 22)
	$Panel/VBox/BtnHoy.add_theme_stylebox_override("hover", hover)
	$Panel/VBox/BtnHoy.add_theme_stylebox_override("pressed", _caja(ORO.darkened(0.12), ORO, 22))
	$Panel/VBox/BtnHoy.add_theme_color_override("font_color", Color("#241a3d"))
	$Panel/VBox/BtnHoy.add_theme_color_override("font_hover_color", Color("#241a3d"))
	$Panel/VBox/BtnHoy.add_theme_color_override("font_pressed_color", Color("#241a3d"))
	$Panel/VBox/Mes/MesLabel.add_theme_color_override("font_color", TEXTO)
	$Panel/VBox/Estado.add_theme_color_override("font_color", ORO)

func _estilizar_boton(b: Button, fondo: Color, borde: Color, texto: Color, radio: int) -> void:
	b.add_theme_stylebox_override("normal", _caja(fondo, borde, radio))
	b.add_theme_stylebox_override("hover", _caja(fondo.lightened(0.08), borde, radio))
	b.add_theme_stylebox_override("pressed", _caja(fondo.darkened(0.08), borde, radio))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", texto)
	b.add_theme_color_override("font_hover_color", texto)
	b.add_theme_color_override("font_pressed_color", texto)

func _caja(fondo: Color, borde: Color, radio: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = borde
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radio)
	sb.content_margin_left = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 10.0
	sb.content_margin_bottom = 6.0
	return sb

func _construir() -> void:
	$Panel/VBox/Mes/MesLabel.text = "%s %d" % [MESES[_mes - 1], _anio]
	var hoy := Time.get_date_dict_from_system()
	var fecha_hoy := _fecha(int(hoy["year"]), int(hoy["month"]), int(hoy["day"]))
	var actual := _anio == int(hoy["year"]) and _mes == int(hoy["month"])
	$Panel/VBox/Mes/BtnNext.disabled = actual

	for hijo in $Panel/VBox/Semana.get_children():
		hijo.free()
	for hijo in $Panel/VBox/Dias.get_children():
		hijo.free()
	for d in DIAS:
		var l := Label.new()
		l.text = d
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", SUAVE)
		$Panel/VBox/Semana.add_child(l)

	var primero := Time.get_unix_time_from_datetime_dict(
			{"year": _anio, "month": _mes, "day": 1, "hour": 12, "minute": 0, "second": 0})
	var info := Time.get_datetime_dict_from_unix_time(int(primero))
	var offset := (int(info["weekday"]) + 6) % 7
	for i in offset:
		var hueco := Control.new()
		hueco.custom_minimum_size = Vector2(84, 62)
		$Panel/VBox/Dias.add_child(hueco)

	var total := _dias_del_mes(_anio, _mes)
	for dia in range(1, total + 1):
		var fecha := _fecha(_anio, _mes, dia)
		var hecho := false
		var estrellas := 0
		if has_node("/root/Progreso"):
			hecho = get_node("/root/Progreso").diario_hecho(fecha)
			estrellas = get_node("/root/Progreso").diario_estrellas(fecha)
		var b := Button.new()
		b.custom_minimum_size = Vector2(84, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%d ★" % dia if hecho else str(dia)
		b.add_theme_font_size_override("font_size", 20 if hecho else 22)
		if fecha == fecha_hoy:
			b.add_theme_stylebox_override("normal", _caja(ORO, ORO, 16))
			b.add_theme_stylebox_override("hover", _caja(ORO.lightened(0.12), ORO, 16))
			b.add_theme_stylebox_override("pressed", _caja(ORO.darkened(0.12), ORO, 16))
			b.add_theme_color_override("font_color", Color("#241a3d"))
			b.add_theme_color_override("font_hover_color", Color("#241a3d"))
			b.add_theme_color_override("font_pressed_color", Color("#241a3d"))
			b.pressed.connect(_jugar)
		else:
			var borde := OK if hecho else PANEL2
			b.add_theme_stylebox_override("normal", _caja(PANEL2, borde, 16))
			b.add_theme_stylebox_override("disabled", _caja(PANEL2, borde, 16))
			b.add_theme_color_override("font_color", TEXTO if hecho else SUAVE)
			b.add_theme_color_override("font_disabled_color", TEXTO if hecho else SUAVE)
			b.disabled = true
		$Panel/VBox/Dias.add_child(b)

	var hechas := 0
	if has_node("/root/Progreso"):
		hechas = get_node("/root/Progreso").diario_estrellas(fecha_hoy)
	$Panel/VBox/Estado.text = ("Hoy: %d/3 estrellas" % hechas) if hechas > 0 \
			else "Un nivel nuevo cada día"
	$Panel/VBox/BtnHoy.text = "Repetir el de hoy" if hechas > 0 else "Jugar el de hoy"

func _cambiar_mes(delta: int) -> void:
	var mes := _mes + delta
	var anio := _anio
	if mes < 1:
		mes = 12
		anio -= 1
	elif mes > 12:
		mes = 1
		anio += 1
	var hoy := Time.get_date_dict_from_system()
	if anio * 12 + mes > int(hoy["year"]) * 12 + int(hoy["month"]):
		return
	_anio = anio
	_mes = mes
	_construir()

func _jugar() -> void:
	var hoy := Time.get_date_dict_from_system()
	var anio := int(hoy["year"])
	var mes := int(hoy["month"])
	var dia := int(hoy["day"])
	if has_node("/root/Sesion"):
		var sesion = get_node("/root/Sesion")
		sesion.modo = "diario"
		sesion.fecha_diaria = _fecha(anio, mes, dia)
		sesion.dificultad_nivel = "medio"
		sesion.semilla_nivel = anio * 10000 + mes * 100 + dia
	get_tree().change_scene_to_file("res://src/game/juego.tscn")

func _volver() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")

func _fecha(anio: int, mes: int, dia: int) -> String:
	return "%04d-%02d-%02d" % [anio, mes, dia]

func _dias_del_mes(anio: int, mes: int) -> int:
	match mes:
		2:
			return 29 if _bisiesto(anio) else 28
		4, 6, 9, 11:
			return 30
	return 31

func _bisiesto(anio: int) -> bool:
	return (anio % 4 == 0 and anio % 100 != 0) or anio % 400 == 0
