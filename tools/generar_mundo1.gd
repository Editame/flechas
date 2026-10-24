extends SceneTree

## Genera y CONGELA los 10 niveles del Mundo 1 (fácil) como datos JSON.
## Cada nivel es una FIGURA rellena 100% con flechas (longitud >= 2), resoluble.
## Ejecutar headless:
##   godot --headless --path . --script tools/generar_mundo1.gd

func _init() -> void:
	# Config por nivel: figura + bounding box + long_max + semilla.
	# IMPORTANTE: para el MVP usamos figuras GARANTIZADAS teselables con flechas
	# de longitud >= 2 (rectángulos de área par y formas compuestas por rectángulos).
	# Formas con puntas estrechas (rombo/óvalo) NO siempre teselan, se dejan para
	# después con un catálogo de figuras validadas.
	# Figuras más grandes para que cada nivel tenga suficientes flechas (min ~8).
	# Rampa: crece el tamaño y la complejidad. Incluye corazón.
	var configs := [
		{"fig": Figuras.rectangulo(8, 8),   "lmax": 6, "sem": 301},
		{"fig": Figuras.rectangulo(9, 9),   "lmax": 6, "sem": 302},
		{"fig": Figuras.ele(10, 9, 4),      "lmax": 6, "sem": 303},
		{"fig": Figuras.rectangulo(10, 10), "lmax": 6, "sem": 304},
		{"fig": Figuras.marco(10, 10),      "lmax": 6, "sem": 305},
		{"fig": Figuras.corazon(),          "lmax": 6, "sem": 306},
		{"fig": Figuras.te(10, 10),         "lmax": 6, "sem": 307},
		{"fig": Figuras.rectangulo(11, 10), "lmax": 6, "sem": 308},
		{"fig": Figuras.ele(11, 11, 5),     "lmax": 6, "sem": 309},
		{"fig": Figuras.rectangulo(12, 11), "lmax": 7, "sem": 310},
	]
	var min_flechas := 12

	var niveles: Array = []
	var idx := 1
	for cfg in configs:
		var forma: Array = cfg["fig"]
		# Bounding box REAL de la figura (evita desajustes de tamaño).
		var bb := _bounding_box(forma)
		var filas: int = bb.x
		var cols: int = bb.y
		# Busca una semilla que dé relleno 100% Y al menos `min_flechas`.
		var nivel: Generador.Nivel = null
		for extra in 200:
			var cand: Generador.Nivel = Generador.generar_relleno(
				forma, filas, cols, cfg["lmax"], cfg["sem"] + extra * 13, 40)
			if cand != null and cand.tablero.cantidad_flechas() >= min_flechas:
				nivel = cand
				break
		if nivel == null:
			# Relaja: acepta el mejor relleno aunque tenga menos flechas.
			nivel = Generador.generar_relleno(forma, filas, cols, cfg["lmax"], cfg["sem"], 120)
		if nivel == null:
			printerr("No se pudo generar (relleno) el nivel ", idx, " (celdas=", forma.size(), ")")
			quit(1)
			return
		# Verificación dura: 100% cubierto.
		var libres := _contar_libres(nivel.tablero)
		if libres != 0:
			printerr("Nivel ", idx, " dejó ", libres, " celdas libres")
			quit(1)
			return
		niveles.append(_serializar(idx, nivel, forma))
		print("Nivel %d: figura %d celdas, %d flechas, solucion=%d, semilla=%d" % [
			idx, forma.size(), nivel.tablero.cantidad_flechas(),
			nivel.solucion.size(), nivel.semilla])
		idx += 1

	var data := { "mundo": 1, "dificultad": "facil", "niveles": niveles }
	var f := FileAccess.open("res://src/levels/mundo1.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("== Escrito src/levels/mundo1.json con %d niveles ==" % niveles.size())
	quit(0)

func _bounding_box(forma: Array) -> Vector2i:
	var maxf := 0
	var maxc := 0
	for c in forma:
		maxf = maxi(maxf, c.x)
		maxc = maxi(maxc, c.y)
	return Vector2i(maxf + 1, maxc + 1)

func _contar_libres(t: Tablero) -> int:
	var n := 0
	for celda in t.jugables.keys():
		if not t.esta_ocupada(celda):
			n += 1
	return n

func _serializar(numero: int, nivel: Generador.Nivel, forma: Array) -> Dictionary:
	var t: Tablero = nivel.tablero
	var flechas_data: Array = []
	for id in t.flechas.keys():
		var flecha: Flecha = t.flechas[id]
		var celdas_arr: Array = []
		for c in flecha.celdas:
			celdas_arr.append([c.x, c.y])
		flechas_data.append({
			"id": flecha.id,
			"celdas": celdas_arr,
		})
	var forma_arr: Array = []
	for c in forma:
		forma_arr.append([c.x, c.y])
	return {
		"numero": numero,
		"filas": t.filas,
		"columnas": t.columnas,
		"forma": forma_arr,          # celdas jugables de la figura (para el render)
		"flechas": flechas_data,
		"solucion": nivel.solucion,
		"semilla": nivel.semilla,
	}
