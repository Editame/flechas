extends Control

## Pantalla de juego (MÓVIL/táctil). Dibuja el tablero y las flechas con
## primitivas (colores suaves, longitud variable) y maneja el toque para sacar
## flechas. La lógica vive en src/core (Tablero); esto solo dibuja y traduce
## toques a llamadas de intentar_sacar.

var tablero: Tablero
var numero_nivel: int = 1
var _saltos: int = 0   # niveles generados en la sesión de prueba

# --- Pre-generación en segundo plano ---
# Generar un tablero de 1000+ celdas tarda 0.5-3 s y bloquea el hilo principal
# (se nota como "se demora en cargar"). Como el generador es lógica pura (no
# toca el árbol de nodos), se puede ejecutar en un hilo: mientras juegas el
# nivel actual, ya se está generando el siguiente. Al pulsar el botón, sale
# al instante.
var _hilo := Thread.new()
var _hilo_vivo := false
var _precargado: Generador.Nivel = null
var _historial: Array = []          # snapshots (clones) para deshacer
var _celda_px: float = 0.0
var _origen := Vector2.ZERO
var _resuelto := false
# Animaciones de salida en curso. Cada una: {flecha, dir, offset_px, dist_max}
var _animaciones: Array = []
var _choques: Array = []         # animaciones de choque (rebote) de bloqueadas
var _fx: Dictionary = {}         # id -> segundos restantes del efecto de bloqueo
var _marcadas: Dictionary = {}   # ids de flechas marcadas (rojas): quieren salir

# --- Métricas del nivel actual ---
var _movimientos: int = 0        # flechas sacadas con éxito (movimientos)
var _errores: int = 0            # toques a flechas bloqueadas
var _optimos: int = 0            # movimientos óptimos (= nº de flechas)
var _tiempo_ini: int = 0         # ms al iniciar el nivel

# --- Pan / Zoom del lienzo ---
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _celda_base: float = 0.0      # tamaño de celda a zoom 1 (encaja todo)
var _origen_base: Vector2 = Vector2.ZERO
var _zoom_min: float = 0.15
var _zoom_max: float = 12.0
# Gestos
var _arrastrando := false
var _toco_en := Vector2.ZERO
var _pan_al_tocar := Vector2.ZERO
var _movio := false
var _touches: Dictionary = {}     # index -> position (para pinch)
var _pinch_dist0: float = 0.0
var _pinch_zoom0: float = 1.0
const _UMBRAL_ARRASTRE := 12.0    # px para considerar que es arrastre, no tap

# Estilo "Arrows Out": líneas finas azul oscuro sobre fondo blanco.
const COLOR_FONDO := Color(1, 1, 1)
# Colores del tema se consultan dinámicamente vía Tema.* (según Config.tema).
const COLOR_TEXTO := Color(0.11, 0.13, 0.26)

@onready var _label_titulo: Label = $Header/Titulo
@onready var _label_estado: Label = $Estado

func _ready() -> void:
	# Nivel inicial: viene de Sesion (elegido en el menú) o del progreso guardado.
	if has_node("/root/Sesion"):
		numero_nivel = get_node("/root/Sesion").nivel_actual
	# Header.
	$Header/Atras.pressed.connect(_ir_menu)
	$Header/Deshacer.pressed.connect(deshacer)
	$Header/Ajustes.pressed.connect(_abrir_modal)
	$Header/VerWeb.pressed.connect(_abrir_en_web)
	# Modal de opciones.
	$Modal/Panel/VBox/Cerrar.pressed.connect(_cerrar_modal)
	$Modal/Panel/VBox/Reiniciar.pressed.connect(func():
		_cerrar_modal()
		reiniciar())
	$Modal/Fondo.gui_input.connect(func(e):
		if e is InputEventScreenTouch and e.pressed: _cerrar_modal())
	var chk_s: CheckButton = $Modal/Panel/VBox/FSonido/Chk
	var chk_v: CheckButton = $Modal/Panel/VBox/FVibracion/Chk
	var chk_e: CheckButton = $Modal/Panel/VBox/FEfectos/Chk
	chk_s.toggled.connect(func(v): Config.set_sonido(v))
	chk_v.toggled.connect(func(v): Config.set_vibracion(v))
	chk_e.toggled.connect(func(v): Config.set_efectos(v))
	# Overlay de victoria.
	$Victoria/VBox/Siguiente.pressed.connect(_siguiente_nivel)
	$Victoria/VBox/Inicio.pressed.connect(_ir_menu)
	resized.connect(queue_redraw)
	if has_node("/root/Config"):
		get_node("/root/Config").cambiado.connect(_refrescar_tema)
	_refrescar_tema()
	if has_node("/root/API_Client"):
		var api := get_node("/root/API_Client")
		if not api.nivel_listo.is_connected(_cargar_nivel_desde_api):
			api.nivel_listo.connect(_cargar_nivel_desde_api)
		if not api.error.is_connected(_on_error_api):
			api.error.connect(_on_error_api)
	cargar_nivel(numero_nivel)

