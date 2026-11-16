extends Control

## Pantalla de arranque: la primera vez muestra la historia; después el hub.

func _ready() -> void:
	await get_tree().process_frame
	var primera := true
	if has_node("/root/Config"):
		primera = not get_node("/root/Config").intro_vista
	var ruta := "res://src/ui/intro.tscn" if primera else "res://src/ui/hub.tscn"
	get_tree().change_scene_to_file(ruta)
