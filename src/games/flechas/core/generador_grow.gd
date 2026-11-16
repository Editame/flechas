class_name GeneradorGrow
extends RefCounted

## GENERADOR ALTERNATIVO "grow" — en clase APARTE, sin tocar Generador.
##
## Si este enfoque no convence, se borra este archivo y se sigue con
## src/core/generador.gd como estaba.
##
## REFERENCIA: clon del juego comercial del genero (sergev/goarrows, que replica
## "Arrows - Puzzle Escape" de Lessmore GmbH, el lider del genero con 421 mil
## resenas). NO es Amaze GO: de ese no hay fuente publica. Es la referencia
## publica mas parecida que existe.
##
## DIFERENCIA CLAVE con nuestro Generador (parece equivalente, pero no):
##   - Generador: elige una LONGITUD OBJETIVO y si no cabe, acorta la flecha.
##   - Grow:      la flecha CRECE HASTA QUE SE ATASCA. No hay objetivo.
##     Por eso las flechas de grow son mucho mas largas y se enredan solas.
##
## REGLAS (traducidas del original):
##  1. Siembra n cabezas, cada una con 1 celda de cuerpo, en orientacion al azar.
##     Ninguna cabeza puede tener su rayo de disparo cortando otra cabeza.
##  2. Extender la COLA de las flechas, en orden aleatorio, hasta que ninguna
##     pueda crecer.
##  3. Al extender, se descarta toda celda que este en el RAYO DE DISPARO de la
##     PROPIA flecha (una flecha no puede cruzarse a si misma).
##  4. Si hay opcion de seguir recto o girar, 90% recto. Pero si el recto esta
##     atascado, gira: por eso salen espirales en las zonas densas.
##  5. Se rechaza el tablero si mas de la mitad de las flechas se pueden
##     disparar de golpe, o si no es resoluble.

const RAYO_POR_10 := 9          # 90% recto cuando ambas opciones son legales

class Resultado:
	var tablero: Tablero = null
	var intentos: int = 0
	var rechazos_facil: int = 0
	var rechazos_resoluble: int = 0
	func ok() -> bool:
		return tablero != null

## Genera un tablero w x h con el algoritmo grow.
static func generar(w: int, h: int, rng: RandomNumberGenerator,
		max_intentos: int = 4000) -> Resultado:
	var res := Resultado.new()
	var n := mini(w, h)
	var n_cabezas := clampi(_f_objetivo(n), 1, maxi(1, (w * h) / 2))
	for intento in max_intentos:
		res.intentos = intento + 1
		var t := _intentar(w, h, n_cabezas, rng)
		if t == null:
			continue
		# REGLA 5a: no mas de la mitad disparables de golpe.
		if not _jugable(t):
			res.rechazos_facil += 1
			continue
		# REGLA 5b: resoluble (nuestro solver es completo: el juego es monótono).
		if not GrafoDependencias.es_resoluble(t):
			res.rechazos_resoluble += 1
			continue
		res.tablero = t
		return res
	return res

## Cuantas flechas: formula de la referencia (n^2/10 para n>=10).
static func _f_objetivo(n: int) -> int:
	if n < 6:
		return n
	if n < 10:
		return n * n / 6
	return n * n / 10