## Abre en el navegador el jugador web con ESTA semilla y dificultad.
## Asi el nivel que se ve en el movil se puede inspeccionar en la web.
func _abrir_en_web() -> void:
	var semilla := 0
	var dificultad := "medio"
	if has_node("/root/Sesion"):
		semilla = get_node("/root/Sesion").semilla_nivel
		dificultad = get_node("/root/Sesion").dificultad_nivel
	var base := "http://127.0.0.1:8077/flechas/v1"
	if has_node("/root/API_Client"):
		base = get_node("/root/API_Client").url_base()
	var url := "%s/static/?semilla=%d&dificultad=%s" % [base, semilla, dificultad]
	print("[juego] abrir en web: ", url)
	OS.shell_open(url)

## Aplica el tema elegido a toda la escena (chrome + colores) y redibuja.
func _refrescar_tema() -> void:
	var t := Config.tema
	Tema.aplicar(t)
	for ruta in ["Header/Atras", "Header/Deshacer", "Header/VerWeb", "Header/Ajustes"]:
		if has_node(ruta):
			Tema.estilizar_secundario(get_node(ruta), t)
	if has_node("Modal/Panel"):
		$Modal/Panel.add_theme_stylebox_override("panel", Tema.caja_panel(t))
	if has_node("Dificultad"):
		$Dificultad.add_theme_color_override("font_color", Tema.texto_suave(t))
	if has_node("Estado"):
		$Estado.add_theme_color_override("font_color", Tema.texto(t))
	if has_node("Victoria/VBox/Mensaje"):
		$Victoria/VBox/Mensaje.add_theme_color_override("font_color", Tema.texto(t))
	queue_redraw()

func _ir_menu() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")

func _abrir_modal() -> void:
	# Sincroniza los checks con la config actual y muestra el modal (sin salir).
	$Modal/Panel/VBox/Titulo.text = I18n.t("opciones")
	$Modal/Panel/VBox/FSonido/Lbl.text = I18n.t("sonido")
	$Modal/Panel/VBox/FVibracion/Lbl.text = I18n.t("vibracion")
	$Modal/Panel/VBox/FEfectos/Lbl.text = I18n.t("efectos")
	$Modal/Panel/VBox/Reiniciar.text = I18n.t("reiniciar")
	$Modal/Panel/VBox/Cerrar.text = I18n.t("cerrar")
	$Modal/Panel/VBox/FSonido/Chk.button_pressed = Config.sonido
	$Modal/Panel/VBox/FVibracion/Chk.button_pressed = Config.vibracion
	$Modal/Panel/VBox/FEfectos/Chk.button_pressed = Config.efectos
	$Modal.visible = true

func _cerrar_modal() -> void:
	$Modal.visible = false

func cargar_nivel(numero: int) -> void:
	numero_nivel = numero
	_resuelto = false
	_historial.clear()
	_marcadas.clear()
	_zoom = 1.0
	_pan = Vector2.ZERO
	_movimientos = 0
	_errores = 0
	_tiempo_ini = Time.get_ticks_msec()
	if has_node("Victoria"):
		$Victoria.visible = false
	var dificultad := dificultad_para(numero)
	if has_node("/root/Sesion"):
		get_node("/root/Sesion").dificultad_nivel = dificultad
	if _label_titulo:
		_label_titulo.text = "Nivel %d" % numero
	if _label_estado:
		_label_estado.text = "Cargando nivel..."
	queue_redraw()
	if has_node("/root/API_Client"):
		get_node("/root/API_Client").siguiente(dificultad)
	else:
		_on_error_api("API no disponible")

## Regla de dificultad: 1-2 facil, 3-5 medio y de ahi en adelante aleatorio
## entre medio y maximo (con mas peso en dificil/super).
func dificultad_para(numero: int) -> String:
	if numero <= 2:
		return "facil"
	if numero <= 5:
		return "medio"
	var bolsa := [
		"medio", "medio", "medio",
		"dificil", "dificil", "dificil", "dificil",
		"super", "super", "super",
		"maximo", "maximo",
	]
	return bolsa[randi() % bolsa.size()]

