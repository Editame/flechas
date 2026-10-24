extends SceneTree

## INSPECCIONA UN NIVEL POR SU SEMILLA.
##
## Uso:  godot --headless --path . --script tools/inspeccionar_semilla.gd -- <semilla> [cols]
##
## Para qué: el juego muestra la semilla en pantalla (tecla D en PC). Con esa
## cifra se reproduce el nivel EXACTO y se vuelcan todas sus métricas, para
## saber por qué un nivel es difícil o fácil en vez de estimarlo.
##
## Ejemplo: -- 17824305 30

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Uso: -- <semilla> [cols]")
		quit(1)
		return
	var semilla := int(args[0])
	var cols := 30
	if args.size() > 1:
		cols = int(args[1])

	print("=== Inspección del nivel con semilla %d (cols %d) ===" % [semilla, cols])
	print("Reproduciendo... (puede tardar)")
	var nivel := Generador.generar_grande(cols, semilla, 1.0)
	if nivel == null:
		print("No se pudo generar con esa semilla.")
		quit(1)
		return
	var t: Tablero = nivel.tablero

	print("")
	print("--- Identidad ---")
	print("semilla (reproducida): %d" % nivel.semilla)
	print("tablero: %d x %d   celdas jugables: %d" % [t.filas, t.columnas, t.jugables.size()])
	print("etiqueta de dificultad: %s" % Generador.dificultad(t))

	print("")
	print("--- Métricas de dificultad ---")
	print("flechas totales:      %d" % t.cantidad_flechas())
	print("CADENA más larga:     %d   <-- jugadas a planificar de antemano" % Metricas.cadena_mas_larga(t))
	print("profundidad (Kahn):   %d" % GrafoDependencias.profundidad(t))
	print("libres al inicio:     %d  (%d%% del total)" % [
		Metricas.libres_iniciales(t),
		int(round(100.0 * Metricas.libres_iniciales(t) / maxf(1.0, float(t.cantidad_flechas()))))])
	print("ratio bloqueo:        %d%%" % int(round(GrafoDependencias.ratio_bloqueo(t) * 100.0)))

	print("")
	print("--- Verificación ---")
	print("resoluble:            %s" % ("si" if GrafoDependencias.es_resoluble(t) else "NO"))
	print("jugadas óptimas:      %d" % Metricas.jugadas_optimas(t))
	print("solución guardada válida: %s" % ("si" if Metricas.verificar_solucion(t, nivel.solucion) else "NO"))
	var v := Metricas.cumple_avanzado(t)
	print("cumple nivel avanzado: %s (%s)" % ["si" if v["ok"] else "NO", v["motivo"]])

	print("")
	print("--- Distribución de longitudes de flecha ---")
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

	print("")
	print("--- Grafo de dependencias (10 flechas más bloqueadas) ---")
	var bloq: Dictionary = GrafoDependencias.bloqueadores(t)
	var filas: Array = []
	for id in bloq.keys():
		filas.append([id, (bloq[id] as Array).size()])
	filas.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	for i in mini(10, filas.size()):
		var id: int = filas[i][0]
		var fl: Flecha = t.flechas[id]
		print("  flecha #%-3d len %2d  bloqueada por %d flechas" % [
			id, fl.longitud(), filas[i][1]])

	_dibujar_mapa(t)
	quit(0)

## Mapa ASCII del tablero: '#' cuerpo, '>' '<' '^' 'v' cabeza con dirección,
## '.' celda jugable vacía, ' ' fuera del tablero.
func _dibujar_mapa(t: Tablero) -> void:
	print("")
	print("--- Mapa (primeras 30 filas) ---")
	var limite := mini(30, t.filas)
	for f in limite:
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