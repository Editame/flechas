extends Node

## Progreso y métricas del jugador, persistente en local (user://).
## Estructurado para soportar rankings futuros y sincronización con Google Play
## Games (MVP siguiente): "quién llegó más lejos" (nivel_maximo) y "quién resolvió
## mejor el nivel X" (métricas por nivel: tiempo, movimientos, errores, estrellas).

const RUTA := "user://progreso.save"

signal actualizado()

# --- Progreso global ---
var nivel_actual: int = 1        # nivel en el que va (siguiente a jugar)
var nivel_maximo: int = 1        # nivel más alto alcanzado (ranking principal)
var niveles_resueltos: int = 0   # total de niveles completados
var tiempo_total_seg: float = 0.0
var perfectos: int = 0           # niveles resueltos sin errores
var estrellas_totales: int = 0   # suma de estrellas ganadas

# --- Métricas por nivel: Dict<int, Dict> ---
# clave = numero de nivel; valor = {mejor_tiempo, mejor_movimientos,
#   movimientos_optimos, menos_errores, estrellas, veces_jugado}
var metricas: Dictionary = {}

func _ready() -> void:
	cargar()

func cargar() -> void:
	if not FileAccess.file_exists(RUTA):
		return
	var f := FileAccess.open(RUTA, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	nivel_actual = int(data.get("nivel_actual", 1))
	nivel_maximo = int(data.get("nivel_maximo", 1))
	niveles_resueltos = int(data.get("niveles_resueltos", 0))
	tiempo_total_seg = float(data.get("tiempo_total_seg", 0.0))
	perfectos = int(data.get("perfectos", 0))
	estrellas_totales = int(data.get("estrellas_totales", 0))
	metricas = data.get("metricas", {})

func guardar() -> void:
	var data := {
		"nivel_actual": nivel_actual,
		"nivel_maximo": nivel_maximo,
		"niveles_resueltos": niveles_resueltos,
		"tiempo_total_seg": tiempo_total_seg,
		"perfectos": perfectos,
		"estrellas_totales": estrellas_totales,
		"metricas": metricas,
	}
	var f := FileAccess.open(RUTA, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

## Calcula estrellas (1-3) según errores y eficiencia de movimientos.
static func calcular_estrellas(errores: int, movimientos: int, optimos: int) -> int:
	if errores == 0 and movimientos <= optimos:
		return 3
	if errores <= 2:
		return 2
	return 1

## Registra la finalización de un nivel con sus métricas y guarda.
## Devuelve las estrellas obtenidas.
func completar_nivel(numero: int, tiempo_seg: float, movimientos: int,
		optimos: int, errores: int) -> int:
	var estrellas := calcular_estrellas(errores, movimientos, optimos)

	# Métrica por nivel: guarda el MEJOR resultado histórico.
	var clave := str(numero)
	var prev: Dictionary = metricas.get(clave, {})
	var mejor_tiempo: float = tiempo_seg
	var mejor_mov: int = movimientos
	var menos_err: int = errores
	var mejor_estrellas: int = estrellas
	var veces: int = int(prev.get("veces_jugado", 0)) + 1
	if not prev.is_empty():
		mejor_tiempo = minf(tiempo_seg, float(prev.get("mejor_tiempo", tiempo_seg)))
		mejor_mov = mini(movimientos, int(prev.get("mejor_movimientos", movimientos)))
		menos_err = mini(errores, int(prev.get("menos_errores", errores)))
		mejor_estrellas = maxi(estrellas, int(prev.get("estrellas", estrellas)))
	metricas[clave] = {
		"mejor_tiempo": mejor_tiempo,
		"mejor_movimientos": mejor_mov,
		"movimientos_optimos": optimos,
		"menos_errores": menos_err,
		"estrellas": mejor_estrellas,
		"veces_jugado": veces,
	}

	# Progreso global (solo cuenta la PRIMERA vez que se resuelve).
	if prev.is_empty():
		niveles_resueltos += 1
		estrellas_totales += estrellas
		if errores == 0:
			perfectos += 1
	tiempo_total_seg += tiempo_seg
	nivel_actual = numero + 1
	nivel_maximo = maxi(nivel_maximo, nivel_actual)

	guardar()
	actualizado.emit()
	return estrellas

## Resumen para pantallas de perfil/ranking local.
func resumen() -> Dictionary:
	return {
		"nivel_maximo": nivel_maximo,
		"niveles_resueltos": niveles_resueltos,
		"perfectos": perfectos,
		"estrellas_totales": estrellas_totales,
		"tiempo_total_seg": tiempo_total_seg,
	}

## Reinicia TODO el progreso: vuelve al nivel 1 y borra métricas.
func reiniciar_todo() -> void:
	nivel_actual = 1
	nivel_maximo = 1
	niveles_resueltos = 0
	tiempo_total_seg = 0.0
	perfectos = 0
	estrellas_totales = 0
	metricas = {}
	guardar()
	actualizado.emit()