func _draw() -> void:
	if tablero == null:
		return
	_calcular_geometria()
	var t := Config.tema
	# 0) Fondo del tema a pantalla completa.
	draw_rect(Rect2(Vector2.ZERO, size), Tema.fondo(t), true)
	# 1) Tablero: fondo, malla (según tema) y puntos.
	var o := _origen_efectivo()
	var w: float = tablero.columnas * _celda_px
	var h: float = tablero.filas * _celda_px
	draw_rect(Rect2(o, Vector2(w, h)), Tema.tablero(t), true)
	if Tema.usa_malla(t):
		var col_malla := Tema.color_malla(t)
		for r in range(tablero.filas + 1):
			var y := o.y + float(r) * _celda_px
			draw_line(Vector2(o.x, y), Vector2(o.x + w, y), col_malla, 1.0)
		for c in range(tablero.columnas + 1):
			var x := o.x + float(c) * _celda_px
			draw_line(Vector2(x, o.y), Vector2(x, o.y + h), col_malla, 1.0)
	var col_punto := Tema.color_punto(t)
	var radio := maxf(1.6, _celda_px * Tema.radio_punto(t))
	for celda in tablero.jugables.keys():
		var centro := _centro_celda(celda)
		draw_rect(Rect2(centro - Vector2(radio, radio), Vector2(radio * 2.0, radio * 2.0)), col_punto)
	# 2) Flechas encima. Las que están en CHOQUE se dibujan aparte (deslizando).
	var en_choque := {}
	for ch in _choques:
		en_choque[(ch["flecha"] as Flecha).id] = true
	for id in tablero.flechas.keys():
		if not en_choque.has(id):
			_dibujar_flecha(tablero.flechas[id])
	# 3) Flechas en animación de salida (deslizándose por su propio camino).
	for a in _animaciones:
		_dibujar_flecha_saliendo(a)
	# 4) Flechas en CHOQUE: deslizan por su camino hasta topar y rebotan.
	for ch in _choques:
		var avance: float = sin(ch["t"] * PI) * ch["avance_max"]
		_dibujar_flecha_saliendo({ "flecha": ch["flecha"], "avance": avance }, true)

func _dibujar_flecha(flecha: Flecha, desplazamiento: Vector2 = Vector2.ZERO) -> void:
	# Dibuja la flecha como una LÍNEA que sigue su camino (con recodos) y una
	# punta al final (cabeza). Color según tema; roja si está marcada.
	var t := Config.tema
	var color := Tema.color_flecha(t, flecha.id)
	if _marcadas.has(flecha.id):
		color = Tema.ROJO_COLISION
	var grosor: float = maxf(2.4, _celda_px * Tema.grosor(t))

	# Puntos del camino en pantalla (centro de cada celda) + desplazamiento.
	var pts: PackedVector2Array = PackedVector2Array()
	for celda in flecha.celdas:
		pts.append(_centro_celda(celda) + desplazamiento)


	# Dirección de salida (para la punta).
	var ds := flecha.direccion_salida()
	var dir := Vector2(ds.y, ds.x)
	if dir.length() > 0.01:
		dir = dir.normalized()
	# Efecto de bloqueo: sacudida perpendicular + anillos en la punta.
	var fx := float(_fx.get(flecha.id, 0.0))
	if fx > 0.0 and pts.size() >= 2:
		var perp := Vector2(-dir.y, dir.x)
		var k := clampf(fx / 0.45, 0.0, 1.0)
		var desf := perp * sin(fx * 55.0) * (_celda_px * 0.07) * k
		for i in range(pts.size()):
			pts[i] += desf
	# 0) Halo suave detrás del cuerpo (según tema).
	var h := Tema.halo(t)
	if h > 0.0:
		var hc := Color(color.r, color.g, color.b, h)
		var hg := grosor * 1.9
		for k in range(pts.size() - 1):
			draw_line(pts[k], pts[k + 1], hc, hg, true)
	# 1) Cuerpo: todo el camino, con codos redondeados.
	for k in range(pts.size() - 1):
		draw_line(pts[k], pts[k + 1], color, grosor, true)
	for p in pts:
		draw_circle(p, grosor * 0.5, color)
	# 2) Punta centrada en el ultimo punto (como la web).
	_dibujar_punta(pts[pts.size() - 1], dir, color)
	# 3) Anillos del efecto de bloqueo.
	if fx > 0.0:
		var avance := 1.0 - clampf(fx / 0.45, 0.0, 1.0)
		for n in range(2):
			var kk := clampf(avance - 0.22 * float(n), 0.0, 1.0)
			var radio := _celda_px * (0.12 + 0.62 * kk)
			var al := (1.0 - kk) * 0.65
			draw_arc(pts[pts.size() - 1], radio, 0.0, TAU, 28,
					Color(1.0, 0.36, 0.45, al), maxf(2.0, _celda_px * 0.05), true)

