class_name Generador
extends RefCounted

## Genera niveles RESOLUBLES por CONSTRUCCIÓN INVERSA, priorizando DIFICULTAD
## (dependencias profundas), siguiendo el patrón del generador profesional de
## arrow-puzzles (gtxPrime/arrow-escape).
##
## Reglas clave:
##  - Construcción hacia atrás: la 1ª flecha colocada es la ÚLTIMA en salir.
##    Solución = orden inverso de colocación -> resoluble por construcción.
##  - Cada flecha, al colocarse, debe ser DISPARABLE ahora (corredor libre).
##  - Cada flecha (salvo la 1ª) DEBE BLOQUEAR el corredor de salida de alguna
##    flecha ya colocada -> crea dependencias -> dificultad real.
##  - Longitudes por TIERS (algunas muy largas cruzan y enredan más).
##  - NO se fuerza relleno 100%: se colocan N flechas; los huecos se aceptan.
##  - Sin backtracking: si falla, se reintenta con otra semilla.

const COLORES_SUAVES: Array[Color] = [
	Color(0.62, 0.76, 0.90), Color(0.66, 0.84, 0.71), Color(0.95, 0.80, 0.65),
	Color(0.83, 0.74, 0.90), Color(0.95, 0.85, 0.70), Color(0.80, 0.88, 0.83),
	Color(0.92, 0.76, 0.80),
]

const DIRS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
]

## --- TANGLE FACTOR (factor de enredado) ---
##
## Referencia: gtxPrime/arrow-escape (level_design_requirements.md, seccion 3).
## Controla cuanto se doblan los caminos, de 0.0 (solo rectas) a 1.0 (zig-zag
## maximo). Es la palanca de dificultad que mas nos faltaba: nuestro generador
## hacia caminos al azar SIN ningun control de enredado.
##
## Por que el enredado sube la dificultad: una flecha que gira atraviesa mas
## corredores de salida ajenos -> bloquea mas flechas -> crea mas aristas en el
## grafo de dependencias -> obligaa al jugador a planificar mas pasos.
const TANGLE_MIN := 0.0
const TANGLE_MAX := 1.0

## Escala de tangle por nº de nivel (calibrada como la referencia).
## 1-5 tutorial -> 0.0 (rectas, aprender sin ruido)
## 6-15->0.15   16-40 -> 0.35   41-100 -> 0.6   101-250 -> 0.8   251+ -> 1.0
static func tangle_para_nivel(numero: int) -> float:
	if numero <= 5:
		return 0.0
	elif numero <= 15:
		return 0.15
	elif numero <= 40:
		return 0.35
	elif numero <= 100:
		return 0.6
	elif numero <= 250:
		return 0.8
	return 1.0

class Nivel:
	var tablero: Tablero
	var solucion: Array
	var semilla: int
	func _init(p_tablero: Tablero, p_solucion: Array, p_semilla: int) -> void:
		tablero = p_tablero
		solucion = p_solucion
		semilla = p_semilla

## Genera un nivel GRANDE directamente (para pre-generación de difíciles, sin
## límite de tiempo). cols grande -> tableros densos y muy profundos.
static func generar_grande(
	cols: int, semilla: int, tangle: float = 1.0, intentos: int = 6
) -> Nivel:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var filas := int(cols * rng.randf_range(1.3, 1.5))
	var forma := Figuras.figura_dinamica(filas, cols, rng)
	var bb := _bbox(forma)
	var objetivo := int(forma.size() * rng.randf_range(0.7, 0.9) / 3.0)
	return _construir(forma, bb.x, bb.y, objetivo, semilla + 777, intentos, tangle)

## FASE DE PRUEBAS DE DIFICULTAD.
##
## Mientras está a `true`, TODOS los niveles generados son difíciles o súper
## difíciles, ignorando la progresión (tutorial) y el pool pre-generado. El
## objetivo es evaluar la dificultad sin filtros: pulsar el botón y siempre
## salir un nivel que de verdad sirva. Cuando la dificultad esté aprobada, se
## pone a `false` y vuelve la progresión normal.
const MODO_PRUEBA_DIFICIL := true

## Genera un nivel para el modo infinito con dificultad progresiva.
## - Niveles 1-5: fáciles (tutorial)
## - Niveles 6+: dificultad aleatoria entre difícil y súper difícil
## - Para prueba: todos difícil/súper difícil
static func generar_para_nivel(numero: int) -> Nivel:
	# --- FASE DE PRUEBAS: siempre difícil/súper difícil, en vivo y nuevo ---
	if MODO_PRUEBA_DIFICIL:
		return _generar_en_vivo(numero, 3, 4)

	# --- TUTORIAL (niveles 1-5): pequeños y rapidos, se generan en vivo ---
	if numero <= 5:
		return _generar_en_vivo(numero, 1, 1)

	# --- NIVELES 6+: se sirven desde el POOL PRE-GENERADO ---
	#
	# Por que: los tableros grandes que queremos (600-1400 celdas, 70-120 flechas)
	# tardan 1.5-4.5 s en generarse en vivo, y el nivel se construye AL JUGAR:
	# eso bloquea la UI y en un movil real puede ser varios segundos. Ademas el
	# generador en vivo caia muchas veces a su fallback (tablero 8x8 diminuto),
	# dejando un "dificil" de 16 flechas.
	#
	# Solucion: el pool se genera OFFLINE con tools/generar_pool.gd (el PC puede
	# tardar minutos) y se guarda en src/levels/dificiles.json. El juego solo lo
	# lee => carga instantanea y siempre con la densidad/profundidad pedidas.
	if CargadorDificiles.hay():
		var del_pool := CargadorDificiles.obtener(numero - 6)
		if del_pool != null:
			return del_pool

	# Sin pool disponible: se genera en vivo, pero con tablero MEDIO para que
	# tarde poco. Es peor que el pool, pero nunca un 8x8 diminuto.
	push_warning("Pool de niveles vacio: se genera en vivo (puede tardar).")
	return _generar_en_vivo(numero, 3, 4)