## Un intento: siembra + crecimiento.
static func _intentar(w: int, h: int, n_cabezas: int,
		rng: RandomNumberGenerator) -> Tablero:
	var ocupa := {}
	var es_cabeza := {}
	var caminos: Array = []

	# --- REGLA 1: siembra ---
	for k in n_cabezas:
		var colocado := false
		for _a in 400:
			var hv := Vector2i(rng.randi_range(0, h - 1), rng.randi_range(0, w - 1))
			if ocupa.has(hv):
				continue
			var dir := Direccion.vector(rng.randi_range(0, 3))
			if _rayo_corta_cabeza(hv, dir, es_cabeza, w, h):
				continue
			var cuerpo: Vector2i = hv - dir
			if not _dentro(cuerpo, w, h) or ocupa.has(cuerpo):
				continue
			ocupa[hv] = true
			ocupa[cuerpo] = true
			es_cabeza[hv] = true
			# Nuestro convention: celdas va de COLA a CABEZA.
			var camino: Array[Vector2i] = [cuerpo, hv]
			caminos.append(camino)
			colocado = true
			break
		if not colocado:
			return null

	# --- Rayo de disparo de cada flecha (fijo: la cabeza no se mueve) ---
	var rayos: Array = []
	for c in caminos:
		var camino: Array[Vector2i] = c
		var cabeza: Vector2i = camino[camino.size() - 1]
		var previo: Vector2i = camino[camino.size() - 2]
		rayos.append(_rayo(cabeza, cabeza - previo, w, h))

	# --- REGLA 2/3/4: crecer las colas ---
	for _ronda in 100000:
		var extendio := false
		for i in _barajar_indices(caminos.size(), rng):
			var camino: Array[Vector2i] = caminos[i]
			if camino.size() < 2:
				continue
			var cola: Vector2i = camino[0]
			var previo: Vector2i = camino[1]
			var cands: Array[Vector2i] = []
			for d in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
				var nx: Vector2i = cola + d
				if nx == previo:
					continue
				if not _dentro(nx, w, h) or ocupa.has(nx):
					continue
				# REGLA 3: no cruzar el propio rayo de disparo.
				if (rayos[i] as Dictionary).has(nx):
					continue
				cands.append(nx)
			if cands.is_empty():
				continue
			var chosen := _elegir_paso(previo, cola, cands, rng)
			camino.insert(0, chosen)
			ocupa[chosen] = true
			extendio = true
		if not extendio:
			break

	# Construye el tablero final con las formas definitivas.
	var t := Tablero.new(w, h)
	for f in h:
		for c in w:
			t.agregar_celda(Vector2i(f, c))
	for i in caminos.size():
		t.colocar(Flecha.new(i, caminos[i], Color.WHITE))
	return t

static func _dentro(p: Vector2i, w: int, h: int) -> bool:
	return p.x >= 0 and p.x < w and p.y >= 0 and p.y < h

static func _rayo(cabeza: Vector2i, d: Vector2i, w: int, h: int) -> Dictionary:
	var res := {}
	var act := cabeza + d
	while _dentro(act, w, h):
		res[act] = true
		act += d
	return res

static func _rayo_corta_cabeza(cabeza: Vector2i, d: Vector2i,
		es_cabeza: Dictionary, w: int, h: int) -> bool:
	var act := cabeza + d
	while _dentro(act, w, h):
		if es_cabeza.has(act):
			return true
		act += d
	return false

## REGLA 4: 90% recto si ambas opciones son legales.
static func _elegir_paso(previo: Vector2i, cola: Vector2i,
		cands: Array[Vector2i], rng: RandomNumberGenerator) -> Vector2i:
	if cands.size() == 1:
		return cands[0]
	var recto := cola - previo
	var rectas: Array[Vector2i] = []
	var giros: Array[Vector2i] = []
	for c in cands:
		if (c - cola) == recto:
			rectas.append(c)
		else:
			giros.append(c)
	if giros.size() > 0 and rectas.size() > 0:
		if rng.randi_range(0, 9) < RAYO_POR_10:
			return rectas[rng.randi_range(0, rectas.size() - 1)]
		return giros[rng.randi_range(0, giros.size() - 1)]
	return cands[rng.randi_range(0, cands.size() - 1)]

## REGLA 5a: como maximo la mitad de las flechas se pueden disparar de golpe.
static func _jugable(t: Tablero) -> bool:
	var total := t.cantidad_flechas()
	if total <= 1:
		return true
	var libres := 0
	for id in t.flechas.keys():
		if t.puede_salir(id):
			libres += 1
	return 2 * libres <= total

static func _barajar_indices(n: int, rng: RandomNumberGenerator) -> Array:
	var res: Array = []
	for i in n:
		res.append(i)
	for i in range(res.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = res[i]
		res[i] = res[j]
		res[j] = tmp
	return res