extends SceneTree

## Mide la dificultad PERCEPTIVA: cuántas flechas PARECEN libres pero no lo
## están (cebos), y cuánto espacio libre hay (a más espacio, más fácil es ver
## los corridors de un vistazo).

func _init() -> void:
	print("=== Dificultad perceptiva (lo que cuesta ver qué está libre) ===")
	print("nivel | flechas | CADENA | cebo | cebo% | espac.libre | veredicto")
	print("------|---------|--------|------|-------|-------------|---------")
	var sum_cebo := 0.0
	var sum_cadena := 0.0
	var n := 0
	for lvl in [6, 7, 8, 9, 10, 11, 12]:
		var nivel := Generador._generar_en_vivo(lvl, 3, 4)
		if nivel == null:
			print("%5d | FALLO" % lvl)
			continue
		var t: Tablero = nivel.tablero
		var p := Metricas.perfil(t)
		var nf := int(p["flechas"])
		var cebo := int(p["cebos"])
		var pct_c := 100.0 * cebo / maxf(1.0, float(nf))
		var pct_e := float(p["espacio_libre"]) * 100.0
		print("%5d | %7d | %6d | %4d | %4.0f%% | %11.0f%% | %s" % [
			lvl, nf, int(p["cadena"]), cebo, pct_c, pct_e,
			Generador.dificultad(t)])
		sum_cebo += pct_c
		sum_cadena += float(p["cadena"])
		n += 1
	if n > 0:
		print("")
		print("MEDIA cebo: %.0f%%   MEDIA cadena: %.1f" % [
			sum_cebo / n, sum_cadena / n])
	quit(0)