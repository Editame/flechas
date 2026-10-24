extends SceneTree

## Mide la RAMIFICACIÓN del grafo: cuántas flechas desbloquea cada flecha.
##
## Hallazgo jugando: un nivel con "muchas flechas pequeñas en el mismo sentido,
## la dependencia era la de adelante, salía la primera y se desbloqueaban las
## otras una tras otra" = CINTA TRANSPORTADORA. Cada flecha desbloquea 1, así
## que no hay nada que decidir: es tedioso, no difícil.
##
## Un nivel interesante: sacando una flecha se desbloquean VARIAS, y esas
## bloquean a otras distintas (ramificación alta y encadenada).

func _init() -> void:
	print("=== Ramificacion del grafo de dependencias ===")
	print("nivel | flechas | CADENA | ramif.media | max | %linea | veredicto")
	print("------|---------|--------|-------------|-----|--------|---------")
	for lvl in [6, 7, 8, 9, 10, 11, 12]:
		var nivel := Generador._generar_en_vivo(lvl, 3, 4)
		if nivel == null:
			print("%5d | FALLO" % lvl)
			continue
		var t: Tablero = nivel.tablero
		var r := Metricas.ramificacion(t)
		var cadena := Metricas.cadena_mas_larga(t)
		var pct_linea := float(r["pct_linea"])
		var veredicto := "OK"
		if pct_linea > 55.0:
			veredicto = "CINTA TRANSPORTADORA"
		print("%5d | %7d | %6d | %11.2f | %3d | %5.0f%% | %s" % [
			lvl, t.cantidad_flechas(), cadena, float(r["media"]),
			int(r["maxima"]), pct_linea, veredicto])
	print("")
	print("Referencia: pct_linea alto (>55%) = nivel lineal, tedioso.")
	print("Lo buscado: pct_linea bajo + CADENA alta = interdependencia real.")
	quit(0)