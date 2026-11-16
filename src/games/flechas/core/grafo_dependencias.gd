class_name GrafoDependencias
extends RefCounted

## Modela el tablero como un grafo dirigido de dependencias entre flechas.
##
## Arista A -> B  ==  "A bloquea la salida de B" (A debe salir antes que B).
## El nivel es RESOLUBLE si y solo si el grafo es un DAG (sin ciclos), lo que se
## comprueba con un ordenamiento topológico (algoritmo de Kahn): si logramos
## "vaciar" el grafo, no hay ciclo.

## Construye el mapa de bloqueadores: para cada flecha B, el conjunto de flechas
## A que están en su camino de salida.
## Devuelve Dictionary<id_B, Array[id_A]>.
static func bloqueadores(tablero: Tablero) -> Dictionary:
	var mapa: Dictionary = {}
	for id in tablero.flechas.keys():
		mapa[id] = _bloqueadores_de(tablero, id)
	return mapa

## API pública: los bloqueadores de UNA flecha (Array de ids).
## La usa el generador para puntuar candidatos sin simular el grafo completo.
static func bloqueadores_de(tablero: Tablero, id: int) -> Array:
	return _bloqueadores_de(tablero, id)

static func _bloqueadores_de(tablero: Tablero, id: int) -> Array:
	var res: Array = []
	var flecha: Flecha = tablero.flechas[id]
	var paso := flecha.direccion_salida()
	var actual: Vector2i = flecha.cabeza() + paso
	while tablero.es_jugable(actual):
		if tablero.esta_ocupada(actual):
			var otro: int = tablero.ocupacion[actual]
			if otro != id and not res.has(otro):
				res.append(otro)
		actual += paso
	return res

## Intenta un ordenamiento topológico (Kahn) simulando salidas reales sobre una
## copia del tablero. Devuelve el ORDEN de salida si es resoluble, o [] si se
## atasca (ciclo). Esta versión "dinámica" refleja que sacar flechas cambia la
## geometría, no solo el grafo estático.
static func orden_solucion(tablero: Tablero) -> Array:
	var sim := tablero.clonar()
	var orden: Array = []
	var seguridad := sim.cantidad_flechas() + 1
	while not sim.esta_vacio() and seguridad > 0:
		var saco_alguna := false
		# Saca todas las que puedan salir en esta pasada.
		for id in sim.flechas.keys():
			if sim.puede_salir(id):
				sim.quitar(id)
				orden.append(id)
				saco_alguna = true
		if not saco_alguna:
			# Nadie pudo salir -> ciclo/atasco.
			return []
		seguridad -= 1
	if sim.esta_vacio():
		return orden
	return []

## ¿El nivel tiene solución? (equivale a: el grafo dinámico es acíclico)
static func es_resoluble(tablero: Tablero) -> bool:
	return not orden_solucion(tablero).is_empty() or tablero.esta_vacio()

## PROFUNDIDAD de dependencias: cuántas "capas" (pasadas de Kahn) hacen falta
## para vaciar el tablero. En cada capa salen TODAS las flechas que pueden salir
## a la vez. Muchas capas = cadenas largas de "quién sale antes que quién" =
## nivel MÁS DIFÍCIL. Pocas capas (todo sale casi de una) = fácil.
## Devuelve la cantidad de capas (0 si no resoluble).
static func profundidad(tablero: Tablero) -> int:
	var sim := tablero.clonar()
	var capas := 0
	var seguridad := sim.cantidad_flechas() + 1
	while not sim.esta_vacio() and seguridad > 0:
		var salen: Array = []
		for id in sim.flechas.keys():
			if sim.puede_salir(id):
				salen.append(id)
		if salen.is_empty():
			return 0   # atascado (no debería pasar en niveles válidos)
		for id in salen:
			sim.quitar(id)
		capas += 1
		seguridad -= 1
	return capas

## Ratio de bloqueo: fracción de flechas que NO pueden salir en el estado inicial
## (0 = todas libres = fácil; cerca de 1 = casi todo bloqueado = difícil).
static func ratio_bloqueo(tablero: Tablero) -> float:
	var total := tablero.cantidad_flechas()
	if total == 0:
		return 0.0
	var libres := 0
	for id in tablero.flechas.keys():
		if tablero.puede_salir(id):
			libres += 1
	return 1.0 - float(libres) / float(total)
