extends SceneTree

## Genera niveles DIFÍCILES/SÚPER DIFÍCILES buscando la MÁXIMA dificultad real
## (profundidad de dependencias del grafo). Sin límite de tiempo: prueba muchos
## candidatos y semillas y se queda con los más difíciles. Guarda a JSON para
## que el juego los cargue (pre-generación).
##
## Ejecutar: godot --headless --path . --script tools/generar_dificiles.gd

func _init() -> void:
	var objetivo_niveles := 8
	var niveles: Array = []
	var idx := 1
	var semilla := 5000
	print("Generando niveles MUY difíciles (máxima profundidad, pocas jugables)...")
	# Recorre muchísimas semillas (pre-generación, sin prisa) y se queda con los
	# de MAYOR profundidad de dependencias y MENOR fracción jugable inicial.
	while niveles.size() < objetivo_niveles and semilla < 5000 + 4000:
		var mejor: Generador.Nivel = null
		var mejor_score := -1.0
		var mejor_prof := 0
		for intento in 6:
			# BOARDS GRANDES directos (pre-generación sin límite de tiempo).
			var cols := 20 + (intento % 9)   # 20..28 columnas
			var nivel := Generador.generar_grande(cols, semilla + intento * 131)
			if nivel == null:
				continue
			var t: Tablero = nivel.tablero
			var flechas := t.cantidad_flechas()
			if flechas < 35:
				continue   # queremos MUCHAS flechas
			var prof := GrafoDependencias.profundidad(t)
			var ratio := GrafoDependencias.ratio_bloqueo(t)  # fracción bloqueada
			# Dificultad = profundidad ALTA + mucha fracción bloqueada al inicio.
			var score := float(prof) * 3.0 + ratio * 20.0
			if score > mejor_score:
				mejor_score = score
				mejor = nivel
				mejor_prof = prof
		semilla += 30
		# Umbral EXIGENTE: profundidad >= 12 (cadenas larguísimas).
		if mejor == null or mejor_prof < 12:
			continue
		niveles.append(_serializar(idx, mejor))
		var tb: Tablero = mejor.tablero
		print("  Nivel %d: %dx%d flechas=%d PROF=%d bloqueo=%.0f%%" % [
			idx, tb.filas, tb.columnas, tb.flechas.size(), mejor_prof,
			GrafoDependencias.ratio_bloqueo(tb) * 100])
		idx += 1

	var data := { "tipo": "dificiles", "niveles": niveles }
	var f := FileAccess.open("res://src/levels/dificiles.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("== Escrito src/levels/dificiles.json con %d niveles ==" % niveles.size())
	quit(0)

func _serializar(numero: int, nivel: Generador.Nivel) -> Dictionary:
	var t: Tablero = nivel.tablero
	var forma: Array = []
	for c in t.jugables.keys():
		forma.append([c.x, c.y])
	var flechas: Array = []
	for id in t.flechas.keys():
		var fl: Flecha = t.flechas[id]
		var celdas: Array = []
		for c in fl.celdas:
			celdas.append([c.x, c.y])
		flechas.append({ "id": fl.id, "celdas": celdas })
	return {
		"numero": numero,
		"filas": t.filas,
		"columnas": t.columnas,
		"forma": forma,
		"flechas": flechas,
		"solucion": nivel.solucion,
	}
