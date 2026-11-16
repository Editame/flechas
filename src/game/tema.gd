class_name Tema
extends RefCounted

## Tres temas visuales de la app (elegibles en Ajustes):
##   0  Neón sereno   base azul noche, malla de puntos + líneas, halo suave
##   1  Cristal       paneles translúcidos, flechas pastel, malla muy tenue
##   2  Pizarra       casi negro, sin líneas, 5 colores muy saturados
##
## Todo el dibujo y el chrome de la app consulta estas funciones con Config.tema.

const ROJO_COLISION := Color("#ff5d73")

## Paleta de flechas por tema.
const PALETAS: Array = [
	# 0 Neón sereno
	[
		Color("#5b8cff"), Color("#3ddc97"), Color("#ffc857"), Color("#ff7b9c"),
		Color("#b388ff"), Color("#4dd0e1"), Color("#f48fb1"), Color("#9ccc65"),
		Color("#ffab40"), Color("#80cbc4"), Color("#ce93d8"), Color("#90a4ae"),
	],
	# 1 Cristal (pastel)
	[
		Color("#8ab4ff"), Color("#7ee0c3"), Color("#ffd489"), Color("#ff9fb8"),
		Color("#c3a6ff"), Color("#86e3ef"), Color("#ffc1d4"), Color("#bfe38a"),
		Color("#ffc27a"), Color("#a9ded9"), Color("#e0b8ff"), Color("#b8c6d6"),
	],
	# 2 Pizarra (5 colores saturados)
	[
		Color("#ff4d6d"), Color("#ffb703"), Color("#3ddc97"), Color("#4cc9f0"),
		Color("#c77dff"),
	],
]

const NOMBRES := ["Neón sereno", "Cristal", "Pizarra"]

# ---------------------------------------------------------------------------
# Paleta / parámetros del tablero
# ---------------------------------------------------------------------------

static func normalizar(t: int) -> int:
	return clampi(t, 0, 2)

static func nombre(t: int) -> String:
	return NOMBRES[normalizar(t)]

static func fondo(t: int) -> Color:
	match normalizar(t):
		1: return Color("#0f1730")
		2: return Color("#05070c")
	return Color("#0b1020")

static func tablero(t: int) -> Color:
	match normalizar(t):
		1: return Color("#16223f")
		2: return Color("#090d15")
	return Color("#111a33")

static func panel(t: int) -> Color:
	match normalizar(t):
		1: return Color(0.12, 0.18, 0.32, 0.62)
		2: return Color("#0c1119")
	return Color("#131a2e")

static func panel_2(t: int) -> Color:
	match normalizar(t):
		1: return Color(0.16, 0.24, 0.42, 0.70)
		2: return Color("#141a24")
	return Color("#1a2340")

static func linea(t: int) -> Color:
	match normalizar(t):
		1: return Color(1, 1, 1, 0.16)
		2: return Color("#1a2230")
	return Color("#26314f")

static func texto(t: int) -> Color:
	match normalizar(t):
		1: return Color("#eef3ff")
		2: return Color("#f2f5fa")
	return Color("#e8edf7")

static func texto_suave(t: int) -> Color:
	match normalizar(t):
		1: return Color("#a8b8d8")
		2: return Color("#7f8b9e")
	return Color("#93a0bd")

static func acento(t: int) -> Color:
	match normalizar(t):
		1: return Color("#9ec1ff")
		2: return Color("#ffb703")
	return Color("#6c8cff")

static func paleta(t: int) -> Array:
	return PALETAS[normalizar(t)]

static func color_flecha(t: int, id: int) -> Color:
	var p: Array = paleta(t)
	return p[id % p.size()]

static func color_punto(t: int) -> Color:
	match normalizar(t):
		1: return Color(1, 1, 1, 0.16)
		2: return Color(1, 1, 1, 0.30)
	return Color(0.58, 0.66, 0.84, 0.20)

