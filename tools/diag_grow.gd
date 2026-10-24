extends SceneTree

## Genera UN nivel con el algoritmo "grow" y lo muestra en ASCII para
## compararlo a ojo con Amaze GO. Es una PRUEBA: si no convence, se borra
## src/core/generador_grow.gd y se sigue con el generador actual.

func _init() -> void:
	var lado := 26
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	print("Generando con GROW (%dx%d)..." % [lado, lado])
	var t0 := Time.get_ticks_msec()
	var res := GeneradorGrow.generar(lado, lado, rng, 3000)
	var ms := (Time.get_ticks_msec() - t0)

	print("intentos=%d  rechazos_facil=%d  rechazos_resoluble=%d  %d ms" % [
		res.intentos, res.rechazos_facil, res.rechazos_resoluble, ms])
	if not res.ok():
		print("NO se genero ningun tablero valido.")
		quit(1)
		return

	var t: Tablero = res.tablero
	print("")
	print("celdas: %d   flechas: %d" % [t.jugables.size(), t.cantidad_flechas()])
	print("CADENA: %d   prof: %d" % [
		Metricas.cadena_mas_larga(t), GrafoDependencias.profundidad(t)])
	print("libres@0: %d (%d%%)   espacio libre: %d%%" % [
		Metricas.libres_iniciales(t),
		int(round(100.0 * Metricas.libres_iniciales(t) / maxf(1.0, float(t.cantidad_flechas())))),
		int(round(Metricas.espacio_libre(t) * 100.0))])
	var r := Metricas.ramificacion(t)
	print("ramificacion media: %.2f  max: %d  %%linea: %.0f%%" % [
		float(r["media"]), int(r["maxima"]), float(r["pct_linea"])])
	print("componentes: %d   resoluble: %s" % [
		Metricas.componentes(t), "si" if GrafoDependencias.es_resoluble(t) else "NO"])

	# Distribucion de longitudes
	var por_len := {}
	var giros_tot := 0
	var c0 := 0
	for id in t.flechas.keys():
		var fl: Flecha = t.flechas[id]
		por_len[fl.longitud()] = int(por_len.get(fl.longitud(), 0)) + 1
		var g := 0
		for i in range(1, fl.celdas.size() - 1):
			if (fl.celdas[i] - fl.celdas[i-1]) != (fl.celdas[i+1] - fl.celdas[i]):
				g += 1
		giros_tot += g
		if g == 0:
			c0 += 1
	var nf := t.cantidad_flechas()
	print("")
	print("giros medios por flecha: %.2f   %% sin giros: %.0f%%" % [
		float(giros_tot) / nf, 100.0 * c0 / nf])
	var lens := por_len.keys()
	lens.sort()
	var linea := ""
	for l in lens:
		linea += "%d:%d " % [l, por_len[l]]
	print("longitudes: " + linea)

	print("")
	print("--- Mapa ---")
	for f in t.filas:
		var s := ""
		for c in t.columnas:
			var celda := Vector2i(f, c)
			if not t.esta_ocupada(celda):
				s += "."
				continue
			var fl: Flecha = t.flechas[t.ocupacion[celda]]
			if celda == fl.cabeza():
				match fl.direccion_salida():
					Vector2i(-1, 0): s += "^"
					Vector2i(1, 0): s += "v"
					Vector2i(0, -1): s += "<"
					_: s += ">"
			else:
				s += "#"
		print(s)
	quit(0)