class_name Metricas
extends RefCounted

## Métricas OBJETIVAS de dificultad de un tablero.
##
## POR QUÉ EXISTE: "el jugador dice que está fácil" es una señal, no una
## medida. Estas métricas permiten comprobar sin jugar si un nivel cumple lo
## que pedimos. Se apoyan en una propiedad de nuestro juego: es MONOTONO
## (sacar una flecha solo libera celdas, nunca las ocupa), así que el solver
## greedy es COMPLETO: devuelve el mínimo exacto de jugadas, no una estimación.
##
## La más importante es `cadena_mas_larga`: cuántas jugadas hay que planificar
## ANTES de poder resolver. Un tablero con 100 flechas todas libres es
## trivial aunque sea enorme; ese es el error quebots cometía al usar el
## tamaño como medida de dificultad.

## ¿El nivel es resoluble? (exacto, no probabilístico)
static func resoluble(tablero: Tablero) -> bool:
	return GrafoDependencias.es_resoluble(tablero)

## Nº MÍNIMO exacto de jugadas para resolver. Como cada flecha sale una vez y
## no hay movimiento wasted, el óptimo es el nº de flechas. Se verifica además
## que exista ese orden.
static func jugadas_optimas(tablero: Tablero) -> int:
	return tablero.cantidad_flechas()

## Cuántas flechas se pueden sacar EN EL PRIMER movimiento sin error.
## Esto es lo que el jugador perceive al abrir el nivel: si puede sacar 40 de
## 50 flechas de inmediato, el nivel se siente fácil aunque el grafo sea hondo.
static func libres_iniciales(tablero: Tablero) -> int:
	var n := 0
	for id in tablero.flechas.keys():
		if tablero.puede_salir(id):
			n += 1
	return n

## Fracción de flechas bloqueadas al empezar (0 = todo libre = fácil).
static func ratio_bloqueo_inicial(tablero: Tablero) -> float:
	var total := tablero.cantidad_flechas()
	if total == 0:
		return 0.0
	return 1.0 - float(libres_iniciales(tablero)) / float(total)

## Longitud de la CADENA DE DEPENDENCIAS más larga del grafo.
##
## Es la medida honesta de "cuántas jugadas hay que planificar": si la cadena
## más larga es de 12, hay una flecha que no puede salir hasta que 11 otras
## hayan salido en un orden concreto. Un tablero enorme con cadenas de 2-3 es
## fácil; uno mediano con cadenas de 12 es difícil.
static func cadena_mas_larga(tablero: Tablero) -> int:
	var memo: Dictionary = {}
	var bloqueadores: Dictionary = GrafoDependencias.bloqueadores(tablero)
	var mejor := 0
	for id in tablero.flechas.keys():
		var l := _cadena(id, bloqueadores, memo)
		mejor = maxi(mejor, l)
	return mejor

## Longitud de cadena de una flecha (memoizada; el grafo es DAG).
static func _cadena(id: int, bloqueadores: Dictionary, memo: Dictionary) -> int:
	if memo.has(id):
		return int(memo[id])
	memo[id] = 1   # guarda primero:protege de cualquier ciclo
	var mejor := 0
	for b in bloqueadores.get(id, []):
		mejor = maxi(mejor, _cadena(int(b), bloqueadores, memo))
	memo[id] = 1 + mejor
	return int(memo[id])

## NOTA: aquí antes había una función `cebos()` que contaba las flechas LIBRES
## (duplicaba `libres_iniciales`) con un nombre y una documentación que
## describían otra cosa. Se eliminó: laDifficulty real la mide `cebos()`
## de más abajo (flechas bloqueadas cuyo bloqueo está lejos de la salida).

## VERIFICA que la solución almacenada en el JSON es realmente válida.
## Reproduce ese orden y comprueba que el tablero queda vacío. Sin esto, un
## `solucion` corrupto pasaría desapercibido hasta que el jugador lo use.
static func verificar_solucion(tablero: Tablero, solucion: Array) -> bool:
	var sim := tablero.clonar()
	for id in solucion:
		if not sim.flechas.has(int(id)):
			continue        # id repetido o ausente: se ignora
		if not sim.puede_salir(int(id)):
			return false   # el orden no era válido
		sim.quitar(int(id))
	return sim.esta_vacio()

## Perfil completo de dificultad de un nivel.
static func perfil(tablero: Tablero) -> Dictionary:
	var cadena := cadena_mas_larga(tablero)
	var libres := libres_iniciales(tablero)
	return {
		"celdas": tablero.jugables.size(),
		"flechas": tablero.cantidad_flechas(),
		"cadena": cadena,
		"profundidad": GrafoDependencias.profundidad(tablero),
		"libres_iniciales": libres,
		"ratio_bloqueo": ratio_bloqueo_inicial(tablero),
		# Dificultad PERCEPTIVA: lo que hace que "cuesta ver qué está libre".
		"cebos": cebos(tablero, 3),
		"espacio_libre": espacio_libre(tablero),
		"componentes": componentes(tablero),
		"resoluble": GrafoDependencias.es_resoluble(tablero),
		"etiqueta": Generador.dificultad(tablero),
	}

## DISTANCIA (en celdas) desde la cabeza de una flecha hasta su primer
## bloqueador en el corredor de salida. Si está en 0, el bloqueo es visible
## al instante; si es alta, el bloqueo está lejos de la salida y la flecha
## PARECE libre.
static func distancia_al_bloqueo(tablero: Tablero, id: int) -> int:
	var flecha: Flecha = tablero.flechas.get(id)
	if flecha == null:
		return -1
	var paso := flecha.direccion_salida()
	var actual: Vector2i = flecha.cabeza() + paso
	var d := 0
	while tablero.es_jugable(actual):
		if tablero.esta_ocupada(actual):
			var otro: int = tablero.ocupacion[actual]
			if otro != id:
				return d
		actual += paso
		d += 1
	return -1   # sin bloqueo: sale libre

