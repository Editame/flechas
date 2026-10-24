extends SceneTree

## Genera el POOL de niveles difíciles/súper difíciles OFFLINE.
##
## POR QUÉ OFFLINE: los tableros grandes que queremos (500-1600 celdas, 60-170
## flechas) tardan segundos en generarse, y el nivel se construye AL JUGAR, lo
## que bloquearía la UI. Además el generador en vivo caía a su fallback
## (tablero 8x8) y devolvía "difíciles" de 16 flechas.
##
## Este script tiene un LÍMITE DE TIEMPO y GUARDA TRAS CADA NIVEL, para poder
## interrumpirlo sin perder el trabajo ya hecho.
##
## Ejecutar: godot --headless --path . --script tools/generar_pool.gd
## Opcional: --max-minutos=15

const OBJETIVO := 40            # niveles en el pool
const MIN_FLECHAS := 45        # ninguna "difícil" puede tener menos flechas
const MIN_PROF_DIFICIL := 10   # profundidad mínima para "difícil"
const MIN_PROF_SUPER := 13     # profundidad mínima para "súper difícil"
const COLS_MIN := 22
const COLS_MAX := 34
const RUTA := "res://src/levels/dificiles.json"

var _t0 := 0
var _max_usec := 0

func _init() -> void:
	_t0 = Time.get_ticks_msec()
	_max_usec = _leer_presupuesto() * 60 * 1000000

	print("Generando pool de niveles (máx %d, presupuesto %d min)..." % [
		OBJETIVO, int(_max_usec / 60000000)])
	var niveles := _cargar_progreso()
	if niveles.is_empty():
		print("(empezando de cero)")
	else:
		print("(continuando: ya hay %d niveles guardados)" % niveles.size())
	print("")

	var intentos := 0
	while niveles.size() < OBJETIVO:
		if _excede_presupuesto():
			print("")
			print("== Presupuesto de tiempo agotado: %d niveles ==" % niveles.size())
			break
		intentos += 1
		# Alterna el objetivo: mitad "difícil", mitad "súper difícil".
		var quiere_super := (niveles.size() % 2) == 1
		var prof_min := MIN_PROF_SUPER if quiere_super else MIN_PROF_DIFICIL
		# Enredado alto: el pool es para niveles avanzados, asi que tangle alto.
		var tangle := 0.9 if quiere_super else 0.65

		var mejor: Generador.Nivel = null
		var mejor_score := -1.0
		for intento in 4:
			var cols := COLS_MIN + (intento * 6) % (COLS_MAX - COLS_MIN + 1)
			var semilla := _t0 / 1000 + intentos * 977 + intento * 131
			var nivel := Generador.generar_grande(cols, semilla, tangle)
			if nivel == null:
				continue
			var t: Tablero = nivel.tablero
			var flechas := t.cantidad_flechas()
			if flechas < MIN_FLECHAS:
				continue   # queremos MUCHAS flechas
			var prof := GrafoDependencias.profundidad(t)
			if prof < prof_min:
				continue
			var ratio := GrafoDependencias.ratio_bloqueo(t)
			var score := float(prof) * 3.0 + ratio * 20.0 + float(flechas) * 0.05
			if score > mejor_score:
				mejor_score = score
				mejor = nivel

		if mejor == null:
			continue

		niveles.append(_serializar(niveles.size() + 1, mejor))
		# GUARDAR TRAS CADA NIVEL: si se interrumpe, no se pierde lo hecho.
		_guardar(niveles)
		var tb: Tablero = mejor.tablero
		print("  #%02d  %dx%d  celdas=%4d  flechas=%3d  PROF=%2d  bloqueo=%2.0f%%  -> %s" % [
			niveles.size(), tb.filas, tb.columnas, tb.jugables.size(),
			tb.cantidad_flechas(), GrafoDependencias.profundidad(tb),
			GrafoDependencias.ratio_bloqueo(tb) * 100.0, Generador.dificultad(tb)])

	_guardar(niveles)
	print("")
	print("== src/levels/dificiles.json con %d niveles (intentos: %d) ==" % [
		niveles.size(), intentos])
	quit(0)

func _excede_presupuesto() -> bool:
	return _max_usec > 0 and (Time.get_ticks_msec() - _t0) * 1000 > _max_usec

## Lee --max-minutes=N de los argumentos del comando.
func _leer_presupuesto() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--max-minutos="):
			return int(arg.split("=")[1])
	return 12

## Si el pool ya existe, lo carga para poder continuar una generación cortada.
func _cargar_progreso() -> Array:
	if not FileAccess.file_exists(RUTA):
		return []
	var f := FileAccess.open(RUTA, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null or not data.has("niveles"):
		return []
	var res: Array = []
	for nd in data["niveles"]:
		res.append(nd)
	return res

func _guardar(niveles: Array) -> void:
	var f := FileAccess.open(RUTA, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir " + RUTA)
		return
	f.store_string(JSON.stringify({ "tipo": "dificiles", "niveles": niveles }))
	f.close()

func _serializar(numero: int, nivel: Generador.Nivel) -> Dictionary:
	var t: Tablero = nivel.tablero
	var forma: Array = []
	for c in t.jugables.keys():
		forma.append([c.x, c.y])
	var flechas: Array = []
	for id in t.flechas.keys():
		var fl: Flecha = t.flechas[id]
		var celdas: Array = []
		for c in fl.celdas:
			celdas.append([c.x, c.y])
		flechas.append({ "id": fl.id, "celdas": celdas })
	return {
		"numero": numero,
		# SEMILLA: permite reproducir este nivel exacto con
		# tools/inspeccionar_semilla.gd y auditar sus metricas.
		"semilla": nivel.semilla,
		"filas": t.filas,
		"columnas": t.columnas,
		"forma": forma,
		"flechas": flechas,
		"solucion": nivel.solucion,
	}