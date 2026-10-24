extends SceneTree

## Comprueba la CONECTIVIDAD del grafo de dependencias: un nivel difícil debe
## ser UNA masa interconectada. Varias componentes = islas de flechas que nadie
## bloquea = jugadas gratis.
##
## Referencia: pantallazos reales de Amaze GO. Nivel 68 "Súper Difícil" = una
## sola masa (1 componente). Nivel 70 "Difícil" = masa central + islas sueltas
## abajo, y se resolvió mucho más rápido.

func _init() -> void:
	print("=== Conectividad del grafo de dependencias ===")
	print("nivel | flechas | CADENA | componentes | veredicto")
	print("------|---------|--------|-------------|---------")
	var malas := 0
	for lvl in [6, 7, 8, 9, 10, 11, 12]:
		var nivel := Generador._generar_en_vivo(lvl, 3, 4)
		if nivel == null:
			print("%5d | FALLO" % lvl)
			continue
		var t: Tablero = nivel.tablero
		var comps := Metricas.componentes(t)
		var cadena := Metricas.cadena_mas_larga(t)
		var nf := t.cantidad_flechas()
		var veredicto := "OK (1 masa)" if comps <= 1 else "ATENCIÓN: %d islas" % comps
		if comps > 1:
			malas += 1
		print("%5d | %7d | %6d | %11d | %s" % [lvl, nf, cadena, comps, veredicto])
	print("")
	print("Niveles con islas sueltas: %d/7" % malas)
	quit(0)