extends Node

## Configuración persistente del jugador: idioma y tema.
## Se guarda en user:// para que sobreviva entre sesiones.

const RUTA := "user://config.cfg"

signal cambiado()   # se emite al cambiar idioma o tema

enum Idioma { ES, EN }
enum TemaApp { NEON, CRISTAL, PIZARRA, AMANECER }

var idioma: int = Idioma.ES
var tema: int = TemaApp.AMANECER
var sonido: bool = true
var vibracion: bool = true
var efectos: bool = true
var intro_vista: bool = false

func _ready() -> void:
	cargar()
	_ajustar_escala()

## Ajusta el tamaño del UI al dispositivo: en tablets baja la escala para que
## las letras no se vean gigantes, y deja más unidades para repartir.
func _ajustar_escala() -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null:
		return
	var vp := DisplayServer.window_get_size()
	if vp.x <= 0 or vp.y <= 0:
		return
	var lado := float(mini(vp.x, vp.y))
	var factor := clampf(1280.0 / maxf(1.0, lado), 0.78, 1.0)
	arbol.root.content_scale_factor = factor

func cargar() -> void:
	var cf := ConfigFile.new()
	if cf.load(RUTA) == OK:
		idioma = int(cf.get_value("pref", "idioma", Idioma.ES))
		tema = Tema.normalizar(int(cf.get_value("pref", "tema", TemaApp.AMANECER)))
		sonido = bool(cf.get_value("pref", "sonido", true))
		vibracion = bool(cf.get_value("pref", "vibracion", true))
		efectos = bool(cf.get_value("pref", "efectos", true))
		intro_vista = bool(cf.get_value("pref", "intro_vista", false))

func guardar() -> void:
	var cf := ConfigFile.new()
	cf.set_value("pref", "idioma", idioma)
	cf.set_value("pref", "tema", tema)
	cf.set_value("pref", "sonido", sonido)
	cf.set_value("pref", "vibracion", vibracion)
	cf.set_value("pref", "efectos", efectos)
	cf.set_value("pref", "intro_vista", intro_vista)
	cf.save(RUTA)

func set_idioma(v: int) -> void:
	idioma = v
	guardar()
	cambiado.emit()

func set_tema(v: int) -> void:
	tema = Tema.normalizar(v)
	Tema.aplicar(tema)
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

func set_intro_vista(v: bool) -> void:
	intro_vista = v
	guardar()
