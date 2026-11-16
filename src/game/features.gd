class_name Features
extends RefCounted

## Banderas de producto. Se pueden cambiar sin tocar el codigo desde
## project.godot -> [flechas] mostrar_servidor=true|false.
##
## `mostrar_servidor` deja visible la configuracion del servidor (util en
## desarrollo). En produccion se pone en false y desaparece de Ajustes.

static func servidor_visible() -> bool:
	return bool(ProjectSettings.get_setting("flechas/mostrar_servidor", true))
