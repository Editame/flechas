class_name Version
extends RefCounted

## VERSIÃ“N DEL JUEGO â€” un solo sitio donde mirar.
##
## PROBLEMA QUE RESUELVE: la versiÃ³n estaba escrita a mano dentro de
## main_menu.tscn y se me olvidÃ³ actualizarla en 6 versiones seguidas (se
## anunciaban v0.6.0, v0.7.0 y v0.8.0 en los commits mientras la app seguÃ­a
## mostrando v0.5.0).
##
## POR QUÃ‰ UNA CONSTANTE Y NO project.godot: se probÃ³ leerla de
## `application/config/version` en project.godot y Godot NO la expone:
## ProjectSettings.get_setting devuelve "" (las claves personalizadas bajo
## [application] no se registran). Con la constante no hay sorpresas, y sigue
## siendo un Ãºnico sitio que editar.
##
## Al subir la versiÃ³n: cambia SOLO este nÃºmero.

const VERSION := "0.9.0"

## VersiÃ³n como string ("0.8.0").
static func texto() -> String:
	return VERSION

## VersiÃ³n como "v0.8.0" (con la v, como se muestra en pantalla).
static func etiqueta() -> String:
	var t := texto()
	return t if t.begins_with("v") else "v" + t

## Devuelve (major, minor, patch) para comparaciones.
static func numeros() -> Array:
	var partes := texto().replace("v", "").split(".")
	var res := [0, 0, 0]
	for i in mini(3, partes.size()):
		res[i] = int(partes[i])
	return res