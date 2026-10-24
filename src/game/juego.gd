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
	# Botón de prueba: siempre genera un nivel difícil/súper difícil NUEVO.
	if has_node("OtroNivel"):
		$OtroNivel.pressed.connect(otro_nivel)
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
		get_node("/root/Config").cambiado.connect(queue_redraw)
	cargar_nivel(numero_nivel)
	# Empieza a generar el siguiente nivel en segundo plano, para que el botón
	# "Otro nivel" responda al instante.
	_lanzar_precarga()

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
	# Métricas del nivel.
	_movimientos = 0
	_errores = 0
	_tiempo_ini = Time.get_ticks_msec()
	if has_node("Victoria"):
		$Victoria.visible = false
	# FASE DE PRUEBAS: sin progresión de niveles. Siempre un nivel difícil o
	# súper difícil nuevo (semilla aleatoria), paraevaluar solo la dificultad.
	var nivel: Generador.Nivel = Generador._generar_en_vivo(randi(), 3, 4)
	if nivel != null:
		tablero = nivel.tablero
		_optimos = (nivel.solucion as Array).size()
		# Guarda semilla y solución para poder auditar este nivel exacto.
		if has_node("/root/Sesion"):
			get_node("/root/Sesion").fijar_nivel(
				numero, nivel.semilla, nivel.solucion as Array)
	if _label_titulo:
		_label_titulo.text = "Prueba %d" % _saltos
	if has_node("Dificultad") and tablero != null:
		$Dificultad.text = I18n.t(Generador.dificultad(tablero))
	_actualizar_debug()
	if _label_estado:
		_label_estado.text = ""
	queue_redraw()

## PANEL DE DIAGNÓSTICO (tecla D).
##
## Muestra la SEMILLA del nivel y sus métricas objetivas. Con esa semilla se
## puede reproducing el nivel exacto en tools/inspeccionar_semilla.gd y auditar
## por qué un nivel es difícil o fácil, en vez de estimarlo a ojo.
##
## Métricas: la CADENA es la importante: cuántas jugadas hay que planificar
## antes de poder resolver. "Libres@0" son las flechas que se pueden sacar sin
## pensar al abrir el nivel: cuantas más, más fácil se siente.
func _actualizar_debug() -> void:
	if not has_node("Debug") or tablero == null:
		return
	var semilla := 0
	if has_node("/root/Sesion"):
		semilla = get_node("/root/Sesion").semilla_nivel
	var cadena := Metricas.cadena_mas_larga(tablero)
	var libres := Metricas.libres_iniciales(tablero)
	var nf := tablero.cantidad_flechas()
	var prof := GrafoDependencias.profundidad(tablero)
	var ratio := GrafoDependencias.ratio_bloqueo(tablero) * 100.0
	var sol_ok := true
	if has_node("/root/Sesion"):
		var sol: Array = get_node("/root/Sesion").solucion_nivel
		if not sol.is_empty():
			sol_ok = Metricas.verificar_solucion(tablero, sol)
	$Debug.text = "\n".join([
		Version.etiqueta(),
		"Nv %d  semilla %d" % [numero_nivel, semilla],
		"celdas %d  flechas %d" % [tablero.jugables.size(), nf],
		"CADENA %d   prof %d" % [cadena, prof],
		"libres@0 %d (%d%%)  bloq %d%%" % [libres, int(round(100.0 * libres / maxf(1.0, float(nf)))), int(ratio)],
		"solucion valida: %s" % ("si" if sol_ok else "NO"),
	])

func _unhandled_input(event: InputEvent) -> void:
	# Tecla D (móvil: 3 dedos? no hay; en PC sirve para auditar).
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_D and has_node("Debug"):
			$Debug.visible = not $Debug.visible

