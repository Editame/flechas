extends SceneTree

## Comprueba de dónde lee la versión el juego.

func _init() -> void:
	var desde_project: Variant = ProjectSettings.get_setting("application/config/version", "AUSENTE")
	print("ProjectSettings 'application/config/version' = '%s'" % str(desde_project))
	print("Version.texto()  = '%s'" % Version.texto())
	print("Version.etiqueta() = '%s'" % Version.etiqueta())
	quit(0)