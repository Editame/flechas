extends Node

## Gestiona sonido (tonos procedurales) y vibración, respetando Config.
## Autoload "Audio". No requiere archivos de sonido externos.

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

## Reproduce un tono corto (frecuencia Hz, duración s) si el sonido está activo.
func _tono(freq: float, dur: float, volumen: float = 0.5) -> void:
	if not Config.sonido:
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = dur + 0.05
	_player.stream = gen
	_player.volume_db = linear_to_db(volumen)
	_player.play()
	var pb: AudioStreamGeneratorPlayback = _player.get_stream_playback()
	if pb == null:
		return
	var total := int(gen.mix_rate * dur)
	var fase := 0.0
	var incr := freq / gen.mix_rate
	for i in total:
		# Envolvente simple (ataque/decay) para que no "clickee".
		var env := 1.0 - float(i) / total
		var s := sin(fase * TAU) * env * 0.6
		pb.push_frame(Vector2(s, s))
		fase += incr

## Sonido satisfactorio al sacar una flecha (whoosh corto ascendente).
func salida() -> void:
	_tono(520.0, 0.12, 0.4)

## Sonido de bloqueo (tono grave corto) + vibración.
func colision() -> void:
	_tono(160.0, 0.10, 0.5)
	if Config.vibracion:
		Input.vibrate_handheld(60)

## Sonido de victoria (dos tonos).
func victoria() -> void:
	_tono(660.0, 0.14, 0.4)
