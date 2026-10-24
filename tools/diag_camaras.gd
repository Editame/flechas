extends SceneTree

## Diagnostico del GENERADOR POR CAMARAS aislado: mide cuantos intentos
##Placean suficientes arrows, cuanto son resolubles y con cuantos giros.
## Asi vemos por que cae al generador clasico.

func _init() -> void:
	print("=== Generador por camaras (aislado) ===")
	print("cols | filas | resultado | flechas | CADENA | giros_med | %0 giros | comps")
	print("-----|-------|-----------|---------|--------|----------|----------|------")
	for cols in [20, 24, 28, 32]:
		for intento in 3:
			var filas := int(cols * 1.4)
			var lvl := Generador._construir_camaras(
				filas, cols, 7000 + intento * 131, 3, 3)
			if lvl == null:
				print("%4d | %5d | FALLO (null)" % [cols, filas])
				continue
			var t: Tablero = lvl.tablero
			var giros := 0
			var c0 := 0
			for id in t.flechas.keys():
				var fl: Flecha = t.flechas[id]
				var g := 0
				for i in range(1, fl.celdas.size() - 1):
					var d1: Vector2i = fl.celdas[i] - fl.celdas[i - 1]
					var d2: Vector2i = fl.celdas[i + 1] - fl.celdas[i]
					if d1 != d2:
						g += 1
				giros += g
				if g == 0:
					c0 += 1
			var n := t.cantidad_flechas()
			print("%4d | %5d | %9s | %7d | %6d | %8.2f | %7.0f%% | %5d" % [
				cols, filas, "OK", n, Metricas.cadena_mas_larga(t),
				float(giros) / maxf(1.0, float(n)),
				100.0 * c0 / maxf(1.0, float(n)), Metricas.componentes(t)])
	quit(0)
