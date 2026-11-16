class_name Figuras
extends RefCounted

## Figuras (lienzos) como conjuntos de celdas jugables sobre una matriz de puntos.
## Para el Mundo 1: formas simples. Todas devuelven Array[Vector2i] (fila, col)
## y procuran tener un número PAR de celdas y sin celdas aisladas, para que se
## puedan rellenar 100% con flechas de longitud >= 2.

## Rectángulo lleno filas x columnas.
static func rectangulo(filas: int, columnas: int) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for f in filas:
		for c in columnas:
			res.append(Vector2i(f, c))
	return res

## Rombo/diamante (aprox) inscrito en un cuadrado de lado impar.
## radio = distancia Manhattan desde el centro.
static func rombo(radio: int) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	var lado := radio * 2 + 1
	var centro := Vector2i(radio, radio)
	for f in lado:
		for c in lado:
			if absi(f - centro.x) + absi(c - centro.y) <= radio:
				res.append(Vector2i(f, c))
	return _asegurar_par(res)

## Óvalo (elipse) aproximado dentro de un bounding box filas x columnas.
static func ovalo(filas: int, columnas: int) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	var rf := filas / 2.0
	var rc := columnas / 2.0
	var cf := (filas - 1) / 2.0
	var cc := (columnas - 1) / 2.0
	for f in filas:
		for c in columnas:
			var nf := (f - cf) / rf
			var nc := (c - cc) / rc
			if nf * nf + nc * nc <= 1.05:
				res.append(Vector2i(f, c))
	return _asegurar_par(res)

## Cruz / plus.
static func cruz(brazo: int) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	var lado := brazo * 2 + 1
	var centro := brazo
	for f in lado:
		for c in lado:
			if f == centro or c == centro:
				res.append(Vector2i(f, c))
	return _asegurar_par(res)

## Forma en L: un rectángulo filas x columnas al que se le quita una esquina
## rectangular de tamaño (filas-hueco) ... simplificado: rectángulo lleno menos
## un bloque superior-derecho de `recorte` x `recorte`.
static func ele(filas: int, columnas: int, recorte: int) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for f in filas:
		for c in columnas:
			# Quita el bloque superior-derecho.
			if f < recorte and c >= columnas - recorte:
				continue
			res.append(Vector2i(f, c))
	return _asegurar_par(res)

## Marco (anillo rectangular): borde de filas x columnas, hueco interior.
static func marco(filas: int, columnas: int) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for f in filas:
		for c in columnas:
			if f == 0 or f == filas - 1 or c == 0 or c == columnas - 1:
				res.append(Vector2i(f, c))
	return _asegurar_par(res)

## Forma T: barra horizontal superior (2 filas de ancho completo) + tronco central.
static func te(filas: int, columnas: int) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	# Barra superior: 2 filas completas (garantiza teselado par por filas).
	for f in 2:
		for c in columnas:
			res.append(Vector2i(f, c))
	# Tronco: columnas centrales, filas restantes (en pares).
	var col_ini := (columnas - 2) / 2
	for f in range(2, filas):
		for c in range(col_ini, col_ini + 2):
			res.append(Vector2i(f, c))
	return _asegurar_par(res)

## Corazón GRANDE y reconocible. Patrón explícito diseñado para ser teselable
## (bordes en bloques de ancho par donde importa, sin celdas de una sola conexión).
static func corazon() -> Array[Vector2i]:
	var patron := [
		" ####   #### ",
		"##############",
		"##############",
		"##############",
		"##############",
		" ############ ",
		"  ##########  ",
		"   ########   ",
		"    ######    ",
		"     ####     ",
		"      ##      ",
	]
	return _desde_patron(patron)

## Convierte un patrón de texto (Array de String, '#' activa) en celdas.
static func _desde_patron(patron: Array) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for f in patron.size():
		var fila: String = patron[f]
		for c in fila.length():
			if fila[c] == "#":
				res.append(Vector2i(f, c))
	return _asegurar_par(res)

## Si el conjunto tiene un número IMPAR de celdas, quita una celda "de punta"
## (con solo un vecino ortogonal) para dejarlo par y teselable con longitud >=2.
static func _asegurar_par(celdas: Array[Vector2i]) -> Array[Vector2i]:
	if celdas.size() % 2 == 0:
		return celdas
	var set := {}
	for c in celdas:
		set[c] = true
	# Busca una celda con el menor número de vecinos para eliminarla.
	var mejor := celdas[celdas.size() - 1]
	var min_vecinos := 5
	for c in celdas:
		var v := 0
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if set.has(c + d):
				v += 1
		if v < min_vecinos:
			min_vecinos = v
			mejor = c
	celdas.erase(mejor)
	return celdas



## Figura DINÁMICA: parte de un rectángulo y recorta bloques de esquinas al azar,
## creando siluetas variadas y orgánicas (no una lista fija). Se queda con el
## mayor componente conexo y asegura área par.
static func figura_dinamica(filas: int, columnas: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var set := {}
	for f in filas:
		for c in columnas:
			set[Vector2i(f, c)] = true
	var recortes := rng.randi_range(0, 4)
	for _r in recortes:
		var rf := rng.randi_range(1, maxi(1, filas / 2))
		var rc := rng.randi_range(1, maxi(1, columnas / 2))
		var esquina := rng.randi_range(0, 3)
		for f in rf:
			for c in rc:
				var celda: Vector2i
				match esquina:
					0: celda = Vector2i(f, c)
					1: celda = Vector2i(f, columnas - 1 - c)
					2: celda = Vector2i(filas - 1 - f, c)
					3: celda = Vector2i(filas - 1 - f, columnas - 1 - c)
				set.erase(celda)
	var celdas: Array[Vector2i] = []
	for k in set.keys():
		celdas.append(k)
	celdas = _mayor_componente(celdas)
	return _asegurar_par(celdas)

static func _mayor_componente(celdas: Array[Vector2i]) -> Array[Vector2i]:
	var set := {}
	for c in celdas:
		set[c] = true
	var visitado := {}
	var mejor: Array[Vector2i] = []
	for inicio in celdas:
		if visitado.has(inicio):
			continue
		var comp: Array[Vector2i] = []
		var cola: Array[Vector2i] = [inicio]
		visitado[inicio] = true
		while not cola.is_empty():
			var cur: Vector2i = cola.pop_back()
			comp.append(cur)
			for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var v: Vector2i = cur + d
				if set.has(v) and not visitado.has(v):
					visitado[v] = true
					cola.append(v)
		if comp.size() > mejor.size():
			mejor = comp
	return mejor
