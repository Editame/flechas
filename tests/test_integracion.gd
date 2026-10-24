extends SceneTree

## Smoke test: verifica que los 10 niveles cargan y son resolubles, y que las
## escenas de menú y juego se instancian sin error. Headless:
##   godot --headless --path . --script tests/test_integracion.gd

func _init() -> void:
	var fallos := 0
	print("=== Smoke test integracion ===")

	# 1) Cargar los 10 niveles y validar solubilidad.
	var niveles := CargadorNiveles.cargar_mundo1()
	if niveles.size() == 10:
		print("  [OK] cargados 10 niveles")
	else:
		print("  [FALLO] esperaba 10, obtuve ", niveles.size())
		fallos += 1

	for nd in niveles:
		var t: Tablero = nd["tablero"]
		var orden := GrafoDependencias.orden_solucion(t)
		if orden.is_empty() and not t.esta_vacio():
			print("  [FALLO] nivel %d no resoluble" % int(nd["numero"]))
			fallos += 1
	if fallos == 0:
		print("  [OK] los 10 niveles son resolubles")

	# 2) Instanciar escenas.
	var menu := load("res://src/ui/main_menu.tscn")
	if menu != null and menu.can_instantiate():
		print("  [OK] main_menu.tscn instanciable")
	else:
		print("  [FALLO] main_menu.tscn"); fallos += 1

	var juego := load("res://src/game/juego.tscn")
	if juego != null and juego.can_instantiate():
		print("  [OK] juego.tscn instanciable")
	else:
		print("  [FALLO] juego.tscn"); fallos += 1

	print("=== %s ===" % ("TODO OK" if fallos == 0 else "%d FALLOS" % fallos))
	quit(1 if fallos > 0 else 0)
