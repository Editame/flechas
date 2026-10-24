class_name I18n
extends RefCounted

## Textos traducibles ES/EN. Uso: I18n.t("clave").
## El idioma actual viene de Config.idioma.

const TEXTOS := {
	"app_titulo": {"es": "Flechas", "en": "Arrows"},
	"mundo1_sub": {"es": "Mundo 1 · Fácil", "en": "World 1 · Easy"},
	"nivel": {"es": "Nivel", "en": "Level"},
	"resuelto": {"es": "¡Nivel resuelto! 🎉", "en": "Solved! 🎉"},
	"bloqueada": {"es": "Bloqueada 🚫", "en": "Blocked 🚫"},
	"atascado": {"es": "Atascado — deshaz o reinicia", "en": "Stuck — undo or restart"},
	"deshacer": {"es": "Deshacer", "en": "Undo"},
	"reiniciar": {"es": "Reiniciar", "en": "Restart"},
	"menu": {"es": "Menú", "en": "Menu"},
	"ajustes": {"es": "Ajustes", "en": "Settings"},
	"idioma": {"es": "Idioma", "en": "Language"},
	"tema": {"es": "Tema", "en": "Theme"},
	"tema_azul": {"es": "Suave", "en": "Soft"},
	"tema_colores": {"es": "Colores", "en": "Colors"},
	"espanol": {"es": "Español", "en": "Spanish"},
	"ingles": {"es": "Inglés", "en": "English"},
	"cuenta": {"es": "Invitado", "en": "Guest"},
	"volver": {"es": "Volver", "en": "Back"},
	"opciones": {"es": "Opciones", "en": "Options"},
	"sonido": {"es": "Sonido", "en": "Sound"},
	"vibracion": {"es": "Vibración", "en": "Vibration"},
	"efectos": {"es": "Efectos", "en": "Effects"},
	"cerrar": {"es": "Cerrar", "en": "Close"},
	"jugar": {"es": "Jugar", "en": "Play"},
	"buen_trabajo": {"es": "¡Buen trabajo!", "en": "Good Job!"},
	"impresionante": {"es": "¡Impresionante!", "en": "Impressive!"},
	"maravilloso": {"es": "¡Maravilloso!", "en": "Wonderful!"},
	"nivel_completado": {"es": "Nivel completado", "en": "Level completed"},
	"siguiente_nivel": {"es": "Siguiente nivel", "en": "Next level"},
	"inicio": {"es": "Inicio", "en": "Home"},
	"movs": {"es": "movs", "en": "moves"},
	"jugar_nivel": {"es": "Jugar · Nivel", "en": "Play · Level"},
	"dif_facil": {"es": "Fácil", "en": "Easy"},
	"dif_medio": {"es": "Medio", "en": "Medium"},
	"dif_dificil": {"es": "Difícil", "en": "Hard"},
	"dif_super": {"es": "Súper Difícil", "en": "Super Hard"},
	"reiniciar_progreso": {"es": "Reiniciar progreso", "en": "Reset progress"},
	"confirmar_reinicio": {"es": "¿Borrar todo el progreso y volver al nivel 1?", "en": "Erase all progress and go back to level 1?"},
	"si": {"es": "Sí", "en": "Yes"},
	"no": {"es": "No", "en": "No"},
}

static func t(clave: String) -> String:
	var lang := "es"
	# Config es autoload; accesible por ruta absoluta.
	var loop := Engine.get_main_loop()
	if loop and loop.root.has_node("Config"):
		lang = "en" if loop.root.get_node("Config").idioma == 1 else "es"
	if TEXTOS.has(clave):
		return TEXTOS[clave].get(lang, clave)
	return clave
