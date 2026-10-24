extends SceneTree

## Compara el efecto del TANGLE FACTOR sobre la dificultad real.
## Genera el mismo tablero con distintos valores de tangle y compara
## nº de flechas, profundidad del grafo y nº de giros medios por flecha.

func _init() -> void:
	print("=== Efecto del Tangle Factor (mismo tamano, distinto tangle) ===")
	print("tangle | ms   | celdas | flechas | prof | ratio | giros/flecha")
	print("-------|------|--------|---------|------|-------|-------------")
	for tangle in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var t0 := Time.get_ticks_usec()
		var nivel := _generar_con_tangle(22, 4242, tangle)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		if nivel == null:
			print("%5.2f | %5.0f | FALLO" % [tangle, ms])
			continue
		var t: Tablero = nivel.tablero
		print("%5.2f | %4.0f | %6d | %7d | %4d | %5.2f | %11.2f" % [
			tangle, ms, t.jugables.size(), t.cantidad_flechas(),
			GrafoDependencias.profundidad(t),
			GrafoDependencias.ratio_bloqueo(t),
			_giros_medios(t)])
	quit(0)

func _generar_con_tangle(cols: int, semilla: int, tangle: float) -> Generador.Nivel:
	# Replica generar_grande pero forzando el tangle.
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var filas := int(cols * 1.4)
	var forma := Figuras.figura_dinamica(filas, cols, rng)
	var bb := Generador._bbox(forma)
	var objetivo := int(forma.size() * 0.8 / 3.0)
	return Generador._construir(forma, bb.x, bb.y, objetivo, semilla + 777, 2, tangle)

## Nº medio de cambios de direccion por flecha (proxy de enredado).
func _giros_medios(t: Tablero) -> float:
	if t.flechas.is_empty():
		return 0.0
	var total := 0
	for id in t.flechas.keys():
		var fl: Flecha = t.flechas[id]
		for i in range(1, fl.celdas.size() - 1):
			var d1: Vector2i = fl.celdas[i] - fl.celdas[i - 1]
			var d2: Vector2i = fl.celdas[i + 1] - fl.celdas[i]
			if d1 != d2:
				total += 1
	return float(total) / float(t.flechas.size())