## Genera un nivel en vivo forzando un rango de dificultad (1=facil..4=super).
static func _generar_en_vivo(numero: int, dificultad_minima: int, dificultad_maxima: int) -> Nivel:
	var rng := RandomNumberGenerator.new()
	rng.seed = numero * 2654435761
	# Enredado escalado por nivel (0.0 tutorial .. 1.0 muy avanzado).
	var tangle := tangle_para_nivel(numero)
	
	# Tamaño y densidad según dificultad
	var cols_base: int
	var dens_min: float
	var dens_max: float
	
	match dificultad_minima:
		1:  # Fácil
			cols_base = rng.randi_range(6, 9)
			dens_min = 0.30
			dens_max = 0.50
		2:  # Medio
			cols_base = rng.randi_range(8, 12)
			dens_min = 0.45
			dens_max = 0.65
		3:  # Difícil
			cols_base = rng.randi_range(20, 30)
			dens_min = 0.80
			dens_max = 1.0
		4:  # Súper difícil
			cols_base = rng.randi_range(28, 40)
			dens_min = 0.90
			dens_max = 1.0
	
	var dens := rng.randf_range(dens_min, dens_max)

	var mejor: Nivel = null
	var mejor_score := -1
	# Niveles difíciles necesitan MÁS intentos para alcanzar el listón real de
	# profundidad (antes se Lopaba el primer resultado flojo y se etiquetaba
	# "súper difícil" siendo fácil). Los tutoriales van igual de rápido.
	var formas_a_probar := 4 if dificultad_maxima <= 2 else 10
	var semillas_por_forma := 2 if dificultad_maxima <= 2 else 5
	# Nº de dobleces por flecha. El jugador rockerpointo: las flechas de Amaze
	# GO no tienen un solo doblez, avanzan y giran varias veces (serpentín o
	# espiral). Cada segmento cruza un carril distinto, así que más dobleces =
	# bloquea más corredores = más dificultad.
	var giros := 1 if dificultad_maxima <= 2 else rng.randi_range(2, 5)

	# En niveles difíciles/súper difíciles se usa el GENERADOR POR CÁMARAS:
	# reparte el tablero en cámaras y dibuja una espiral completa en cada una.
	# Es lo que produce las "cámaras rectangulares anidadas" de Amaze GO, con
	# todas las flechas con multiples dobleces y dependencias entre cámaras.
	if dificultad_maxima >= 3:
		for intento_forma in 4:
			var ccols := cols_base + rng.randi_range(-1, 1)
			var cfilas := int(ccols * rng.randf_range(1.3, 1.6))
			var por_camaras := _construir_camaras(
				cfilas, ccols, numero * 100003 + intento_forma * 9173, 3, giros)
			if por_camaras != null:
				return por_camaras
		# Si no se puede, se sigue con el generador clásico.
	for intento_forma in formas_a_probar:
		var cols := cols_base + rng.randi_range(-1, 1)
		var filas := int(cols * rng.randf_range(1.3, 1.6))
		# FORMA DEL TABLERO.
		#
		# En niveles difíciles/súper difíciles usamos RECTÁNGULO COMPLETO, igual
		# que Amaze GO. Antes usaba `figura_dinamica`, que recorta bloques
		# rectangulares de las esquinas y siempre salía la misma silueta
		# escalonada con forma de "L" (el jugador lo señaló: "siempre usamos la
		# misma figura, preferiría el rectángulo completo como en Amaze GO").
		#
		# Referencia (gtxPrime/arrow-escape): los niveles NORMALES usan
		# rectángulo; las siluetas (gato, perro, corazón...) son solo para los
		# niveles Boss/God. Las siluetas quedan para una fase posterior.
		var forma: Array
		if dificultad_maxima <= 2:
			forma = Figuras.figura_dinamica(filas, cols, rng)
		else:
			forma = Figuras.rectangulo(filas, cols)
		if forma.size() < MIN_FLECHAS * 2:
			continue
		var bb := _bbox(forma)
		var objetivo := maxi(MIN_FLECHAS, int(forma.size() * dens / 4.0))
		var nivel := _construir(forma, bb.x, bb.y, objetivo, numero * 100003 + intento_forma * 9173, semillas_por_forma, tangle, giros)
		if nivel == null:
			continue
		var flechas := nivel.tablero.cantidad_flechas()
		var prof := GrafoDependencias.profundidad(nivel.tablero)
		var dif := dificultad(nivel.tablero)
		var dif_num := _dificultad_a_numero(dif)
		
		# Verificar que cumple el rango de dificultad objetivo
		if dif_num >= dificultad_minima and dif_num <= dificultad_maxima:
			if flechas >= MIN_FLECHAS and prof >= MIN_PROFUNDIDAD:
				return nivel
		
		# Guardar el mejor como fallback
		var score := prof * 100 + flechas + dif_num * 50
		if score > mejor_score:
			mejor_score = score
			mejor = nivel
	
	if mejor != null:
		# Aviso: si se devuelve el mejor candidato sin alcanzar el rango pedido,
		# el nivel se quedará por debajo de la dificultad que se le pidió.
		var bd := dificultad(mejor.tablero)
		if _dificultad_a_numero(bd) < dificultad_minima:
			push_warning("Nivel %d: no alcanzó dificultad pedida (obtuvo %s, prof %d, flechas %d)" % [
				numero, bd, GrafoDependencias.profundidad(mejor.tablero),
				mejor.tablero.cantidad_flechas()])
		return mejor
	
	# Fallback: NO caer a un tablero diminuto. Antes usaba un 8x8 (64 celdas,
	# ~16 flechas) querompe la premisa de "niveles difíciles con muchas flechas".
	# Ahora reintenta con un tablero del tamaño MINIMO aceptable para la
	# dificultad pedida y, en ultimo caso, devuelve el mejor candidato hallado
	# aunque no alcance el rango (con un aviso) para no romper el flujo de juego.
	var min_cols := 14 if dificultad_maxima >= 3 else 6
	for intento in 8:
		var cols := min_cols + (intento * 3) % 10
		var filas := int(cols * rng.randf_range(1.3, 1.6))
		var forma := Figuras.figura_dinamica(filas, cols, rng)
		if forma.size() < MIN_FLECHAS * 2:
			continue
		var bb := _bbox(forma)
		var lv := _construir(forma, bb.x, bb.y, maxi(MIN_FLECHAS, int(forma.size() * dens / 4.0)), numero * 100003 + 555 + intento * 313, 3, tangle)
		if lv != null:
			return lv
	if mejor != null:
		push_warning("Nivel %d: no alcanzo la dificultad objetivo; se usa el mejor candidato." % numero)
		return mejor
	# Ultimo recurso: un tablero decente (no 8x8) para que el juego nunca se rompa.
	var rect := Figuras.rectangulo(maxi(10, min_cols), maxi(10, min_cols))
	var bbr := _bbox(rect)
	return _construir(rect, bbr.x, bbr.y, 10, numero * 100003 + 555, 60, tangle)

## Convierte dificultad string a número para comparaciones
static func _dificultad_a_numero(dif: String) -> int:
	match dif:
		"dif_facil": return 1
		"dif_medio": return 2
		"dif_dificil": return 3
		"dif_super": return 4
	return 1

# MÍNIMOS que todo nivel de este modo debe cumplir (evitan niveles triviales).
const MIN_FLECHAS := 8       # nunca menos de 8 flechas
const MIN_PROFUNDIDAD := 3   # cadenas de dependencia de al menos 3 capas

## Nº de candidatos válidos que se exigen por colocación. Con flechas largas
## (patrón Amaze GO) encontrar 6 candidatas es muy restrictivo y hacía fallar la
## generación; con 3 hay suficiente variación para puntuar y no se cae el nivel.
const CANDIDATOS_MIN := 3

## Compat: relleno por figura con nº de flechas automático.
static func generar_relleno(p_forma: Array, p_filas: int, p_columnas: int,
		_long_max: int = 6, p_semilla: int = -1, p_intentos: int = 60) -> Nivel:
	var n := clampi(p_forma.size() / 5, 6, 40)
	return _construir(p_forma, p_filas, p_columnas, n, p_semilla, p_intentos)

