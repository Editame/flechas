extends Node2D

## Script de prueba para validar la conexión con la API del servidor.
## Úsalo en la consola de Godot: test_api()

const URL_BASE := "http://127.0.0.1:8000"

func _ready() -> void:
	pass

## Prueba básica: verifica que el servidor responde
func test_salud() -> void:
	print("🔍 Probando endpoint /salud...")
	var http = HTTPRequest.new()
	add_child(http)
	http.request(URL_BASE + "/flechas/v1/salud", false, HTTPClient.METHOD_GET)
	
	http.request_completed.connect(func(id, data, status, headers, body):
		if status == 200:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				print("✅ Salud OK:", json.data)
			else:
				print("❌ Error parseando respuesta")
		else:
			print("❌ Error HTTP:", status, "Body:", body.get_string_from_utf8())
		http.queue_free())

## Prueba de generación de pool
func test_generar_pool() -> void:
	print("\n🔍 Probando endpoint /pool...")
	var http = HTTPRequest.new()
	add_child(http)
	
	var params = {
		"cantidad": 5,
		"dificultad": "super"
	}
	
	http.request(URL_BASE + "/flechas/v1/pool", true, HTTPClient.METHOD_POST, _json_to_bytes(params))
	
	http.request_completed.connect(func(id, data, status, headers, body):
		if status == 200:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				print("✅ Pool generado:")
				print("   Niveles:", json.data.get("meta", {}).get("generados", 0))
				print("   Intentos:", json.data.get("meta", {}).get("intentos", 0))
				print("   Segundos:", json.data.get("meta", {}).get("segundos", 0))
				
				# Mostrar detalles de los niveles
				var niveles = json.data.get("niveles", [])
				for i, n in enumerate(niveles):
					print("\n   Nivel", i+1, ":", n["dificultad"], "- Profundidad:", n["profundidad"], "- Flechas:", n["flechas"])
			else:
				print("❌ Error parseando respuesta")
		else:
			print("❌ Error HTTP:", status)
		http.queue_free())

func _json_to_bytes(data: Dictionary) -> PackedByteArray:
	var json = JSON.new()
	json.data = data
	return json.stringify().to_utf8_buffer()

## Ejecutar todas las pruebas
func test_todo() -> void:
	print("🚀 INICIANDO PRUEBAS DE API")
	print("=" * 50)
	
	test_salud()
	await get_tree().process_frame
	
	test_generar_pool()
	await get_tree().process_frame
	
	print("\n" + "=" * 50)
	print("✅ Pruebas completadas")