## Dibuja una flecha en animación de salida, deslizándose por SU PROPIO CAMINO.
## Construye un "riel" en coords de celda = camino (cola->cabeza) + extensión
## recta desde la cabeza en la dirección de salida. Cada punto del cuerpo se
## coloca en el riel a distancia (indice_original + avance), siguiendo los giros.
func _dibujar_flecha_saliendo(a: Dictionary, rojo: bool = false) -> void:
	var flecha: Flecha = a["flecha"]
	var avance: float = a["avance"]
	var color := Tema.ROJO_COLISION if rojo else Tema.color_flecha(Config.tema, flecha.id)
	var grosor: float = maxf(2.4, _celda_px * Tema.grosor(Config.tema))

	# Riel en coords de celda: las celdas del camino + extensión recta.
	var ds := flecha.direccion_salida()   # (dfila, dcol)
	var riel: Array[Vector2] = []
	for c in flecha.celdas:
		riel.append(Vector2(c.x, c.y))     # (fila, col)
	# Extiende desde la cabeza en dir de salida (suficientes celdas para salir).
	var cab: Vector2i = flecha.cabeza()
	var ext := flecha.longitud() + tablero.filas + tablero.columnas + 4
	for k in range(1, ext):
		riel.append(Vector2(cab.x + ds.x * k, cab.y + ds.y * k))

	# Cuerpo: desde la COLA (distancia = avance) hasta la CABEZA (avance + n-1),
	# incluyendo TODOS los nodos intermedios del riel (los codos), para que las
	# curvas mantengan su ángulo recto y NO se redondeen.
	var n := flecha.longitud()
	var d_cola: float = avance
	var d_cabeza: float = avance + float(n - 1)
	var pantalla: PackedVector2Array = PackedVector2Array()
	pantalla.append(_punto_en_riel(riel, d_cola))
	# Añade cada nodo entero del riel que caiga dentro del rango (los codos).
	var k0 := int(ceil(d_cola))
	var k1 := int(floor(d_cabeza))
	for k in range(k0, k1 + 1):
		pantalla.append(_punto_en_riel(riel, float(k)))
	pantalla.append(_punto_en_riel(riel, d_cabeza))

	# Dibuja el cuerpo (cola->cabeza) siguiendo el riel con codos.
	for i in range(pantalla.size() - 1):
		draw_line(pantalla[i], pantalla[i + 1], color, grosor, true)
	for p in pantalla:
		draw_circle(p, grosor * 0.5, color)

	# Punta en la cabeza (último punto), UNIDA al cuerpo (sin hueco).
	var dir := Vector2(ds.y, ds.x)
	if dir.length() > 0.01:
		dir = dir.normalized()
	_dibujar_punta(pantalla[pantalla.size() - 1], dir, color)

## Punta triangular centrada en `punta`, con el vertice medio paso por delante
## (igual que el jugador web): asi la flecha "apunta" al punto sin invadir la
## celda siguiente.
func _dibujar_punta(punta: Vector2, dir: Vector2, color: Color) -> void:
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var t: float = maxf(3.0, _celda_px * 0.34)
	var vertice := punta + dir * t
	var a1 := punta + dir.rotated(2.5) * t
	var a2 := punta + dir.rotated(-2.5) * t
	draw_colored_polygon(PackedVector2Array([vertice, a1, a2]), color)

## Dado un riel (lista de celdas Vector2(fila,col)) y una distancia `d` en
## unidades de celda a lo largo del riel, devuelve el punto en PANTALLA.
func _punto_en_riel(riel: Array[Vector2], d: float) -> Vector2:
	if d <= 0.0:
		return _celda_centro_f(riel[0])
	var i := int(floor(d))
	var frac := d - i
	if i >= riel.size() - 1:
		# Más allá del riel: extrapola en la dirección del último segmento.
		var ultimo := riel[riel.size() - 1]
		var previo := riel[riel.size() - 2]
		var dirc := (ultimo - previo)
		return _celda_centro_f(ultimo + dirc * (d - (riel.size() - 1)))
	var a := riel[i]
	var b := riel[i + 1]
	return _celda_centro_f(a.lerp(b, frac))