## Construcción inversa con bloqueo obligatorio. Reintenta con semillas.
## `tangle` controla el enredado de los caminos (0.0 recto .. 1.0 zig-zag).
static func _construir(forma: Array, filas: int, columnas: int, n_flechas: int,
		semilla_base: int, intentos: int, tangle: float = 1.0,
		giros: int = 3) -> Nivel:
	var G: int = maxi(filas, columnas)
	var mejor: Nivel = null
	var mejor_score := -1.0
	for intento in intentos:
		var semilla := semilla_base + intento * 997
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla

		var tablero := Tablero.new(filas, columnas)
		var celdas_forma: Array[Vector2i] = []
		for c in forma:
			var cv: Vector2i = c
			tablero.agregar_celda(cv)
			celdas_forma.append(cv)

		var orden: Array = []
		# Conteo de bloqueadores POR flecha, mantido INCREMENTALMENTE.
		# Antes se recalculaba con GrafoDependencias para todas las flechas en cada
		# colocacion (O(n^2) con corredores) => 40 s por nivel en tableros grandes.
		# El corredor de salida de una flecha es FIJO, asi que al colocar una
		# flecha solo hay que sumar 1 a cada flecha cuyo corredor pisa. O(n) total.
		var n_bloq: Dictionary = {}
		# Árbol de dependencias: controlamos su FORMA en vez de dejarla al azar.
		# `prof_arbol` = profundidad de cada flecha; `hijos` = cuántas
		# desbloquea. Así se fijan la cadena (objetivo) y la ramificación (tope),
		# que es lo que evita la cinta transportadora.
		var prof_arbol: Dictionary = {}
		var hijos: Dictionary = {}
		var n_esp := maxi(1, int(celdas_forma.size() * 0.22))
		var target_prof := maxi(8, int(n_esp * 0.35))
		var max_hijos := 4
		# SATURA el tablero: coloca flechas hasta que no quepan más (densidad
		# alta, estilo Amaze GO). En cada colocación, SESGA hacia dificultad
		# eligiendo el candidato que deja MENOS flechas jugables (idea de UnStack).
		var guardia := celdas_forma.size() + 5
		# Nº de flechas que esperamos saturar: guia el plan de longitudes.
		var n_esperado := maxi(1, int(celdas_forma.size() * 0.22))
		while guardia > 0:
			guardia -= 1
			var i := orden.size()
			# Orden de longitudes inverso: las PRIMERAS son las más largas
			# (enredan el tablero desde el principio), las últimas cortas.
			var long_obj := _long_por_orden(i, n_esperado, rng, G)
			var flecha := _colocar_sesgado(
				tablero, celdas_forma, rng, i, G, n_bloq, tangle, long_obj, giros,
				prof_arbol, hijos, target_prof, max_hijos)
			if flecha == null:
				break   # saturado: no caben más flechas -> listo
			tablero.colocar(flecha)
			orden.append(flecha.id)
			# Actualiza el conteo incremental de bloqueadores.
			n_bloq[flecha.id] = 0
			_registrar_bloqueos(tablero, flecha, n_bloq)
			# Actualiza el árbol: profundidad = 1 + la del padre más profundo
			# entre las flechas que esta bloquea.
			var prof_nueva := 0
			for c in flecha.celdas:
				var hit: int = tablero.ocupacion.get(c, -1)
				if hit >= 0 and hit != flecha.id:
					prof_nueva = maxi(prof_nueva, 1 + int(prof_arbol.get(hit, 0)))
					hijos[hit] = int(hijos.get(hit, 0)) + 1
			prof_arbol[flecha.id] = prof_nueva
			hijos[flecha.id] = int(hijos.get(flecha.id, 0))
		# GENERADOR B (relleno): tapa los huecos restantes con flechas CORTAS
		# disparables, para que el tablero se vea lleno (como Amaze GO), sin
		# romper la solubilidad (cada una entra disparable = sale primero).
		# Relleno: flechas LARGAS y con tope de cantidad.
		#
		# MEDIDO (semilla 115133368110587): con relleno de longitud 2-4 salían
		# 164 flechas, 156 de ellas de 2-5 celdas: el nivel era TEDIOSO (muchas
		# jugadas mecánicas), no difícil. Amaze GO "Súper Difícil" ronda las
		# 60-70 flechas. Aquí se rellena con flechas de 6-14 celdas y se para al
		# llegar al objetivo de flechas del nivel.
		# Cantidad de flechas por la FORMULA de la referencia: n^2/10 para n>=10
		# (n = lado menor del tablero). Antes era un 10% de las celdas con topes
		# fijos de 40-78, que no escalaba con el tamaño del tablero.
		var n_lado := mini(tablero.filas, tablero.columnas)
		var objetivo_flechas := maxi(MIN_FLECHAS, _flechas_objetivo(n_lado))
		_rellenar_huecos(tablero, celdas_forma, rng, orden, 3, 6, 14, objetivo_flechas)
		if orden.size() < 6:
			continue

		# SOLUCIÓN: se recalcula con el solver sobre el tablero FINAL.
		#
		# Antes se usaba "orden inverso de colocación", que en teoría es válido
		# (la última colocada sale primero). PERO `_absorber_sobrantes` mueve
		# celdas entre flechas DESPUÉS de colocarlas, y eso rompe esa garantía:
		# MEDIDO en el nivel semilla 53492901886772 el nivel era resoluble pero
		# la solución guardada NO lo vaciaba ("solucion valida: NO" en el panel
		# de diagnóstico del juego).
		#
		# El solver simula salidas reales sobre el tablero final, así que el
		# orden que devuelve siempre es válido.
		var solucion := GrafoDependencias.orden_solucion(tablero)
		if solucion.is_empty():
			continue

		# GENERAR-Y-ELEGIR: antes se devolvía el PRIMER nivel que pasaba un
		# umbral flojo (prof >= 3), asi que se aceptaban niveles debiles
		# (medido: 23-34 flechas con profundidad 4-5 etiquetados "difícil").
		# Ahora se prueban TODOS los intentos y se queda con el MEJOR.
		var prof := GrafoDependencias.profundidad(tablero)
		var ratio := GrafoDependencias.ratio_bloqueo(tablero)
		var nf := tablero.cantidad_flechas()
		# PUNTUACIÓN DE DIFICULTAD REAL (ver src/core/metricas.gd).
		# - `cadena` = cuántas jugadas hay que planificar de antemano.
		# - `libres` = cuántas flechas se sacan SIN pensar al abrir el nivel.
		#   Este último término es lo que ataca el reporte "muchas flechas que
		#   salen fácil": se penaliza que el nivel venga con muchas jugadas gratis.
		var cadena := Metricas.cadena_mas_larga(tablero)
		var libres := Metricas.libres_iniciales(tablero)
		var cebo := Metricas.cebos(tablero, 3)
		var score := float(cadena) * 10.0 + float(prof) * 2.0 + float(nf) * 0.05
		score -= (float(libres) / maxf(1.0, float(nf))) * 60.0
		# EXCESO DE FLECHAS: por encima de ~85 el nivel se vuelve tedioso
		# (muchas jugadas mecánicas) en vez de difícil. Referencia Amaze GO:
		# ~60-70 flechas en "Súper Difícil". Se penaliza fuerte.
		if nf > 85:
			score -= float(nf - 85) * 6.0
		# Cebos: flechas que PARECEN libres. Es lo que el jugador pedia
		# ("cuesta detectar cuales no estan bloqueadas").
		score += (float(cebo) / maxf(1.0, float(nf))) * 50.0
		# COMPONENTES del grafo: un nivel difficult debe ser UNA masa
		# interconectada. Varias componentes = islas de flechas que nadie
		# bloquea = movimientos gratis (comparado con dos pantallazos reales
		# de Amaze GO: el "Súper Difícil" era 1 componente; el "Difícil" que
		# se resolvió rápido tenía islas sueltas).
		var comps := Metricas.componentes(tablero)
		score -= float(comps - 1) * 400.0
		if score > mejor_score:
			mejor_score = score
			mejor = Nivel.new(tablero, solucion, semilla)

	# Devuelve el MEJOR de los intentos. Si ninguno passes validación estricta,
	# devuelve igualmente el mejor (con aviso): mejor un nivel flojo que un
	# tablero diminuto de emergencia.
	if mejor == null:
		return null
	if not _validar_dificultad(mejor.tablero, 3):
		push_warning("Nivel flojo (prof %d, flechas %d) con semilla %d" % [
			GrafoDependencias.profundidad(mejor.tablero),
			mejor.tablero.cantidad_flechas(), mejor.semilla])
	return mejor

## GENERADOR B: rellena huecos con flechas CORTAS disparables. Los agrega al
## orden (salen primero = resolubles por construcción). Al final, absorbe celdas
## sueltas extendiendo la cola de una flecha vecina.
static func _rellenar_huecos(tablero: Tablero, celdas_forma: Array[Vector2i],
		rng: RandomNumberGenerator, orden: Array, rondas: int = 4,
		len_min: int = 2, len_max: int = 4, max_flechas: int = 9999) -> void:
	# Rellena huecos con flechas disparables.
	#
	# MEDIDO (semilla 115133368110587): con longitudes 2-4 el relleno inundaba el
	# tablero: 164 flechas de las cuales 156 medían 2-5 celdas y solo 1 era
	# larga. El jugador tardaba por CANTIDAD de jugadas mecánicas, no por
	# pensar. Amaze GO "Súper Difícil" tiene ~60-70 flechas de media ~9 celdas.
	#
	# Ahora el relleno usa flechas LARGAS (por defecto 6-14) y para al alcanzar
	# `max_flechas`, para que la densidad de flechas se parezca a la referencia.
	for _ronda in rondas:
		if orden.size() >= max_flechas:
			break
		var progreso := true
		while progreso:
			progreso = false
			if orden.size() >= max_flechas:
				break
			for celda in celdas_forma:
				if orden.size() >= max_flechas:
					break
				if tablero.esta_ocupada(celda):
					continue
				# Prueba varias longitudes en el rango pedido.
				for _try in 20:
					var longitud := rng.randi_range(len_min, maxi(len_min, len_max))
					var camino := _camino_con_gancho(tablero, celda, longitud, rng)
					if camino.size() < 2:
						continue
					var f := Flecha.new(orden.size(), camino, COLORES_SUAVES[orden.size() % COLORES_SUAVES.size()])
					if _disparable(tablero, f):
						tablero.colocar(f)
						orden.append(f.id)
						progreso = true
						break
		# Tras saturar de flechas cortas, absorbe lo suelto en colas vecinas.
		_absorber_sobrantes(tablero)

## Absorbe celdas libres sueltas extendiendo la COLA de una flecha vecina (no
## cambia la dirección de salida, que depende de la cabeza). Reduce huecos.
static func _absorber_sobrantes(tablero: Tablero) -> void:
	var progreso := true
	while progreso:
		progreso = false
		for celda in tablero.jugables.keys():
			if tablero.esta_ocupada(celda):
				continue
			for d in DIRS:
				var vecino: Vector2i = celda + d
				if not tablero.esta_ocupada(vecino):
					continue
				var fid: int = tablero.ocupacion[vecino]
				var flecha: Flecha = tablero.flechas[fid]
				if flecha.cola() == vecino:
					var nuevas: Array[Vector2i] = [celda]
					nuevas.append_array(flecha.celdas)
					tablero.quitar(fid)
					tablero.colocar(Flecha.new(fid, nuevas, flecha.color))
					progreso = true
					break

