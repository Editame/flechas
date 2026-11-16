extends Node

## Estado minimo entre escenas: que nivel se juega y su dificultad.

var nivel_actual: int = 1

## ID del nivel actual cuando viene de la API.
var nivel_actual_id: String = ""

## Dificultad pedida para el nivel actual ("facil".."maximo").
var dificultad_nivel: String = "medio"

## Modo de la partida: "clasico" (avance de niveles) o "diario".
var modo: String = "clasico"

## Fecha del desafio diario ("YYYY-MM-DD") cuando modo == "diario".
var fecha_diaria: String = ""

## Semilla con la que se genero el nivel actual (para reproducirlo).
var semilla_nivel: int = 0

## Solucion (orden de salida) tal como la devolvio el servidor.
var solucion_nivel: Array = []

## URL base del servidor (con el prefijo /flechas/v1).
var url_servidor: String = "http://127.0.0.1:8077/flechas/v1"

func fijar_nivel(numero: int, semilla: int, solucion: Array) -> void:
	nivel_actual = numero
	semilla_nivel = semilla
	solucion_nivel = solucion

func configurar_servidor(url: String) -> void:
	url_servidor = url.strip_edges() if not url.is_empty() else "http://127.0.0.1:8077/flechas/v1"
	if has_node("/root/API_Client"):
		get_node("/root/API_Client").cargar_url_servidor()

func get_url_servidor() -> String:
	return url_servidor