## Centro en pantalla de una posición de celda fraccionaria (fila,col).
func _celda_centro_f(cf: Vector2) -> Vector2:
	var o := _origen_efectivo()
	return o + Vector2((cf.y + 0.5) * _celda_px, (cf.x + 0.5) * _celda_px)

# --- Entrada: pan (1 dedo), pinch zoom (2 dedos), rueda (PC), tap = sacar ---
func _gui_input(event: InputEvent) -> void:
	# --- Táctil ---
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_arrastrando = true
				_movio = false
				_toco_en = event.position
				_pan_al_tocar = _pan
			elif _touches.size() == 2:
				# Inicia pinch.
				_arrastrando = false
				var ps := _touches.values()
				_pinch_dist0 = (ps[0] as Vector2).distance_to(ps[1] as Vector2)
				_pinch_zoom0 = _zoom
		else:
			_touches.erase(event.index)
			if _touches.is_empty():
				# Se soltó el último dedo: si fue tap corto (sin mover) = sacar.
				if not _movio and not _resuelto:
					_procesar_toque(event.position)
				_arrastrando = false
		return

	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			# Pinch zoom.
			var ps := _touches.values()
			var d := (ps[0] as Vector2).distance_to(ps[1] as Vector2)
			if _pinch_dist0 > 1.0:
				var centro := ((ps[0] as Vector2) + (ps[1] as Vector2)) * 0.5
				_aplicar_zoom(_pinch_zoom0 * (d / _pinch_dist0), centro)
		elif _arrastrando:
			var delta: Vector2 = event.position - _toco_en
			if delta.length() > _UMBRAL_ARRASTRE:
				_movio = true
			_pan = _pan_al_tocar + delta
			_limitar_pan()
			queue_redraw()
		return

	# --- Mouse (PC): arrastrar con botón izq = pan; rueda = zoom; clic simple = tap ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_aplicar_zoom(_zoom * 1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_aplicar_zoom(_zoom / 1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_arrastrando = true
				_movio = false
				_toco_en = event.position
				_pan_al_tocar = _pan
			else:
				if not _movio and not _resuelto:
					_procesar_toque(event.position)
				_arrastrando = false
		return

	if event is InputEventMouseMotion and _arrastrando:
		var delta: Vector2 = event.position - _toco_en
		if delta.length() > _UMBRAL_ARRASTRE:
			_movio = true
		_pan = _pan_al_tocar + delta
		_limitar_pan()
		queue_redraw()

## Aplica zoom manteniendo el punto `centro` (en pantalla) fijo.
func _aplicar_zoom(nuevo: float, centro: Vector2) -> void:
	nuevo = clampf(nuevo, _zoom_min, _zoom_max)
	if is_equal_approx(nuevo, _zoom):
		return
	# Ajusta pan para hacer zoom hacia el punto `centro`.
	var factor := nuevo / _zoom
	_pan = centro - (centro - _pan) * factor
	_zoom = nuevo
	_limitar_pan()
	queue_redraw()

## Limita el paneo para que el tablero no se salga por completo de la vista,
## pero permitiendo moverlo libremente y centrarlo.
func _limitar_pan() -> void:
	var area := size
	if area.x < 10:
		area = get_viewport_rect().size
	var w := tablero.columnas * _celda_px   # ancho efectivo (ya incluye zoom)
	var h := tablero.filas * _celda_px       # alto efectivo
	# Posición en pantalla de la esquina superior-izq del tablero = origen_base + pan.
	# Queremos que el tablero pueda moverse pero dejando >= 'visible' px dentro.
	var visible := 120.0   # cuánto del tablero debe permanecer en pantalla
	# X: la esquina izquierda puede ir desde (area.x - visible) hasta (visible - w)
	var izq_min := visible - w                       # tablero casi salido por la izq
	var izq_max := area.x - visible                  # tablero casi salido por la der
	var pan_x_min := izq_min - _origen_base.x
	var pan_x_max := izq_max - _origen_base.x
	# Si el tablero cabe holgado, permite centrar (min<=max garantizado).
	if pan_x_min > pan_x_max:
		var m := (pan_x_min + pan_x_max) * 0.5
		pan_x_min = m; pan_x_max = m
	_pan.x = clampf(_pan.x, pan_x_min, pan_x_max)
	# Y: análogo, respetando el área de juego (deja ver header arriba).
	var arr_min := visible - h
	var arr_max := area.y - visible
	var pan_y_min := arr_min - _origen_base.y
	var pan_y_max := arr_max - _origen_base.y
	if pan_y_min > pan_y_max:
		var m2 := (pan_y_min + pan_y_max) * 0.5
		pan_y_min = m2; pan_y_max = m2
	_pan.y = clampf(_pan.y, pan_y_min, pan_y_max)

