extends SceneTree

## ¿Se están formando de verdad las espirales/serpentines?
## Cuenta los cambios de direccion por flecha (giros reales del camino).
##
## Si sale ~1, el generador sigue haciendo "recta + gancho" y la espiral no
## se está manifesting: ese sería el motivo de que el nivel NO se vea ni se
## sienta como el de Amaze GO.

func _init() -> void:
	print("=== Giros reales por flecha (cambios de direccion) ===")
	print("nivel | flechas | giros medios | %con 0 giros | %con 3+ giros | historial")
	print("------|---------|--------------|---------------|-----------------|---------")
	for lvl in [6, 7, 8, 9, 10]:
		var nivel := Generador._generar_en_vivo(lvl, 3, 4)
		if nivel == null:
			print("%5d | FALLO" % lvl)
			continue
		var t: Tablero = nivel.tablero
		var giros_tot := 0
		var c0 := 0
		var c3 := 0
		var histo := {}
		for id in t.flechas.keys():
			var fl: Flecha = t.flechas[id]
			var g := 0
			for i in range(1, fl.celdas.size() - 1):
				var d1: Vector2i = fl.celdas[i] - fl.celdas[i - 1]
				var d2: Vector2i = fl.celdas[i + 1] - fl.celdas[i]
				if d1 != d2:
					g += 1
			giros_tot += g
			histo[g] = int(histo.get(g, 0)) + 1
			if g == 0:
				c0 += 1
			if g >= 3:
				c3 += 1
		var n := t.cantidad_flechas()
		var linea := ""
		var keys := histo.keys()
		keys.sort()
		for k in keys:
			linea += "%d:%d " % [k, histo[k]]
		print("%5d | %7d | %12.2f | %12.0f%% | %14.0f%% | %s" % [
			lvl, n, float(giros_tot) / float(n),
			100.0 * c0 / n, 100.0 * c3 / n, linea])
	print("")
	print("Referencia Amaze GO nivel 73: la mayoria de flechas tiene 2-4 giros.")
	quit(0)