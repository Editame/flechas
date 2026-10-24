extends SceneTree

## Verifica el POOL generado antes de mandarlo al juego.
##
## Un nivel bueno NO es solo "se resuelve": tiene que ser RESOLUBLE (el solver
## lo vacía), tener profundidad (cadenas de dependencias) y muchas flechas.
## Este script reconstruye cada nivel del JSON y lo mide, dato por dato.
## Si algo falla, lo dice en vez de dejar que el jugador lo encuentre.

const RUTA := "res://src/levels/dificiles.json"

func _init() -> void:
	if not FileAccess.file_exists(RUTA):
		print("FALLO: no existe " + RUTA)
		quit(1)
		return
	var f := FileAccess.open(RUTA, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null or not data.has("niveles"):
		print("FALLO: JSON invalido")
		quit(1)
		return

	var niveles: Array = data["niveles"]
	print("=== Verificacion del pool: %d niveles ===" % niveles.size())
	print("#   | filas x cols | celdas | flechas | prof | ratio | resoluble | veredicto")
	print("----|--------------|--------|---------|------|-------|-----------|---------")

	var ok := 0
	var malos: Array = []
	var sum_flechas := 0
	var sum_prof := 0

	for i in niveles.size():
		var nd = niveles[i]
		var t := Tablero.new(int(nd["filas"]), int(nd["columnas"]))
		for c in nd["forma"]:
			t.agregar_celda(Vector2i(int(c[0]), int(c[1])))
		for fd in nd["flechas"]:
			var celdas: Array[Vector2i] = []
			for c in fd["celdas"]:
				celdas.append(Vector2i(int(c[0]), int(c[1])))
			t.colocar(Flecha.new(int(fd["id"]), celdas, Color.WHITE))

		var flechas := t.cantidad_flechas()
		var prof := GrafoDependencias.profundidad(t)
		var ratio := GrafoDependencias.ratio_bloqueo(t)
		var resoluble := GrafoDependencias.es_resoluble(t)
		var celdas := t.jugables.size()
		sum_flechas += flechas
		sum_prof += prof

		# Criterio de calidad del pool (niveles 6+).
		var veredicto := "OK"
		if not resoluble:
			veredicto = "NO RESOLUBLE"
		elif flechas < 45:
			veredicto = "POCAS FLECHAS"
		elif prof < 10:
			veredicto = "POCA PROFUNDIDAD"
		elif ratio < 0.35:
			veredicto = "POCO BLOQUEO"

		if veredicto == "OK":
			ok += 1
		else:
			malos.append(i + 1)

		print("#%-2d | %3d x %3d    | %6d | %7d | %4d | %5.2f | %9s | %s" % [
			i + 1, int(nd["filas"]), int(nd["columnas"]), celdas, flechas,
			prof, ratio, "si" if resoluble else "NO", veredicto])

	print("")
	print("Niveles OK: %d/%d" % [ok, niveles.size()])
	if niveles.size() > 0:
		print("Media flechas: %.0f" % (float(sum_flechas) / niveles.size()))
		print("Media profundidad: %.1f" % (float(sum_prof) / niveles.size()))
	if not malos.is_empty():
		print("Niveles con problema: %s" % str(malos))
	quit(0 if malos.is_empty() else 1)