func _procesar_toque(pos: Vector2) -> void:
	var celda := _celda_en(pos)
	if celda == Vector2i(-1, -1):
		return
	if not tablero.esta_ocupada(celda):
		return
	var id: int = tablero.ocupacion[celda]
	# Guarda snapshot para deshacer.
	_historial.append(tablero.clonar())
	if tablero.puede_salir(id):
		_sacar_con_animacion(id)
		_marcadas.erase(id)
		_evaluar_fin()
		# Tras salir, revisa si alguna flecha MARCADA ya puede salir sola.
		_liberar_marcadas()
	else:
		# Bloqueada: se queda MARCADA en rojo. Animación de CHOQUE: la flecha
		# avanza hasta topar con la que la bloquea y rebota.
		_historial.pop_back()   # marcar no es una jugada deshacible
		if not _marcadas.has(id):
			_errores += 1        # cuenta el error solo la primera vez
		_marcadas[id] = true
		_fx[id] = 0.45          # efecto de bloqueo (sacudida + anillos)
		if has_node("/root/Audio"):
			get_node("/root/Audio").colision()   # sonido + vibración (respeta config)
		_iniciar_choque(id)
		# El color ROJO de la flecha ya comunica el bloqueo (sin texto).
		queue_redraw()

## Anima el CHOQUE de una flecha bloqueada: se desliza SIGUIENDO SU CAMINO hasta
## topar con el obstáculo (o 1 casilla) y rebota. Igual que la salida pero ida y
## vuelta, respetando los recodos (no rígido).
func _iniciar_choque(id: int) -> void:
	var flecha: Flecha = tablero.flechas.get(id)
	if flecha == null:
		return
	var paso := flecha.direccion_salida()
	# Celdas libres delante de la cabeza hasta el obstáculo.
	var libres := 0
	var actual: Vector2i = flecha.cabeza() + paso
	while tablero.es_jugable(actual) and not tablero.esta_ocupada(actual):
		libres += 1
		actual += paso
	# Avance máximo del golpe: hasta tocar el obstáculo (mínimo un empujoncito).
	var avance_max := maxf(0.5, float(libres) + 0.5)
	_choques.append({
		"flecha": flecha.clonar(),
		"avance_max": avance_max,
		"t": 0.0,
	})
	set_process(true)

## Saca una flecha del tablero e inicia su animación de salida.
func _sacar_con_animacion(id: int) -> void:
	var flecha: Flecha = (tablero.flechas[id] as Flecha).clonar()
	tablero.quitar(id)
	_movimientos += 1
	_iniciar_animacion_salida(flecha)
	if has_node("/root/Audio"):
		get_node("/root/Audio").salida()
	queue_redraw()

## Revisa las flechas marcadas (rojas): las que ya tienen camino libre salen
## solas, en cadena (sacar una puede desbloquear otra marcada).
func _liberar_marcadas() -> void:
	var hubo_cambio := true
	while hubo_cambio:
		hubo_cambio = false
		for id in _marcadas.keys():
			if tablero.flechas.has(id) and tablero.puede_salir(id):
				_sacar_con_animacion(id)
				_marcadas.erase(id)
				hubo_cambio = true
				break   # reinicia el barrido (el diccionario cambió)
	_evaluar_fin()

## Prepara la animación de una flecha deslizándose fuera del tablero.
func _iniciar_animacion_salida(flecha: Flecha) -> void:
	# La flecha sale SIGUIENDO SU CAMINO (como serpiente por un tubo): la cabeza
	# avanza en su dirección de salida hasta fuera de pantalla, y cada segmento
	# del cuerpo recorre exactamente la misma trayectoria por donde ya pasó.
	# Guardamos las celdas (en coords de celda) y la dirección de salida; el
	# dibujo desliza el cuerpo a lo largo de esa polilínea + extensión recta.
	var ds := flecha.direccion_salida()
	_animaciones.append({
		"flecha": flecha,
		"ds": Vector2(ds.y, ds.x),   # dirección de salida en pantalla (x=col,y=fila)
		"avance": 0.0,               # distancia recorrida (en unidades de celda)
		"max": flecha.longitud() + tablero.columnas + tablero.filas + 4.0,
		"vel": 26.0,                 # celdas por segundo (rápido)
	})
	set_process(true)