## Coloca una flecha eligiendo entre varios candidatos el que deja MENOS flechas
## jugables (sesgo de dificultad). Genera hasta N candidatos válidos (disparables)
## y prueba cuántas flechas quedarían jugables tras colocar cada uno; elige el
## que MÁS reduce las jugadas disponibles -> cadenas de dependencia más profundas.
##
## MEJORA: el sesgo ya no simula el grafo completo (clonar + Profundidad por
## candidato), porque con tableros de 1000+ celdas la generacion tardaba minutos
## y el nivel se construye AL JUGAR. Ahora puntua de forma local y O(n):
##   - bloqueos        : cuantos corredores de salida pisa (aristas nuevas).
##   - extiende_cadena : de esas, cuantas flechas YA estaban bloqueadas por
##                       otra -> alarga la cadena A->B->C (la profundidad real).
##   - sobreviven      : cuantas flechas siguen sacables (menos = mas encerrado).
##   - penal_borde     : penaliza flechas que apuntan hacia afuera (faciles).
##
## MEJORA 2: Las flechas en los bordes NO deben apuntar todas hacia afuera.
## Se penaliza a los candidatos cuya dirección de salida apunta hacia el borde
## más cercano (fáciles de sacar) y se prefieren los que apuntan hacia adentro.
## Coloca una flecha eligiendo entre candidatos, guiando la FORMA del grafo de
## dependencias para que sea un ÁRBOL controlado en vez de lo que salga.
##
## INSPIRACIÓN (fuera de la especificación): un desarrollador con el mismo
## problema fortifications que el nuestro (r/gamedev, r/algorithms) reçibió este
## consejo: "si consigues crear un laberinto resoluble con uno de esos
## algoritmos, luego puedes amoldarlo al puzle que quieras". La idea: una
## estructura acíclica garantizada (un árbol) primero, y la geometría después.
##
## POR QUÉ IMPORTA: antes la resolubilidad dependía de exigir `_disparable` en
## cada colocación, y eso a su vez obligaba a flechas casi rectas (una espiral
## completa casi nunca tiene el corredor libre). Con el árbol, la aciclicidad
## la garantiza la ESTRUCTURA, no la geometría, así que se pueden usar caminos
## Espirales sin miedo a los ciclos.
##
## Para que no sea una cinta transportadora (el jugador: "salía la primera y se
## desbloqueaban las otras una tras otra"), se controla:
##  - `target_prof`: profundidad deseada del árbol (cadena de dependencias).
##  - `max_hijos`: cuántas flechas puede desbloquear como máximo cada una.
##    Forzar el límite reparte las dependencias en varios sitios y obliga a
##    elegir.
static func _colocar_sesgado(
	tablero: Tablero, celdas_forma: Array[Vector2i], rng: RandomNumberGenerator,
	id: int, G: int, n_bloq: Dictionary, tangle: float, long_objetivo: int,
	giros: int = 3, prof_arbol: Dictionary = {}, hijos: Dictionary = {},
	target_prof: int = 0, max_hijos: int = 99
) -> Flecha:
	var candidatos: Array[Flecha] = []
	# Búsquedas para reunir candidatos. 80 era overkill (solo buscamos 6
	# candidatos válidos) y multiplicaba el coste de la generación offline.
	#
	# Si la longitud objetivo no cabe (flechas muy largas en un tablero ya
	# ocupado), NO se abandona: se reintenta con longitudes progresivamente
	# menores. Antes, si no se encontraba ninguna flecha de la longitud pedida,
	# el bucle de saturación se rompia y el tablero quedaba con POQUAS flechas
	# (medido: 27 flechas en vez de ~90).
	for factor in [1.0, 0.7, 0.5, 0.35, 0.22, 0.12]:
		var busquedas := 34 if factor >= 1.0 else 16
		# ESTRATEGIA A (preferida): RESERVAR una región vacía y dibujar dentro una
		# espiral/serpentín completa. Así la flecha tiene varios dobleces de
		# verdad, que es lo que faltaba.
		if candidatos.size() < CANDIDATOS_MIN and busquedas > 0:
			busquedas -= 1
			var region := _mejor_region_libre(tablero, tablero.filas, tablero.columnas)
			if region.size.x >= 4 and region.size.y >= 3:
				# Se prueban TODAS las variantes (serpentín + espiral desde cada
				# esquina). Antes solo una, y casi nunca era disparable: el
				# corredor de salida de una espiral depende de por dónde entra.
				for v in 5:
					var camino_r := _camino_en_region(tablero, region, rng, v)
					if camino_r.size() < 4:
						continue
					var fr := Flecha.new(id, camino_r, COLORES_SUAVES[id % COLORES_SUAVES.size()])
					if _disparable(tablero, fr):
						candidatos.append(fr)
						break
		while candidatos.size() < CANDIDATOS_MIN and busquedas > 0:
			busquedas -= 1
			var inicio: Vector2i = celdas_forma[rng.randi_range(0, celdas_forma.size() - 1)]
			if tablero.esta_ocupada(inicio):
				continue
			var longitud := maxi(2, int(round(float(long_objetivo) * factor)))
			# ESTRATEGIA B (respaldo): serpentín/espiral improvisado.
			var camino := _camino_espiral(tablero, inicio, longitud, rng, giros)
			if camino.size() < 2:
				continue
			var flecha := Flecha.new(id, camino, COLORES_SUAVES[id % COLORES_SUAVES.size()])
			if not _disparable(tablero, flecha):
				continue
			candidatos.append(flecha)
		if candidatos.size() >= CANDIDATOS_MIN:
			break
	if candidatos.is_empty():
		return null
	# Evalúa cada candidato por PROFUNDIDAD REAL del grafo resultante.
	var mejor: Flecha = null
	var mejor_score := -999999
	# Precalcula corredores de salida y cuantos bloqueadores tiene cada flecha
	# (barato: una vez por colocacion, no por candidato).
	var corredores: Array = []
	var corridor_a_id: Array = []
	for fid in tablero.flechas.keys():
		var f: Flecha = tablero.flechas[fid]
		corredores.append(_corredor_salida(tablero, f))
		corridor_a_id.append(fid)
	for cand in candidatos:
		var cuerpo := {}
		for c in cand.celdas:
			cuerpo[c] = true
		var bloqueos := 0
		var extiende_cadena := 0
		var engaña := 0
		var distancia_bloqueo := 0
		var prof_creada := 0
		var sobrecarga := 0
		for i in corredores.size():
			var pisa := false
			for celda in (corredores[i] as Dictionary).keys():
				if cuerpo.has(celda):
					pisa = true
					break
			if not pisa:
				continue
			bloqueos += 1
			# Si la flecha bloqueada YA estaba bloqueada por otra, la cadena
			# se alarga (A bloquea a B que ya dependia de C) = mas profundidad.
			if int(n_bloq.get(corridor_a_id[i], 0)) > 0:
				extiende_cadena += 1
			# Cebo: el bloqueo debe caer LEJOS de la salida. Se recompensa la
			# DISTANCIA de forma lineal, no solo un umbral: interesa que el
			# carril esté largo y limpio y el bloqueo aparezca al final.
			# Medido: conpremio binario (dist>=3) apenas salían cebos (1-5%)
			# porque todo se bloqueaba en la nariz.
			var bloq: Flecha = tablero.flechas[corridor_a_id[i]]
			var paso_b := bloq.direccion_salida()
			var act_b := bloq.cabeza() + paso_b
			var dist := 0
			while tablero.es_jugable(act_b):
				if cuerpo.has(act_b):
					break
				act_b += paso_b
				dist += 1
			distancia_bloqueo += dist
			if dist >= 3:
				engaña += 1
			# Datos del árbol que formaría este candidato.
			var prof_b: int = int(prof_arbol.get(corridor_a_id[i], 0))
			if 1 + prof_b > prof_creada:
				prof_creada = 1 + prof_b
			if int(hijos.get(corridor_a_id[i], 0)) >= max_hijos:
				sobrecarga += 1
		# CONECTIVIDAD: si la flecha NO bloquea el corredor de ninguna ya
		# colocada, queda como nodo AISLADO del grafo de dependencias.
		#
		# MEDIDO: sin este filtro, el 100% de los niveles (7 de 7) salía con
		# 2-4 islas sueltas. Esas islas nadie las bloquea => se sacan gratis de
		# inmediato, y el nivel se resuelve rápido. Comparado con los
		# pantallazos reales de Amaze GO: el "Súper Difícil" (68) era una sola
		# masa interconectada; el "Difícil" (70), que se resolvió rápido, tenía
		# islas sueltas abajo.
		#
		# La primera flecha del tablero no tiene a quién bloquear: se permite.
		if bloqueos == 0 and not corredores.is_empty():
			continue
		# Cuantas flechas siguen siendo sacables: cuanto menos, mas encerrado.
		#
		# PESO DE "sobreviven": estaba en 3, muy por debajo de bloqueos*12, y eso
		# media que el generador NO priorizaba encerrar el tablero. Medido: el
		# jugador reportaba "muchas flechas que salen fácil" (libres@0 de 35-45%).
		# Ese es exactamente el término que lo arregla, así que sube a 18.
		var sobreviven := tablero.flechas.size() - bloqueos
		var penal_borde := _penalizacion_borde(tablero, cand)
		# Términos de ÁRBOL: se acerca a la profundidad objetivo sin pasarse, y
		# penaliza saturar un nodo (eso convierte el grafo en cinta).
		var term_prof := 0.0
		if target_prof > 0:
			term_prof = -absf(float(prof_creada) - float(target_prof)) * 6.0
			if prof_creada >= target_prof:
				term_prof -= 25.0
		var score := (
			extiende_cadena * 40
			+ bloqueos * 12
			+ engaña * 10
			+ distancia_bloqueo * 2
			- sobreviven * 26
			- penal_borde * 25
			- sobrecarga * 18
			+ term_prof
			+ rng.randi_range(0, 3)
		)
		if score > mejor_score:
			mejor_score = score
			mejor = cand
	return mejor

