extends Node

## Configuración persistente del jugador: idioma y tema.
## Se guarda en user:// para que sobreviva entre sesiones.

const RUTA := "user://config.cfg"

signal cambiado()   # se emite al cambiar idioma o tema

enum Idioma { ES, EN }
enum Tema { AZUL_OSCURO, COLORES }

var idioma: int = Idioma.ES
var tema: int = Tema.AZUL_OSCURO
var sonido: bool = true
var vibracion: bool = true
var efectos: bool = true

func _ready() -> void:
	cargar()

func cargar() -> void:
	var cf := ConfigFile.new()
	if cf.load(RUTA) == OK:
		idioma = int(cf.get_value("pref", "idioma", Idioma.ES))
		tema = int(cf.get_value("pref", "tema", Tema.AZUL_OSCURO))
		sonido = bool(cf.get_value("pref", "sonido", true))
		vibracion = bool(cf.get_value("pref", "vibracion", true))
		efectos = bool(cf.get_value("pref", "efectos", true))

func guardar() -> void:
	var cf := ConfigFile.new()
	cf.set_value("pref", "idioma", idioma)
	cf.set_value("pref", "tema", tema)
	cf.set_value("pref", "sonido", sonido)
	cf.set_value("pref", "vibracion", vibracion)
	cf.set_value("pref", "efectos", efectos)
	cf.save(RUTA)

func set_idioma(v: int) -> void:
	idioma = v
	guardar()
	cambiado.emit()

func set_tema(v: int) -> void:
	tema = v
	guardar()
	cambiado.emit()

func set_sonido(v: bool) -> void:
	sonido = v
	guardar()

func set_vibracion(v: bool) -> void:
	vibracion = v
	guardar()

func set_efectos(v: bool) -> void:
	efectos = v
	guardar()
