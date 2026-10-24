extends SceneTree

## Responde: ¿los niveles cumplen lo que pedimos, sin depender del feedback
## del jugador?
##
## Mide la "cadena de dependencias más larga" (cuántas jugadas hay que
## planificar de antemano) y las flechas libres al inicio (lo que el jugador
## percibe al abrir el nivel). Un tablero enorme puede ser fácil: lo que
## importa no es el tamaño, es la cadena.

func _init() -> void:
	print("=== Dificultad real por nivel (metrica objetiva) ===")
	print("nivel | celdas | flechas | CADENA | libres@0 | ratio | veredicto")
	print("------|--------|---------|--------|----------|-------|---------")

	var Buffer := []
	for n in range(1, 13):
		var nivel := Generador.generar_para_nivel(n)
		if nivel == null:
			print("%5d | FALLO" % n)
			continue
		var t: Tablero = nivel.tablero
		var p := Metricas.perfil(t)
		var v := Metricas.cumple_avanzado(t)
		var veredicto := "OK" if v["ok"] else ("- tutorial" if n <= 5 else "FALLO: " + str(v["motivo"]))
		print("%5d | %6d | %7d | %7d | %9d | %5.2f | %s" % [
			n, int(p["celdas"]), int(p["flechas"]), int(p["cadena"]),
			int(p["libres_iniciales"]), float(p["ratio_bloqueo"]), veredicto])
		Buffer.append(p)

	# ¿Las soluciones almacenadas en el pool son válidas?
	print("")
	var total_cadena := 0
	var total_libres := 0
	for p in Buffer:
		total_cadena += int(p["cadena"])
		total_libres += int(p["libres_iniciales"])
	if not Buffer.is_empty():
		print("Media cadena de dependencias: %.1f" % (float(total_cadena) / Buffer.size()))
		print("Media flechas libres al inicio: %.1f" % (float(total_libres) / Buffer.size()))
	quit(0)