## Registra, de forma INCREMENTAL, a que flechas bloquea la nueva flecha `f`.
## El corredor de salida de cada flecha es fijo, asi que basta con recorrer las
## celdas del cuerpo de `f` y ver a quien pisan. Actualiza `n_bloq` in-place.
static func _registrar_bloqueos(tablero: Tablero, f: Flecha, n_bloq: Dictionary) -> void:
	for celda in f.celdas:
		var hit: int = tablero.ocupacion.get(celda, -1)
		if hit >= 0 and hit != f.id:
			n_bloq[hit] = int(n_bloq.get(hit, 0)) + 1

## Calcula una penalización si la flecha apunta hacia el borde más cercano.
## Las flechas que apuntan hacia afuera son fáciles de sacar, así que las
## penalizamos para hacer el nivel más difícil.
static func _penalizacion_borde(tablero: Tablero, cand: Flecha) -> int:
	var cabeza := cand.cabeza()
	var ds := cand.direccion_salida()
	var penalizacion := 0
	# Verificar si la cabeza está cerca de un borde y la dirección apunta hacia afuera
	var dist_borde := _distancia_borde(tablero, cabeza)
	if dist_borde <= 2:
		# ¿La dirección apunta hacia afuera?
		var siguiente: Vector2i = cabeza + ds
		if not tablero.es_jugable(siguiente):
			# Apunta hacia afuera = fácil = penalizar
			penalizacion = 3
		elif dist_borde <= 1:
			# Muy cerca del borde, penalizar un poco
			penalizacion = 1
	return penalizacion

## Calcula la distancia al borde más cercano.
static func _distancia_borde(tablero: Tablero, celda: Vector2i) -> int:
	var min_dist := 999999
	# Distancia a cada borde
	min_dist = mini(min_dist, celda.x)  # arriba
	min_dist = mini(min_dist, tablero.filas - 1 - celda.x)  # abajo
	min_dist = mini(min_dist, celda.y)  # izquierda
	min_dist = mini(min_dist, tablero.columnas - 1 - celda.y)  # derecha
	return min_dist

## Cuenta cuántos corredores de salida bloquea una flecha candidata.
static func _contar_bloqueos(tablero: Tablero, cand: Flecha) -> int:
	var corredores: Array = []
	for fid in tablero.flechas.keys():
		corredores.append(_corredor_salida(tablero, tablero.flechas[fid]))
	var bloqueos := 0
	var cuerpo := {}
	for c in cand.celdas:
		cuerpo[c] = true
	for corr in corredores:
		for celda in corr.keys():
			if cuerpo.has(celda):
				bloqueos += 1
				break
	return bloqueos

## Intenta colocar UNA flecha: disparable ahora y (si debe_bloquear) que bloquee
## el corredor de alguna flecha ya colocada. Prueba muchos inicios/longitudes.
static func _intentar_colocar(
	tablero: Tablero, celdas_forma: Array[Vector2i], rng: RandomNumberGenerator,
	id: int, G: int, debe_bloquear: bool
) -> Flecha:
	# Corredores de salida actuales (para exigir bloqueo).
	var corredores: Array = []
	if debe_bloquear:
		for fid in tablero.flechas.keys():
			corredores.append(_corredor_salida(tablero, tablero.flechas[fid]))

	var attempts := 300
	for _a in attempts:
		var inicio: Vector2i = celdas_forma[rng.randi_range(0, celdas_forma.size() - 1)]
		if tablero.esta_ocupada(inicio):
			continue
		var longitud := _long_por_tier(rng, G)
		var camino := _camino_serpiente(tablero, inicio, longitud, rng)
		if camino.size() < 2:
			continue
		# Construimos Flecha para consultar su dirección de salida y disparable.
		var flecha := Flecha.new(id, camino, COLORES_SUAVES[id % COLORES_SUAVES.size()])
		# ¿Disparable AHORA? (corredor de su cabeza libre hasta el borde)
		if not _disparable(tablero, flecha):
			continue
		# ¿Bloquea a alguna existente?
		if debe_bloquear and not _bloquea(camino, corredores):
			continue
		return flecha
	return null

## Longitud por tiers (muy larga / larga / media / corta) como el repo.
static func _long_por_tier(rng: RandomNumberGenerator, G: int) -> int:
	var t := rng.randi_range(0, 99)
	# Predominan las CORTAS (densidad alta, muchas flechas como Amaze GO).
	# Unas pocas largas cruzan y crean los bloqueos profundos.
	if t < 55:
		return rng.randi_range(2, 3)                   # corta (mayoría)
	elif t < 80:
		return rng.randi_range(3, maxi(3, G / 3))      # media
	elif t < 95:
		return rng.randi_range(maxi(3, G / 3), G)      # larga
	return rng.randi_range(G, 2 * G)                   # muy larga (pocas, enreda)

## Longitud objetivo para la flecha nº `i` de `n`, en orden INVERSO.
##
## Referencia: gtxPrime/arrow-escape, "Phase 1: Reverse Arrow Placement
## (Very Long -> Long -> Medium)" seguido de "Phase 2: Gap Fill with 2-Cell
## Arrows".
##
## Por que: en construcción inversa la 1ª flecha colocada es la ÚLTIMA en salir.
## Si las primeras son las MÁS largas, enredan el tablero entero desde el
## principio y cada flecha posterior queda bloqueada por ellas -> grafo de
## dependencias profundo. Si alternamos longitudes al azar (lo que haciamos),
## las largas se reparten y apenas enredan nada.
static func _long_por_orden(
	i: int, n: int, rng: RandomNumberGenerator, G: int
) -> int:
	if n <= 1:
		return rng.randi_range(2, maxi(2, G))

	# DISTRIBUCIÓN CALIBRADA CON AMZE GO (patrón "cuerpo largo + gancho").
	#
	# Antes (medido, semilla 12345): 43% de flechas de 2-4 celdas y unas pocas
	# gigantes de 26-51. Bimodal: muchas flechitas inútiles + pocas gigantes.
	# Las flechitas de 2-4 celdas son las que "salen fácil" y no aportan
	# dependencias: son relleno visual, no dificultad.
	#
	# Ahora: la mayoría son largas (8-25) y unas pocas muy largas. La longitud
	# es el recurso escaso (celdas del tablero), así que se reparte en esa banda
	# media-alta donde aporta bloqueo de verdad.
	var frac := float(i) / float(n)
	var t := rng.randf()
	if frac < 0.08:
		# Alguna muy larga: enreda el tablero desde el principio.
		return clampi(int(rng.randf_range(float(G * 0.35), float(G * 0.60))), 8, G)
	if t < 0.14:
		# Pocas cortas, solo para variedad visual.
		return rng.randi_range(2, 4)
	elif t < 0.55:
		# Mayoría: largas (8-14).
		return rng.randi_range(8, maxi(9, int(G * 0.35)))
	elif t < 0.88:
		# Largas (12-20).
		return rng.randi_range(12, maxi(13, int(G * 0.48)))
	# Muy largas (18-26): pocas, son las que más bloquean.
	return rng.randi_range(18, maxi(19, int(G * 0.62)))