func _draw() -> void:
	if tablero == null:
		return
	_calcular_geometria()
	# 1) Matriz de puntos de fondo (dot grid) según el tema.
	var col_punto := Tema.color_punto(Config.tema)
	for celda in tablero.jugables.keys():
		var centro := _centro_celda(celda)
		draw_circle(centro, maxf(2.0, _celda_px * 0.06), col_punto)
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
	var color := Tema.color_flecha(Config.tema, flecha.id)
	if _marcadas.has(flecha.id):
		color = Tema.ROJO_COLISION
	var grosor: float = maxf(2.0, _celda_px * 0.10)   # grosor intermedio

	# Puntos del camino en pantalla (centro de cada celda) + desplazamiento.
	var pts: PackedVector2Array = PackedVector2Array()
	for celda in flecha.celdas:
		pts.append(_centro_celda(celda) + desplazamiento)

	# Extiende la cola un poco hacia afuera (para que arranque en el borde).
	if pts.size() >= 2:
		var d0 := (pts[0] - pts[1]).normalized()
		pts[0] = pts[0] + d0 * (_celda_px * 0.28)

	# Dirección de salida (para la punta).
	var ds := flecha.direccion_salida()
	var dir := Vector2(ds.y, ds.x)
	if dir.length() > 0.01:
		dir = dir.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var cabeza := pts[pts.size() - 1]
	# La punta arranca DESDE la celda cabeza (unida al cuerpo, sin hueco).
	var vertice := cabeza + dir * (_celda_px * 0.42)
	var base := cabeza                       # base de la punta = centro de la celda
	# 1) Cuerpo: recorre el camino hasta la BASE de la punta (continuo).
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], color, grosor, true)
	for p in pts:
		draw_circle(p, grosor * 0.5, color)
	# 2) Punta triangular UNIDA al cuerpo (su base está en la celda cabeza).
	var ancho := _celda_px * 0.24
	var a1 := base + perp * ancho
	var a2 := base - perp * ancho
	draw_colored_polygon(PackedVector2Array([vertice, a1, a2]), color)

## Dibuja una flecha en animación de salida, deslizándose por SU PROPIO CAMINO.
## Construye un "riel" en coords de celda = camino (cola->cabeza) + extensión
## recta desde la cabeza en la dirección de salida. Cada punto del cuerpo se
## coloca en el riel a distancia (indice_original + avance), siguiendo los giros.
func _dibujar_flecha_saliendo(a: Dictionary, rojo: bool = false) -> void:
	var flecha: Flecha = a["flecha"]
	var avance: float = a["avance"]
	var color := Tema.ROJO_COLISION if rojo else Tema.color_flecha(Config.tema, flecha.id)
	var grosor: float = maxf(2.0, _celda_px * 0.10)

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
	var perp := Vector2(-dir.y, dir.x)
	var cabeza := pantalla[pantalla.size() - 1]
	var vertice := cabeza + dir * (_celda_px * 0.42)
	var ancho := _celda_px * 0.24
	draw_colored_polygon(PackedVector2Array([
		vertice, cabeza + perp * ancho, cabeza - perp * ancho]), color)

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
	if _animaciones.is_empty() and _choques.is_empty():
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
	otro_nivel()

## FASE DE PRUEBAS: genera un nivel NUEVO, siempre difícil o súper difícil.
##
## No hay progresión de niveles ni tutorial por ahora: el objetivo esevaluar
## únicamente la dificultad. Cada pulsación usa una semilla DISTINTA para que
## nunca se repita el mismo tablero.
func otro_nivel() -> void:
	# Recoge el nivel pre-generado en segundo plano (si ya está listo).
	var nivel := _tomar_precargado()
	if nivel == null:
		# No había ninguno listo: se genera ahora (puede tardar).
		if _label_estado:
			_label_estado.text = "Generando..."
			queue_redraw()
		nivel = Generador._generar_en_vivo(randi(), 3, 4)
	if nivel == null:
		push_warning("No se pudo generar nivel de prueba")
		if _label_estado:
			_label_estado.text = "Error al generar"
		return
	_saltos += 1
	numero_nivel = _saltos
	cargar_tablero(nivel)
	# Arranca a generar el SIGUIENTE en segundo plano.
	_lanzar_precarga()

## Devuelve el nivel pre-generado (espera al hilo si sigue trabajando).
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
	_actualizar_debug()
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

# --- Geometría (píxeles <-> celdas) con pan/zoom ---
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



