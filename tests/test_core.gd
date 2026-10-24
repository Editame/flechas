extends SceneTree

## Pruebas de la lógica core (modelo de flechas que DOBLAN). Headless:
##   godot --headless --path . --script tests/test_core.gd

var _fallos := 0
var _total := 0

func _check(cond: bool, nombre: String) -> void:
	_total += 1
	if cond:
		print("  [OK] ", nombre)
	else:
		_fallos += 1
		print("  [FALLO] ", nombre)

func _init() -> void:
	print("=== Tests core Flechas ===")
	_test_salida_recta()
	_test_bloqueo()
	_test_desbloqueo()
	_test_direccion_salida_con_giro()
	_test_atascado_ciclo()
	_test_relleno_total()
	print("=== %d/%d OK, %d fallos ===" % [_total - _fallos, _total, _fallos])
	quit(1 if _fallos > 0 else 0)

# Camino recto horizontal, sale a la derecha.
func _test_salida_recta() -> void:
	var t := Tablero.rectangular(1, 4)
	# cola (0,0) -> cabeza (0,1); dirección de salida = derecha.
	var f := Flecha.new(0, [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i])
	t.colocar(f)
	_check(f.direccion_salida() == Vector2i(0, 1), "direccion salida derecha")
	_check(t.puede_salir(0), "camino recto sale")
	_check(t.intentar_sacar(0) == Tablero.RESULTADO_EXITOSA, "sacar exitosa")
	_check(t.esta_vacio(), "tablero vacio tras sacar")

# Una flecha bloquea el frente de otra.
func _test_bloqueo() -> void:
	var t := Tablero.rectangular(1, 4)
	# A: (0,0)->(0,1) sale derecha. B: (0,2)->(0,3) sale derecha.
	var a := Flecha.new(0, [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i])
	var b := Flecha.new(1, [Vector2i(0, 2), Vector2i(0, 3)] as Array[Vector2i])
	t.colocar(a)
	t.colocar(b)
	_check(not t.puede_salir(0), "A bloqueada por B")
	_check(t.puede_salir(1), "B puede salir (borde libre)")

func _test_desbloqueo() -> void:
	var t := Tablero.rectangular(1, 4)
	var a := Flecha.new(0, [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i])
	var b := Flecha.new(1, [Vector2i(0, 2), Vector2i(0, 3)] as Array[Vector2i])
	t.colocar(a)
	t.colocar(b)
	_check(not t.puede_salir(0), "A inicialmente bloqueada")
	t.intentar_sacar(1)
	_check(t.puede_salir(0), "A desbloqueada tras sacar B")

# Camino que DOBLA: la salida sigue el último segmento.
func _test_direccion_salida_con_giro() -> void:
	var t := Tablero.rectangular(3, 3)
	# camino: (2,0)->(1,0)->(1,1): último segmento va hacia la DERECHA (0,1).
	var f := Flecha.new(0, [Vector2i(2, 0), Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i])
	t.colocar(f)
	_check(f.direccion_salida() == Vector2i(0, 1), "salida = ultimo segmento (derecha)")
	# La cabeza (1,1) desliza a la derecha: (1,2) libre -> sale.
	_check(t.puede_salir(0), "flecha con giro sale por su frente")

# Dos flechas que se bloquean mutuamente = ciclo/atasco.
func _test_atascado_ciclo() -> void:
	var t := Tablero.rectangular(1, 2)
	# A (0,0) mira derecha (hacia B), B (0,1) mira izquierda (hacia A).
	var a := Flecha.new(0, [Vector2i(0, -0), Vector2i(0, 0)] as Array[Vector2i])
	# Construimos direcciones opuestas con caminos de 2 fuera->dentro:
	# A: cola fuera no vale; usamos 2 celdas reales.
	# Simplificamos: A ocupa (0,0) con cabeza mirando derecha usando celda previa virtual.
	# En su lugar, test directo con puede_salir sobre config bloqueante:
	t = Tablero.rectangular(1, 2)
	var a2 := Flecha.new(0, [Vector2i(0, 1), Vector2i(0, 0)] as Array[Vector2i]) # cabeza (0,0) mira izq -> borde: sale
	# Para un ciclo real necesitamos 2 celdas c/u; en 1x2 no cabe. Probamos 1x4:
	t = Tablero.rectangular(1, 4)
	var x := Flecha.new(0, [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i]) # mira derecha -> bloqueada por Y
	var y := Flecha.new(1, [Vector2i(0, 3), Vector2i(0, 2)] as Array[Vector2i]) # mira izquierda -> bloqueada por X
	t.colocar(x)
	t.colocar(y)
	_check(not t.hay_movimiento_posible(), "ciclo: nadie puede salir")
	_check(t.atascado(), "detecta atascado")
	_check(GrafoDependencias.orden_solucion(t).is_empty(), "grafo: sin solucion en ciclo")

# Generador (prioriza dificultad): flechas len>=2, contiguas, resoluble, con
# dependencias (profundidad >= 1). Ya NO exige relleno 100%.
func _test_relleno_total() -> void:
	var forma := Figuras.rectangulo(10, 10)
	var nivel := Generador.generar_relleno(forma, 10, 10, 6, 500, 60)
	if nivel == null:
		_check(false, "generador: genera nivel")
		return
	var t: Tablero = nivel.tablero
	var min2 := true
	var contig := true
	for id in t.flechas.keys():
		var fl: Flecha = t.flechas[id]
		if fl.longitud() < 2:
			min2 = false
		for i in range(1, fl.celdas.size()):
			var d: Vector2i = fl.celdas[i] - fl.celdas[i - 1]
			if abs(d.x) + abs(d.y) != 1:
				contig = false
	_check(t.flechas.size() >= 6, "generador: coloca varias flechas")
	_check(min2, "generador: todas longitud >= 2")
	_check(contig, "generador: caminos contiguos ortogonales (sin diagonales)")
	_check(not GrafoDependencias.orden_solucion(t).is_empty(), "generador: resoluble")
