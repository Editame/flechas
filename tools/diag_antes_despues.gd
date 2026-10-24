extends SceneTree

## Mide la dificultad REAL de niveles recién generados (sin pasar por el pool,
## que puede estar a medio generar y devolver siempre el mismo nivel).
##
## Métricas: cadena = jugadas a planificar; libres@0 = flechas sacables sin
## pensar al abrir el nivel.

func _init() -> void:
	print("=== Dificultad real por nivel (generacion directa) ===")
	print("nivel | celdas | flechas | CADENA | libres@0 | %libres | etiqueta")
	print("------|--------|---------|--------|----------|--------|---------")
	var sum_cadena := 0
	var sum_libres := 0
	var n := 0
	for lvl in [6, 7, 8, 9, 10, 11, 12]:
		var nivel := Generador._generar_en_vivo(lvl, 3, 4)
		if nivel == null:
			print("%5d | FALLO" % lvl)
			continue
		var t: Tablero = nivel.tablero
		var cadena := Metricas.cadena_mas_larga(t)
		var libres := Metricas.libres_iniciales(t)
		var fl := t.cantidad_flechas()
		var pct := 100.0 * float(libres) / maxf(1.0, float(fl))
		print("%5d | %6d | %7d | %7d | %9d | %5.1f%% | %s" % [
			lvl, t.jugables.size(), fl, cadena, libres, pct,
			Generador.dificultad(t)])
		sum_cadena += cadena
		sum_libres += pct
		n += 1
	if n > 0:
		print("")
		print("MEDIA cadena: %.1f   MEDIA %%libres: %.1f%%" % [
			float(sum_cadena) / n, float(sum_libres) / n])
		print("(antes del arreglo: cadena ~12, libres ~35%)")
	quit(0)