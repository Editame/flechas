extends Node

## Singleton (autoload) para pasar estado mínimo entre escenas:
## qué nivel se va a jugar, y los datos del nivel generado (semilla y
## solución) para poder auditarlo después.

var nivel_actual: int = 1

## Semilla con la que se generó el nivel actual. Permite reproducir el nivel
## EXACTO con tools/inspeccionar_semilla.gd.
var semilla_nivel: int = 0

## Solución (orden de salida) del nivel actual, tal como la generó el
## generador. Permite verificar que el nivel tiene solución válida.
var solucion_nivel: Array = []

func fijar_nivel(numero: int, semilla: int, solucion: Array) -> void:
	nivel_actual = numero
	semilla_nivel = semilla
	solucion_nivel = solucion