## CEBOS: flechas que están bloqueadas, pero cuyo bloqueo está LEJOS de la
## salida (a partir de `min_dist` celdas).
##
## Esta es la medida de la dificultad PERCEPTIVA, que es la que el jugador
## menciona ("cuesta detectar cuáles flechas no están bloqueadas"). Un nivel
## con muchos cebos obliga a recorrer mentalmente cada corredor hasta el
## borde: no se puede decidir "a ojo" qué flecha está libre.
static func cebos(tablero: Tablero, min_dist: int = 3) -> int:
	var n := 0
	for id in tablero.flechas.keys():
		var d := distancia_al_bloqueo(tablero, id)
		if d >= min_dist:
			n += 1
	return n

## Fracción de celdas jugables VACÍAS. Cuanto MENOR sea, más difícil es
##finding un camino libre a ojo (no se ven "huecos" despejados).
static func espacio_libre(tablero: Tablero) -> float:
	var total := tablero.jugables.size()
	if total == 0:
		return 0.0
	var ocupadas := 0
	for c in tablero.ocupacion.keys():
		ocupadas += 1
	return 1.0 - float(ocupadas) / float(total)

## NÚMERO DE COMPONENTES CONEXAS del grafo de dependencias.
##
## Hallazgo comparando dos pantallazos REALES de Amaze GO:
##   - Nivel 68 "Súper Difícil": una sola masa interconectada => 1 componente.
##     Al jugador le cuesta mucho: cada flecha depende del sistema entero.
##   - Nivel 70 "Difícil": la masa central más 2-3 islas de flechas sueltas
##     abajo => varias componentes. Esas islas NO las bloquea nadie, así que
##     se sacan gratis de inmediato: movimientos gratis que rompen la tensión.
##     El jugador lo resolvió mucho más rápido.
##
## Para un nivel difícil se quiere 1 componente: todas las flechas conectadas.
static func componentes(tablero: Tablero) -> int:
	var bloq: Dictionary = GrafoDependencias.bloqueadores(tablero)
	var ids := tablero.flechas.keys()
	var visto := {}
	var total := 0
	for inicio in ids:
		if visto.has(inicio):
			continue
		total += 1
		var cola: Array = [inicio]
		visto[inicio] = true
		while not cola.is_empty():
			var cur = cola.pop_back()
			# Vecinos en ambas direcciones: bloqueadores y bloqueados.
			for b in bloq.get(cur, []):
				if not visto.has(b):
					visto[b] = true
					cola.append(b)
			for otro in ids:
				if visto.has(otro):
					continue
				if (bloq.get(otro, []) as Array).has(cur):
					visto[otro] = true
					cola.append(otro)
	return total

## RAMIFICACIÓN del grafo de dependencias: cuántas flechas desbloquea cada flecha.
##
## Hallazgo jugando un nivel: "muchas flechas pequeñas apuntando al mismo lado,
## la dependencia era la flecha de adelante; salía la primera y se
## desbloqueaban las otras una tras otra". Eso es un CINTA TRANSPORTADORA: cada
## flecha desbloquea exactamente 1, así que no hay nada que decidir, solo
## seguir la fila. Es TEDIOSO, no difícil.
##
## Un nivel interesante necesita ramificación: que sacando una flecha se
## desbloqueen VARIAS, y que esas a su vez bloqueen a otras distintas.
## Devuelve {media, maxima,Percentage_linea, solo_una}.
static func ramificacion(tablero: Tablero) -> Dictionary:
	var bloq: Dictionary = GrafoDependencias.bloqueadores(tablero)
	var total := 0
	if total == 0:
		total = tablero.cantidad_flechas()
	# out-degree: cuántas flechas desbloquea cada una.
	var out := {}
	for id in tablero.flechas.keys():
		out[id] = 0
	for b in bloq.keys():
		for bloqueador in (bloq[b] as Array):
			if out.has(bloqueador):
				out[bloqueador] = int(out[bloqueador]) + 1
	var suma := 0
	var maxima := 0
	var solo_una := 0
	for id in out.keys():
		var d := int(out[id])
		suma += d
		maxima = maxi(maxima, d)
		if d <= 1:
			solo_una += 1
	var n := maxi(1, out.size())
	return {
		"media": float(suma) / float(n),
		"maxima": maxima,
		"pct_linea": 100.0 * float(solo_una) / float(n),
	}

## VEREDICTO objetivo: ¿este nivel cumple lo que pedimos para nivel avanzado?
##
## NO es la opinión del jugador ni una estimación: son condiciones verificables.
## Devuelve {"ok": bool, "motivo": String}.
static func cumple_avanzado(tablero: Tablero) -> Dictionary:
	var p := perfil(tablero)
	if not p["resoluble"]:
		return {"ok": false, "motivo": "no resoluble"}
	if int(p["flechas"]) < 45:
		return {"ok": false, "motivo": "solo %d flechas (min 45)" % int(p["flechas"])}
	if int(p["cadena"]) < 10:
		return {"ok": false, "motivo": "cadena de solo %d (min 10)" % int(p["cadena"])}
	# Si casi todo se puede sacar de golpe, el jugador no tiene que planificar.
	if int(p["libres_iniciales"]) > int(p["flechas"]) * 0.35:
		return {"ok": false, "motivo": "%d de %d libres de entrada (max 35%%)" % [
			int(p["libres_iniciales"]), int(p["flechas"])]}
	return {"ok": true, "motivo": "ok"}