static func radio_punto(t: int) -> float:
	match normalizar(t):
		1: return 0.040
		2: return 0.050
	return 0.045

static func usa_malla(t: int) -> bool:
	return normalizar(t) != 2

static func color_malla(t: int) -> Color:
	if normalizar(t) == 1:
		return Color(1, 1, 1, 0.10)
	return Color(0.47, 0.57, 0.80, 0.10)

static func grosor(t: int) -> float:
	match normalizar(t):
		1: return 0.19
		2: return 0.17
	return 0.20

## Intensidad del halo detrás de cada flecha (0 = sin halo).
static func halo(t: int) -> float:
	match normalizar(t):
		1: return 0.09
		2: return 0.0
	return 0.16

# ---------------------------------------------------------------------------
# Tema de UI global (botones, paneles, textos)
# ---------------------------------------------------------------------------

static func aplicar(t: int) -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null:
		return
	arbol.root.theme = construir_theme(t)

static func construir_theme(t: int) -> Theme:
	var th := Theme.new()
	var regular: Font = load("res://assets/fonts/Poppins-Medium.ttf")
	var fuerte: Font = load("res://assets/fonts/Poppins-SemiBold.ttf")
	th.default_font = regular
	th.default_font_size = 30
	th.set_font("font", "Button", fuerte)
	th.set_font_size("font_size", "Button", 32)

	var ct := texto(t)
	var ct_boton := ct
	if normalizar(t) == 2:
		ct_boton = Color("#0b0f16")
	for clave in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(clave, "Button", ct_boton)
		th.set_color(clave, "OptionButton", ct_boton)
	th.set_color("font_color", "Label", ct)
	th.set_color("font_color", "CheckButton", ct)

	th.set_stylebox("normal", "Button", caja_boton(t, 0))
	th.set_stylebox("hover", "Button", caja_boton(t, 1))
	th.set_stylebox("pressed", "Button", caja_boton(t, 2))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_stylebox("panel", "PanelContainer", caja_panel(t))
	return th

static func caja_boton(t: int, estado: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = _fondo_boton(t, estado)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 22.0
	sb.content_margin_top = 15.0
	sb.content_margin_right = 22.0
	sb.content_margin_bottom = 15.0
	if normalizar(t) == 1:
		sb.set_border_width_all(1)
		sb.border_color = Color(1, 1, 1, 0.22)
	if normalizar(t) != 2 and estado == 0:
		var a := acento(t)
		sb.shadow_color = Color(a.r, a.g, a.b, 0.30)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 4)
	return sb

static func caja_panel(t: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel(t)
	sb.border_color = linea(t)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(24.0)
	if normalizar(t) == 1:
		sb.shadow_color = Color(1, 1, 1, 0.05)
		sb.shadow_size = 18
	return sb

## Estilo "secundario" para botones de icono/cabecera: fondo panel, borde línea.
static func estilizar_secundario(btn: Button, t: int) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = panel_2(t)
	normal.border_color = linea(t)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(18)
	normal.content_margin_left = 18.0
	normal.content_margin_top = 12.0
	normal.content_margin_right = 18.0
	normal.content_margin_bottom = 12.0

	var pulsado := normal.duplicate() as StyleBoxFlat
	pulsado.bg_color = panel(t)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pulsado)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", texto(t))
	btn.add_theme_color_override("font_hover_color", texto(t))
	btn.add_theme_color_override("font_pressed_color", texto(t))

static func _fondo_boton(t: int, estado: int) -> Color:
	match normalizar(t):
		1:
			return [Color(0.42, 0.55, 0.95, 0.55), Color(0.50, 0.63, 1.0, 0.72),
					Color(0.34, 0.45, 0.86, 0.80)][estado]
		2:
			return [Color("#e8edf7"), Color("#ffffff"), Color("#c9d2e0")][estado]
	return [Color("#6b8cff"), Color("#7f9cff"), Color("#5a78e0")][estado]
