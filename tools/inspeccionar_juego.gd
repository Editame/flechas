extends SceneTree

## Reproduce un nivel tal como lo generó el JUEGO (misma ruta de código que
## el botón "Otro nivel": Generador._generar_en_vivo(semilla, 3, 4)) y vuelca
## todas sus métricas.
##
## Uso: -- <semilla>
##
## Para qué: el juego muestra la semilla en pantalla. Con esa cifra se
## reproduce el nivel EXACTO que el jugador vio y se mide por qué fue fácil
## o difícil, en vez de estimarlo.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Uso: -- <semilla>")
		quit(1)
		return
	var semilla := int(args[0])
	print("=== Nivel del JUEGO con semilla %d ===" % semilla)
	print("Reproduciendo con la misma ruta que el juego...")
	var nivel := Generador._generar_en_vivo(semilla, 3, 4)
	if nivel == null:
		print("No se pudo generar con esa semilla.")
		quit(1)
		return
	var t: Tablero = nivel.tablero
	var p := Metricas.perfil(t)
	var nf := int(p["flechas"])
	var cadena := int(p["cadena"])
	var libres := int(p["libres_iniciales"])

	print("")
	print("--- Identidad ---")
	print("tablero: %d x %d   celdas jugables: %d" % [t.filas, t.columnas, t.jugables.size()])
	print("etiqueta: %s" % Generador.dificultad(t))
	print("")

	print("--- Dificultad ---")
	print("flechas:               %d" % nf)
	print("CADENA mas larga:      %d   <- jugadas a planificar" % cadena)
	print("profundidad (Kahn):    %d" % int(p["profundidad"]))
	print("libres al inicio:      %d  (%d%%)" % [libres, int(round(100.0 * libres / maxf(1.0, float(nf))))])
	print("ratio bloqueo:         %d%%" % int(round(float(p["ratio_bloqueo"]) * 100.0)))
	print("componentes (islas):   %d" % int(p["componentes"]))
	print("espacio libre:         %d%%" % int(round(float(p["espacio_libre"]) * 100.0)))
	print("")

	print("--- Contraste con Amaze GO ---")
	print("Amaze GO 'Super Dificil' (niv 68): ~60-70 flechas, una sola masa.")
	print("Este nivel:                          %d flechas, %d isla(s)." % [nf, int(p["componentes"])])
	if nf > 100:
		print("=> DEMASIADAS flechas: se vuelve tedioso, no dificil.")
		print("   El jugador tarda por CANTIDAD, no por pensar.")
	print("")

	print("--- Verificacion ---")
	print("resoluble:             %s" % ("si" if GrafoDependencias.es_resoluble(t) else "NO"))
	print("jugadas optimas:       %d" % Metricas.jugadas_optimas(t))
	print("solucion guardada ok:  %s" % ("si" if Metricas.verificar_solucion(t, nivel.solucion) else "NO"))
	print("")

	print("--- Distribucion de longitudes ---")
	var por_len := {}
	for id in t.flechas.keys():
		var l: int = (t.flechas[id] as Flecha).longitud()
		por_len[l] = int(por_len.get(l, 0)) + 1
	var lens := por_len.keys()
	lens.sort()
	for l in lens:
		var barra := ""
		for _i in int(por_len[l] / 2):
			barra += "#"
		print("  len %2d : %3d  %s" % [l, por_len[l], barra])

	# Mapa: '#' cuerpo, '>' '<' '^' 'v' cabeza con su dirección, '.' celda
	# jugable vacía. Sirve para VER si las flechas forman espirales/serpentines.
	print("")
	print("--- Mapa (primeras 34 filas) ---")
	for f in mini(34, t.filas):
		var linea := ""
		for c in t.columnas:
			var celda := Vector2i(f, c)
			if not t.es_jugable(celda):
				linea += " "
				continue
			if not t.esta_ocupada(celda):
				linea += "."
				continue
			var fl: Flecha = t.flechas[t.ocupacion[celda]]
			if celda == fl.cabeza():
				match fl.direccion_salida():
					Vector2i(-1, 0): linea += "^"
					Vector2i(1, 0): linea += "v"
					Vector2i(0, -1): linea += "<"
					_: linea += ">"
			else:
				linea += "#"
		print(linea)
	quit(0)