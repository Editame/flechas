extends SceneTree

## ¿Qué calidad se puede REALMENTE alcanzar por semilla?
## Prueba N semillas y reporta la distribución de flechas y profundidad,
## para fijar después un criterio de aceptación HONESTO (que descarte lo flojo).

const PRUEBAS := 14

func _init() -> void:
	print("=== Calidad alcanzable por semilla (tangle 0.9, 24 cols) ===")
	print("cols | semilla | ms   | celdas | flechas | prof | ratio")
	print("-----|---------|------|--------|---------|------|------")
	var mejor_prof := 0
	var mejor_flechas := 0
	for c in [18, 22, 26, 30]:
		var acum_prof := 0
		var acum_flechas := 0
		var found := 0
		for k in PRUEBAS:
			var t0 := Time.get_ticks_usec()
			var nivel := Generador.generar_grande(c, 1000 + k * 7919, 0.9)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			if nivel == null:
				print("%4d | %7d | FALLO" % [c, 1000 + k * 7919])
				continue
			var t: Tablero = nivel.tablero
			var prof := GrafoDependencias.profundidad(t)
			var fl := t.cantidad_flechas()
			acum_prof += prof
			acum_flechas += fl
			found += 1
			mejor_prof = maxi(mejor_prof, prof)
			mejor_flechas = maxi(mejor_flechas, fl)
			print("%4d | %7d | %4.0f | %6d | %7d | %4d | %5.2f" % [
				c, 1000 + k * 7919, ms, t.jugables.size(), fl, prof,
				GrafoDependencias.ratio_bloqueo(t)])
		if found > 0:
			print("  >> cols=%d  PROMEDIO: flechas=%.0f  prof=%.1f" % [
				c, float(acum_flechas) / found, float(acum_prof) / found])
	print("")
	print("Max prof=%d  Max flechas=%d" % [mejor_prof, mejor_flechas])
	quit(0)