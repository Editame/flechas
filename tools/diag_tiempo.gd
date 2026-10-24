extends SceneTree

## Diagnostico temporal: mide TIEMPO de generacion por nivel y difficulty.
## El nivel se genera AL JUGAR, asi que el tiempo por nivel es critico.

func _init() -> void:
	print("=== Tiempo de generacion por nivel ===")
	print("Nivel | ms     | celdas | flechas | prof | ratio | dificultad")
	print("------|--------|--------|---------|------|-------|-----------")
	var peor := 0.0
	for n in [1, 3, 5, 6, 7, 8, 9, 10, 12, 15]:
		var t0 := Time.get_ticks_usec()
		var nivel := Generador.generar_para_nivel(n)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		if ms > peor:
			peor = ms
		if nivel == null:
			print("%5d | %6.1f | FALLO" % [n, ms])
			continue
		var t: Tablero = nivel.tablero
		print("%5d | %6.1f | %6d | %7d | %4d | %5.2f | %s" % [
			n, ms, t.jugables.size(), t.cantidad_flechas(),
			GrafoDependencias.profundidad(t),
			GrafoDependencias.ratio_bloqueo(t),
			Generador.dificultad(t)])
	print("\nPeor tiempo: %.1f ms" % peor)
	quit(0)