## REPARTE el tablero en CÁMARAS rectangulares de tamaños irregulares.
##
## Este es el cambio de fondo para parecerse a Amaze GO. MEDIDO: si las
## espirales se dibujan " improvised" sobre el tablero ya lleno, se cortan
## (26-47% de flechas con 0 giros) y cada espiral gigante devora el tablero
## dejando huecos donde solo caben rectas.
##
## En vez de eso se reparte el tablero en cámaras ANTES de colocar nada, y en
## cada cámara se dibuja UN serpentín/espiral completo. Resultado:
##  - Todas las flechas tienen varios dobleces (nada de rectas).
##  - Las cámaras se ADOSAN, así que la flecha de una cámara sale cruzando la
##    cámara vecina: eso crea las dependencias entre cámaras (cadenas hondas).
static func _camaras(filas: int, cols: int, rng: RandomNumberGenerator) -> Array:
	# Cortes horizontales y verticales en segmentos irregulares.
	var cortes_h := _cortes(filas, rng, 3, 8)
	var cortes_v := _cortes(cols, rng, 3, 7)
	var res: Array = []
	for i in range(cortes_h.size() - 1):
		for j in range(cortes_v.size() - 1):
			var f0: int = cortes_h[i]
			var f1: int = cortes_h[i + 1]
			var c0: int = cortes_v[j]
			var c1: int = cortes_v[j + 1]
			var r := Rect2i(c0, f0, c1 - c0, f1 - f0)
			# Cámara mínima viable para una espiral con dobleces.
			if r.size.x >= 4 and r.size.y >= 3:
				res.append(r)
	# Baraja el orden de colocación (en construcción inversa influences la
	# estructura del grafo).
	for i in range(res.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = res[i]
		res[i] = res[j]
		res[j] = tmp
	return res

## Devuelve una lista de cortes que particionan [0, total) en `n` segmentos
## irregulares de tamaño minimo `minimo`.
static func _cortes(total: int, rng: RandomNumberGenerator, n: int, minimo: int) -> Array:
	var cortes := [0]
	var restante := total
	var quedan := n
	while quedan > 1:
		# Se reserva minimo para los segmentos que faltan.
		var max_tomo := restante - minimo * (quedan - 1)
		if max_tomo <= minimo:
			break
		var toma := rng.randi_range(minimo, max_tomo)
		cortes.append(cortes[cortes.size() - 1] + toma)
		restante -= toma
		quedan -= 1
	cortes.append(total)
	return cortes

## Cantidad de flechas segun el lado del tablero (formula de la referencia
## sergev/goarrows): n<6 -> n ; n<10 -> n^2/6 ; n>=10 -> n^2/10.
## Para 30x30 son 90 flechas; para 40x40, 160.
static func _flechas_objetivo(n: int) -> int:
	if n < 6:
		return n
	if n < 10:
		return n * n / 6
	return n * n / 10

## Construye un nivel por CÁMARAS: una flecha serpentín/espiral por cámara.
##
## Cada camino se dibuja COMPLETO dentro de su cámara (no se corta), así que
## todas las flechas tienen varios dobleces. Luego se valida el grafo con el
## solver y se exige una sola componente conexa.
static func _construir_camaras(
	filas: int, columnas: int, semilla_base: int, intentos: int, giros: int
) -> Nivel:
	var G: int = maxi(filas, columnas)
	var mejor: Nivel = null
	var mejor_score := -1e9
	for intento in intentos:
		var semilla := semilla_base + intento * 997
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla
		var tablero := Tablero.new(filas, columnas)
		for f in filas:
			for c in columnas:
				tablero.agregar_celda(Vector2i(f, c))
		var cams := _camaras(filas, columnas, rng)
		var id := 0
		var colocadas := 0
		for cam in cams:
			var region: Rect2i = cam
			# Se intenta el serpentín; si la región está sucia, se recorta.
			var camino := _camino_en_region(tablero, region, rng)
			if camino.size() < 4:
				continue
			var flecha := Flecha.new(id, camino, COLORES_SUAVES[id % COLORES_SUAVES.size()])
			# NO se exige que sea disparable AHORA. En una cámara, el corredor de
			# salida casi nunca está libre, y exigirlo impedía el enredo (medido:
			# se rechazaba casi todo y el nivel salía con pocas flechas rectas).
			# Lo que sí se exige es que la flecha no se AUTOBLOQUEE con su propio
			# cuerpo; la validez global la comprueba el solver después.
			if not _sin_autobloqueo(tablero, flecha):
				continue
			tablero.colocar(flecha)
			id += 1
			colocadas += 1
		# Se necesitan suficientes flechas y una cadena decente: si no, el
		# intento se descarta y se prueba otra partición.
		if colocadas < 20:
			continue
		var solucion := GrafoDependencias.orden_solucion(tablero)
		if solucion.is_empty():
			continue
		var cadena := Metricas.cadena_mas_larga(tablero)
		var comps := Metricas.componentes(tablero)
		var libres := Metricas.libres_iniciales(tablero)
		var nf := tablero.cantidad_flechas()
		var score := float(cadena) * 12.0 + float(nf) * 0.05
		score -= (float(libres) / maxf(1.0, float(nf))) * 60.0
		score -= float(comps - 1) * 400.0
		if score > mejor_score:
			mejor_score = score
			mejor = Nivel.new(tablero, solucion, semilla)
	return mejor

## Busca la región rectangular MÁS VACÍA del tablero, para poder dibujar una
## espiral completa dentro sin que se corte al chocar con nada.
##
## MEDIDO: la espiral "improvisada" (la que avanzaba hasta el primer obstáculo)
## se cortaba siempre -> 29-42% de flechas con 0 giros y 45% con 1 solo. Ahora se
## RESERVA la región primero y luego se dibuja dentro, que es lo que produce
## las cámaras rectangulares anidadas de Amaze GO.
##
## Devuelve un Rect2i con origen y tamaño, o Rect2i() si no cabe nada.
static func _mejor_region_libre(
	tablero: Tablero, filas: int, columnas: int
) -> Rect2i:
	# matriz de libres
	var libre := []
	for f in filas:
		var fila: Array[bool] = []
		for c in columnas:
			fila.append(tablero.es_jugable(Vector2i(f, c)) and not tablero.esta_ocupada(Vector2i(f, c)))
		libre.append(fila)
	# histogramas: para cada fila, altura de libres consecutivos desde esa fila
	var mejor := Rect2i()
	var mejor_area := 0
	var alto := 0
	for f in filas:
		for c in columnas:
			if libre[f][c]:
				alto += 1
			else:
				alto = 0
			# ancho disponible hacia la derecha desde (f,c)
			var ancho := 0
			var cc := c
			while cc < columnas and libre[f][cc]:
				ancho += 1
				cc += 1
			var area := ancho * alto
			if area > mejor_area and ancho >= 4 and alto >= 4:
				mejor_area = area
				mejor = Rect2i(c, f, ancho, alto)
	return mejor

## Dibuja una ESPIRAL / SERPENTÍN completa dentro de una región reservada.
##
## Dos estilos (ambos con varios dobleces, como en Amaze GO):
##  - ESPIRAL: va por el borde y se enrolla hacia dentro (capas concéntricas).
##  - SERPENTÍN: recorre la región en filas de ida y vuelta.
##
## La DIRECCIÓN DE SALIDA es la del último segmento, y se orienta para que
## apunte hacia fuera de la región (así es más fácil que sea disparable).
static func _camino_en_region(
	tablero: Tablero, region: Rect2i, rng: RandomNumberGenerator, variante: int = -1
) -> Array[Vector2i]:
	var camino: Array[Vector2i] = []
	if region.size.x < 2 or region.size.y < 2:
		return camino
	var x0 := region.position.x
	var y0 := region.position.y
	var w := region.size.x
	var h := region.size.y
	var usada := {}
	# variante: 0 serpentin, 1..4 espiral desde cada esquina (giro inicial).
	if variante < 0:
		variante = rng.randi_range(0, 4)

	var libre := func(x: int, y: int) -> bool:
		if x < x0 or y < y0 or x >= x0 + w or y >= y0 + h:
			return false
		var v := Vector2i(y, x)
		return tablero.es_jugable(v) and not tablero.esta_ocupada(v) and not usada.has(v)

	if variante == 0:
		# SERPENTÍN: filas horizontales de ida y vuelta (2 orientaciones).
		var invert := variante == 0 and rng.randf() < 0.5
		var y := y0
		var hacia_derecha := not invert
		while y < y0 + h:
			var x := x0 if hacia_derecha else x0 + w - 1
			var paso := 1 if hacia_derecha else -1
			while x >= x0 and x < x0 + w:
				if not libre.call(x, y):
					return []
				var v := Vector2i(y, x)
				camino.append(v)
				usada[v] = true
				x += paso
			y += 1
			hacia_derecha = not hacia_derecha
			if y < y0 + h:
				var v2 := Vector2i(y, x - paso)
				if not libre.call(v2.x, v2.y):
					break
				camino.append(v2)
				usada[v2] = true
		return camino

	# ESPIRAL desde una esquina (variantes 1..4).
	var arriba := y0
	var abajo := y0 + h - 1
	var izq := x0
	var der := x0 + w - 1
	# Elgijo de la esquina inicial define por dónde entra la espiral.
	match variante:
		1: pass                      # arriba-izq, sentido horario
		2:                          # arriba-der, antihorario
			izq += 1
		3:                          # abajo-izq, antihorario
			abajo -= 1
		4:                          # abajo-der, horario
			izq += 1
			abajo -= 1
	while arriba <= abajo and izq <= der:
		var x := izq
		while x <= der:
			if not libre.call(x, arriba):
				return []
			var v := Vector2i(arriba, x)
			camino.append(v)
			usada[v] = true
			x += 1
		var y := arriba + 1
		while y <= abajo:
			if not libre.call(der, y):
				return []
			var v2 := Vector2i(y, der)
			camino.append(v2)
			usada[v2] = true
			y += 1
		x = der - 1
		while x >= izq:
			if not libre.call(x, abajo):
				return []
			var v3 := Vector2i(abajo, x)
			camino.append(v3)
			usada[v3] = true
			x -= 1
		y = abajo - 1
		while y >= arriba:
			if not libre.call(izq, y):
				return []
			var v4 := Vector2i(y, izq)
			camino.append(v4)
			usada[v4] = true
			y -= 1
		arriba += 1
		abajo -= 1
		izq += 1
		der -= 1
	return camino

## Camino SERPENTÍN / ESPIRAL con varios dobleces — el patrón real de Amaze GO.
##
## El jugador lo describio así: "empiece en fila 2, avance a la derecha, suba,
## avance a la derecha, baje, vuelva a subir...". No es una recta con un
## doblez: son 2-6 dobleces, y eso cambia la dificultad por una razón concreta:
## CADA SEGMENTO del cuerpo cruza un carril distinto, así que una flecha de 5
## segmentos bloquea muchos más corredores que una recta con un gancho.
## De ahí salen las "cámaras rectangulares anidadas" que se ven en los niveles
## difíciles de Amaze GO (pantallazo del nivel 73).
##
## Modos (elegido al azar):
##  - ESPIRAL: siempre gira en el mismo sentido -> rectangle que se enrolla.
##  - SERPENTÍN: gira alternando sentido -> filas idas y venidas.
static func _camino_espiral(
	tablero: Tablero, inicio: Vector2i, objetivo: int, rng: RandomNumberGenerator,
	giros: int = 3
) -> Array[Vector2i]:
	var camino: Array[Vector2i] = [inicio]
	var usadas := { inicio: true }
	var actual := inicio
	if objetivo < 2:
		return camino

	var dir := _dir_con_mas_recorrido(tablero, inicio, usadas)
	if dir == Vector2i.ZERO:
		dir = DIRS[rng.randi_range(0, DIRS.size() - 1)]

	# ¿Espiral (giro siempre igual) o serpentín (giro alternado)?
	var espiral := rng.randf() < 0.5
	# El primer segmento suele ser el más largo (cuerpo principal).
	var restante := objetivo - 1
	var por_turno := maxi(2, int(restante / maxi(1, giros)))

	for g in giros:
		# Largo del segmento (el primero es más largo).
		var largo := por_turno
		if g == 0:
			largo = maxi(2, int(restante * rng.randf_range(0.45, 0.65)))
		var hechos := 0
		while hechos < largo and camino.size() < objetivo:
			var sig := actual + dir
			if not (tablero.es_jugable(sig) and not tablero.esta_ocupada(sig) and not usadas.has(sig)):
				break
			camino.append(sig)
			usadas[sig] = true
			actual = sig
			hechos += 1
		# Gira 90°: perpendicular al segmento actual.
		var perp := Vector2i(-dir.y, dir.x)
		if espiral:
			# Siempre mismo sentido -> se enrolla.
			pass
		else:
			# Alterna sentido -> serpentín de ida y vuelta.
			if g % 2 == 0:
				perp = -perp
		dir = perp

	return camino

## Camino en "L": cuerpo recto + un gancho de 90 grados en un extremo.
##
## `lado` (0-3) elige en qué esquina está el gancho: arriba, abajo, izquierda o
## derecha. Se usa el índice de la flecha para que el lado VAYA ROTANDO:
## así las flechas se van ANIDANDO unas dentro de otras (como las cámaras
## concéntricas de Amaze GO) en vez de salir todas paralelas.
##
## MEDIDO: con las flechas todas en paralelo (el jugador: "muchas flechas
## apuntando al mismo lado... salía la primera y se desbloqueaban las otras
## una tras otra" = cinta transportadora) el nivel era tedioso. Rotando el
## lado se forma la estructura anidada que sí parece un puzzle.
static func _camino_L(
	tablero: Tablero, inicio: Vector2i, largo: int, lado: int
) -> Array[Vector2i]:
	var camino: Array[Vector2i] = [inicio]
	var usadas := { inicio: true }
	var actual := inicio
	# Dirección del cuerpo: perpendicular al lado del gancho.
	var cuerpo_dir := _dir_cuerpo_para_lado(lado)
	var largo_cuerpo := maxi(1, largo - 2)
	# 1) Cuerpo recto.
	for _i in largo_cuerpo:
		var sig := actual + cuerpo_dir
		if not (tablero.es_jugable(sig) and not tablero.esta_ocupada(sig) and not usadas.has(sig)):
			break
		camino.append(sig)
		usadas[sig] = true
		actual = sig
	# 2) Gancho de 90 grados al final (define la dirección de salida).
	var gancho_dir := _dir_gancho_para_lado(lado)
	for _g in 2:
		var s2 := actual + gancho_dir
		if not (tablero.es_jugable(s2) and not tablero.esta_ocupada(s2) and not usadas.has(s2)):
			break
		camino.append(s2)
		usadas[s2] = true
		actual = s2
	return camino

static func _dir_cuerpo_para_lado(lado: int) -> Vector2i:
	match lado % 4:
		0: return Vector2i(1, 0)    # cuerpo vertical, gancho a la derecha
		1: return Vector2i(0, 1)    # cuerpo horizontal, gancho hacia abajo
		2: return Vector2i(1, 0)    # cuerpo vertical, gancho a la izquierda
		_: return Vector2i(0, 1)    # cuerpo horizontal, gancho hacia arriba

static func _dir_gancho_para_lado(lado: int) -> Vector2i:
	match lado % 4:
		0: return Vector2i(0, 1)
		1: return Vector2i(-1, 0)
		2: return Vector2i(0, -1)
		_: return Vector2i(1, 0)

## Camino "CUERPO LARGO + GANCHO" — el patrón real de Amaze GO.
##
## Calibrado mirando un nivel "Súper Difícil" de Amaze GO (Nivel 68) y
## comparando con nuestros datos:
##   - Amaze GO: la mayoría de flechas son LARGAS (8-25 celdas) con un gancho
##     corto que gira 90º al final. El cuerpo largo cruza muchos corredores y
##     el gancho hace que salga en una dirección inesperada (perpendicular).
##   - Nosotros: 43% de flechas de 2-4 celdas (medido, semilla 12345) = las
##     "flechas que salen fácil" que reportó el jugador, más unas pocas
##     gigantes de 26-51 que se comían el tablero. Distribución BIMODAL.
##
## Este generador produce cuerpo recto largo + giro final de 1-3 celdas.
static func _camino_con_gancho(
	tablero: Tablero, inicio: Vector2i, objetivo: int, rng: RandomNumberGenerator
) -> Array[Vector2i]:
	var camino: Array[Vector2i] = [inicio]
	var usadas := { inicio: true }
	var actual := inicio
	if objetivo < 2:
		return camino

	# Dirección inicial: la que más recorrido libre tenga (flechas largas).
	var dir := _dir_con_mas_recorrido(tablero, inicio, usadas)
	if dir == Vector2i.ZERO:
		dir = DIRS[rng.randi_range(0, DIRS.size() - 1)]

	# El cuerpo recto ocupa la mayor parte de la longitud; el resto es gancho.
	var largo_cuerpo := maxi(2, int(round(float(objetivo) * rng.randf_range(0.7, 0.92))))
	# 1) CUERPO recto.
	while camino.size() < largo_cuerpo:
		var sig := actual + dir
		if not (tablero.es_jugable(sig) and not tablero.esta_ocupada(sig) and not usadas.has(sig)):
			break
		camino.append(sig)
		usadas[sig] = true
		actual = sig
	# 2) GANCHO: gira 90º (perpendicular) 1-3 celdas. Esto hace que la flecha
	#    SALGA en la dirección del gancho, no en la del cuerpo: de ahí el
	#    enredo que se ve en la referencia.
	if camino.size() >= 2 and rng.randf() < 0.85:
		var perp := Vector2i(-dir.y, dir.x)
		if rng.randf() < 0.5:
			perp = -perp
		var gancho := rng.randi_range(1, 3)
		for _g in gancho:
			var s2 := actual + perp
			if not (tablero.es_jugable(s2) and not tablero.esta_ocupada(s2) and not usadas.has(s2)):
				break
			camino.append(s2)
			usadas[s2] = true
			actual = s2
	return camino

## Dirección con más celdas libres por delante (para alargar el cuerpo).
static func _dir_con_mas_recorrido(
	tablero: Tablero, celda: Vector2i, usadas: Dictionary
) -> Vector2i:
	var mejor := Vector2i.ZERO
	var maximo := 0
	for d in DIRS:
		var n := _run_libre(tablero, celda, d, usadas)
		if n > maximo:
			maximo = n
			mejor = d
	return mejor
##
## `tangle` 0.0 = sigue recto siempre (sin giros); 1.0 = gira en cada paso
## (zig-zag máximo). En medio, decide con esa probabilidad en cada paso.
##
## Referencia: gtxPrime/arrow-escape, "Path Tangling Progression" (Tangle Factor
## 0.0..1.0 escalado por nivel).
static func _camino_serpiente(
	tablero: Tablero, inicio: Vector2i, objetivo: int, rng: RandomNumberGenerator,
	tangle: float = 1.0
) -> Array[Vector2i]:
	var camino: Array[Vector2i] = [inicio]
	var usadas := { inicio: true }
	var actual := inicio
	var ult_dir := Vector2i.ZERO
	var dirs: Array[Vector2i] = []
	while camino.size() < objetivo:
		# Decide si este paso puede girar. Con tangle bajo, se preﬁere seguir
		# recto; el tangle es un SESGO, no una restriccion dura.
		var puede_girar := ult_dir == Vector2i.ZERO or rng.randf() < tangle
		if ult_dir == Vector2i.ZERO:
			# Primer paso: con tangle bajo, elegir el eje con mas recorrido libre
			# para que las flechas rectas sean largas y no	de 1 celda.
			dirs = _dirs_iniciales(tablero, inicio, usadas, rng, puede_girar)
		elif puede_girar:
			dirs = DIRS.duplicate()
			_barajar(dirs, rng)
		else:
			dirs = [ult_dir]
		# Evita U-turn 180° (solo tiene sentido al poder girar).
		var avanzo := false
		for d in dirs:
			if d == -ult_dir:
				continue
			var sig: Vector2i = actual + d
			if tablero.es_jugable(sig) and not tablero.esta_ocupada(sig) and not usadas.has(sig):
				camino.append(sig)
				usadas[sig] = true
				actual = sig
				ult_dir = d
				avanzo = true
				break
		# Si la vía "recta" se traba, se permite girar como SALIDA DE EMERGENCIA.
		# Sin este fallback el tangle 0.0 no encuentra caminos y la generación
		# falla (los niveles del tutorial usan tangle 0.0).
		if not avanzo and not puede_girar:
			var todos := DIRS.duplicate()
			_barajar(todos, rng)
			for d in todos:
				if d == -ult_dir:
					continue
				var sig2: Vector2i = actual + d
				if tablero.es_jugable(sig2) and not tablero.esta_ocupada(sig2) and not usadas.has(sig2):
					camino.append(sig2)
					usadas[sig2] = true
					actual = sig2
					ult_dir = d
					avanzo = true
					break
		if not avanzo:
			break
	return camino

## Direcciones candidatas para el PRIMER paso. Con tangle bajo ordena las que
## tienen mas recorrido libre delante (flechas rectas largas).
static func _dirs_iniciales(
	tablero: Tablero, celda: Vector2i, usadas: Dictionary,
	rng: RandomNumberGenerator, puede_girar: bool
) -> Array[Vector2i]:
	var dirs := DIRS.duplicate()
	if not puede_girar:
		# Ordena por recorrido libre descendente.
		dirs.sort_custom(func(a, b): return _run_libre(tablero, celda, a, usadas) > _run_libre(tablero, celda, b, usadas))
	else:
		_barajar(dirs, rng)
	return dirs

## Cuántas celdas libres hay en esa dirección desde `celda` (parando en borde,
## ocupación o celda ya usada).
static func _run_libre(tablero: Tablero, celda: Vector2i, d: Vector2i, usadas: Dictionary) -> int:
	var n := 0
	var act := celda + d
	while tablero.es_jugable(act) and not tablero.esta_ocupada(act) and not usadas.has(act):
		n += 1
		act += d
	return n

## ¿La flecha puede disparar ahora? El corredor de la cabeza debe estar libre
## hasta el borde: sin otras flechas Y sin cruzar su PROPIO cuerpo (auto-bloqueo).
static func _disparable(tablero: Tablero, flecha: Flecha) -> bool:
	var cuerpo := {}
	for c in flecha.celdas:
		cuerpo[c] = true
	var paso := flecha.direccion_salida()
	var actual: Vector2i = flecha.cabeza() + paso
	while tablero.es_jugable(actual):
		if tablero.esta_ocupada(actual) or cuerpo.has(actual):
			return false
		actual += paso
	return true

## ¿La flecha se autobloquea con su PROPIO cuerpo? (No mira otras flechas.)
## Se usa en el generador por cámaras, donde no se exige corredor libre.
static func _sin_autobloqueo(tablero: Tablero, flecha: Flecha) -> bool:
	var cuerpo := {}
	for c in flecha.celdas:
		cuerpo[c] = true
	var paso := flecha.direccion_salida()
	var actual: Vector2i = flecha.cabeza() + paso
	while tablero.es_jugable(actual):
		if cuerpo.has(actual):
			return false
		actual += paso
	return true

static func _corredor_salida(tablero: Tablero, flecha: Flecha) -> Dictionary:
	var res := {}
	var paso := flecha.direccion_salida()
	var actual: Vector2i = flecha.cabeza() + paso
	while tablero.es_jugable(actual):
		res[actual] = true
		actual += paso
	return res

static func _bloquea(camino: Array, corredores: Array) -> bool:
	for celda in camino:
		for corr in corredores:
			if corr.has(celda):
				return true
	return false

## Clasifica dificultad por celdas y flechas (etiqueta visible).
static func dificultad(tablero: Tablero) -> String:
	var celdas := tablero.jugables.size()
	var flechas := tablero.flechas.size()
	var prof := GrafoDependencias.profundidad(tablero)

	# BUG QUE ESTABA (visto jugando): score = celdas + prof*12 + flechas*2.
	# El TAMAÑO dominaba la puntuación, así que un tablero grande pero
	# superficial (900 celdas, 20 flechas, profundidad 5 -> score 1000) salía
	# como "dif_super" siendo facilísimo. Un tablero grande NO es difícil:
	# lo difícil son las CADENAS DE DEPENDENCIAS.
	#
	# Ahora manda la dificultad real: profundidad del grafo + nº de flechas,
	# con pisos obligatorios para que nada se etiquete como "súper difícil"
	# sin serlo de verdad.
	if celdas <= 140:
		return "dif_facil"
	var f := float(flechas)
	if prof >= 13 and f >= 60.0:
		return "dif_super"
	elif prof >= 9 and f >= 40.0:
		return "dif_dificil"
	elif prof >= 6 and f >= 25.0:
		return "dif_medio"
	return "dif_facil"

static func _bbox(forma: Array) -> Vector2i:
	var maxf := 0
	var maxc := 0
	for c in forma:
		maxf = maxi(maxf, c.x)
		maxc = maxi(maxc, c.y)
	return Vector2i(maxf + 1, maxc + 1)

static func _barajar(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

## Estima la dificultad actual del tablero basándose en tamaño y densidad.
## Se usa para decidir si reducir el relleno de huecos.
static func _estimar_dificultad(tablero: Tablero, n_flechas: int) -> String:
	var celdas := tablero.jugables.size()
	var densidad := float(n_flechas) / float(celdas) if celdas > 0 else 0.0
	# Tableros grandes con alta densidad = más difíciles
	if celdas >= 80 and densidad >= 0.25:
		return "dificil"
	elif celdas >= 50 and densidad >= 0.20:
		return "medio"
	return "facil"

## Relleno limitado de huecos (para niveles difíciles).
## En lugar de 4 rondas, hace solo `rondas` rondas.
static func _rellenar_huecos_limitado(tablero: Tablero, celdas_forma: Array[Vector2i],
	rng: RandomNumberGenerator, orden: Array, rondas: int) -> void:
	for _ronda in rondas:
		var progreso := true
		while progreso:
			progreso = false
			for celda in celdas_forma:
				if tablero.esta_ocupada(celda):
					continue
				for _try in 20:
					var longitud := rng.randi_range(2, 4)
					var camino := _camino_serpiente(tablero, celda, longitud, rng)
					if camino.size() < 2:
						continue
					var f := Flecha.new(orden.size(), camino, COLORES_SUAVES[orden.size() % COLORES_SUAVES.size()])
					if _disparable(tablero, f):
						tablero.colocar(f)
						orden.append(f.id)
						progreso = true
						break
	_absorber_sobrantes(tablero)

## Validación de dificultad post-generación.
## Verifica que el nivel cumpla con los mínimos de dificultad.
## Devuelve true si el nivel es válido, false si debe descartarse.
static func _validar_dificultad(tablero: Tablero, profundidad_minima: int) -> bool:
	var prof := GrafoDependencias.profundidad(tablero)
	var flechas := tablero.cantidad_flechas()
	# REGLA DE LA REFERENCIA (growPlayfulEnough): como máximo la MITAD de las
	# flechas pueden dispararse de golpe al abrir el nivel.
	#   return 2*fireable <= total
	# Es la comprobación de dificultad más simple y la que mejor predice lo que
	# siente el jugador: si puede borrar mediatablera de un tirón, es fácil.
	if flechas > 1 and Metricas.libres_iniciales(tablero) * 2 > flechas:
		return false
	if prof < profundidad_minima:
		return false
	if flechas < 8:
		return false
	return true