func _process(delta: float) -> void:
	# Avanza animaciones de salida.
	var vivas: Array = []
	for a in _animaciones:
		a["avance"] += a["vel"] * delta
		if a["avance"] < a["max"]:
			vivas.append(a)
	_animaciones = vivas
	# Avanza animaciones de CHOQUE (ida y vuelta rápida = rebote).
	var choques_vivos: Array = []
	for ch in _choques:
		ch["t"] += delta * 7.0   # velocidad del rebote
		if ch["t"] < 1.0:
			choques_vivos.append(ch)
	_choques = choques_vivos
	# Efecto de bloqueo (sacudida + anillos rojos).
	for id in _fx.keys():
		var resto: float = float(_fx[id]) - delta
		if resto > 0.0:
			_fx[id] = resto
		else:
			_fx.erase(id)
	if _animaciones.is_empty() and _choques.is_empty() and _fx.is_empty():
		set_process(false)
	queue_redraw()

func _evaluar_fin() -> void:
	if tablero.victoria():
		_resuelto = true
		_mostrar_victoria()
	elif tablero.atascado():
		if _label_estado:
			_label_estado.text = I18n.t("atascado")

func _mostrar_victoria() -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").victoria()
	# Calcula tiempo y guarda métricas -> devuelve estrellas.
	var tiempo := (Time.get_ticks_msec() - _tiempo_ini) / 1000.0
	var estrellas := 3
	if has_node("/root/Progreso"):
		estrellas = get_node("/root/Progreso").completar_nivel(
			numero_nivel, tiempo, _movimientos, _optimos, _errores)
	# Mensaje celebratorio + estrellas + stats.
	var mensajes := ["buen_trabajo", "impresionante", "maravilloso"]
	$Victoria/VBox/Mensaje.text = I18n.t(mensajes[numero_nivel % mensajes.size()])
	$Victoria/VBox/Sub.text = "%s %d" % [I18n.t("nivel_completado"), numero_nivel]
	$Victoria/VBox/Estrellas.text = _texto_estrellas(estrellas)
	$Victoria/VBox/Stats.text = "⏱ %.0fs   ·   %d %s   ·   %d ✗" % [
		tiempo, _movimientos, I18n.t("movs"), _errores]
	$Victoria/VBox/Siguiente.text = I18n.t("siguiente_nivel")
	$Victoria/VBox/Inicio.text = I18n.t("inicio")
	$Victoria/VBox/Siguiente.visible = true   # modo infinito: siempre hay siguiente
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(func(): $Victoria.visible = true)

func _texto_estrellas(n: int) -> String:
	var s := ""
	for i in 3:
		s += "★" if i < n else "☆"
	return s

func _siguiente_nivel() -> void:
	$Victoria.visible = false
	cargar_nivel(numero_nivel + 1)

func _tomar_precargado() -> Generador.Nivel:
	if not _hilo_vivo:
		return _precargado
	_hilo.wait_to_finish()
	_hilo_vivo = false
	var n := _precargado
	_precargado = null
	return n

## Genera un nivel difícil en un hilo de fondo (lógica pura, no toca nodos).
func _lanzar_precarga() -> void:
	if _hilo_vivo:
		return
	_precargado = null
	_hilo_vivo = true
	_hilo.start(_trabajo_generar.bind(randi()))

func _trabajo_generar(semilla: int) -> void:
	_precargado = Generador._generar_en_vivo(semilla, 3, 4)

## Carga un nivel desde la API.
## Se llama desde cargar_nivel() cuando viene de selector_niveles.
## Construye el tablero con los datos que devuelve la API y arranca el nivel.
func _cargar_nivel_desde_api(data: Dictionary) -> void:
	if not data.has("flechas") or not data.has("forma"):
		_on_error_api("El servidor devolvio un nivel incompleto")
		return
	tablero = Tablero.new(int(data["filas"]), int(data["columnas"]))
	for celda in data["forma"]:
		tablero.agregar_celda(Vector2i(int(celda[0]), int(celda[1])))
	var paleta := Tema.paleta(Config.tema)
	var i := 0
	for fd in data["flechas"]:
		var celdas: Array[Vector2i] = []
		for c in fd["celdas"]:
			celdas.append(Vector2i(int(c[0]), int(c[1])))
		tablero.colocar(Flecha.new(int(fd["id"]), celdas, paleta[i % paleta.size()]))
		i += 1
	var solucion: Array = data.get("solucion", [])
	if has_node("/root/Sesion"):
		var sesion := get_node("/root/Sesion")
		sesion.fijar_nivel(numero_nivel, int(data.get("semilla", 0)), solucion)
		sesion.dificultad_nivel = str(data.get("dificultad", sesion.dificultad_nivel))
	_optimos = solucion.size()
	_resuelto = false
	_historial.clear()
	_marcadas.clear()
	_zoom = 1.0
	_pan = Vector2.ZERO
	_movimientos = 0
	_errores = 0
	_tiempo_ini = Time.get_ticks_msec()
	if has_node("Victoria"):
		$Victoria.visible = false
	if has_node("Dificultad"):
		$Dificultad.text = I18n.t(str(data.get("dificultad", "medio")))
	if _label_estado:
		_label_estado.text = ""
	print("[juego] nivel ", numero_nivel, " ", tablero.filas, "x", tablero.columnas, " flechas=", tablero.cantidad_flechas(), " dificultad=", str(data.get("dificultad", "?")))
	queue_redraw()

func _on_error_api(mensaje: String) -> void:
	printerr("[juego] ", mensaje)
	if _label_estado:
		_label_estado.text = mensaje
	queue_redraw()

func _exit_tree() -> void:
	# Nunca dejar un hilo vivo al salir de la escena.
	if _hilo_vivo:
		_hilo.wait_to_finish()
		_hilo_vivo = false

## Carga un nivel ya generado (compartido por carga inicial y botón).
func cargar_tablero(nivel: Generador.Nivel) -> void:
	tablero = nivel.tablero
	_optimos = (nivel.solucion as Array).size()
	_resuelto = false
	_historial.clear()
	_marcadas.clear()
	_zoom = 1.0
	_pan = Vector2.ZERO
	_movimientos = 0
	_errores = 0
	_tiempo_ini = Time.get_ticks_msec()
	if has_node("Victoria"):
		$Victoria.visible = false
	if has_node("/root/Sesion"):
		get_node("/root/Sesion").fijar_nivel(numero_nivel, nivel.semilla, nivel.solucion as Array)
	if _label_titulo:
		_label_titulo.text = "Prueba %d" % numero_nivel
	if has_node("Dificultad") and tablero != null:
		$Dificultad.text = I18n.t(Generador.dificultad(tablero))
	if _label_estado:
		_label_estado.text = ""
	queue_redraw()

func deshacer() -> void:
	if _historial.is_empty():
		return
	tablero = _historial.pop_back()
	_resuelto = false
	if _label_estado:
		_label_estado.text = ""
	queue_redraw()

func reiniciar() -> void:
	cargar_nivel(numero_nivel)

func siguiente() -> void:
	if numero_nivel < 10:
		cargar_nivel(numero_nivel + 1)

## Carga un nivel ya generado (compartido por carga inicial y botón).
func _calcular_geometria() -> void:
	var area := size
	if area.x < 10.0 or area.y < 10.0:
		area = get_viewport_rect().size
	var margen := 24.0
	var reserva_arriba := 170.0   # header + dificultad + estado
	var reserva_abajo := 30.0
	var ancho_disp: float = area.x - margen * 2.0
	var alto_disp: float = area.y - reserva_arriba - reserva_abajo
	# Celda BASE (zoom 1): encaja TODO el tablero (vista general inicial).
	var celda_w: float = ancho_disp / float(tablero.columnas)
	var celda_h: float = alto_disp / float(tablero.filas)
	_celda_base = maxf(6.0, minf(celda_w, celda_h))
	var w: float = tablero.columnas * _celda_base
	var h: float = tablero.filas * _celda_base
	_origen_base = Vector2(
		(area.x - w) / 2.0,
		reserva_arriba + (alto_disp - h) / 2.0
	)
	# Tamaño efectivo tras zoom.
	_celda_px = _celda_base * _zoom

## Origen efectivo (con pan y zoom aplicados).
func _origen_efectivo() -> Vector2:
	# Al hacer zoom, el origen base se escala respecto a sí mismo + pan.
	return _origen_base + _pan

func _centro_celda(celda: Vector2i) -> Vector2:
	var o := _origen_efectivo()
	return o + Vector2((celda.y + 0.5) * _celda_px, (celda.x + 0.5) * _celda_px)

func _celda_en(pos: Vector2) -> Vector2i:
	if _celda_px <= 0.0:
		return Vector2i(-1, -1)
	var local := pos - _origen_efectivo()
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var col := int(local.x / _celda_px)
	var fila := int(local.y / _celda_px)
	var celda := Vector2i(fila, col)
	if tablero.es_jugable(celda):
		return celda
	return Vector2i(-1, -1)

# Reset de pan/zoom al cargar nivel (definido abajo si hace falta).



