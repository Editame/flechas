class_name Direccion
extends RefCounted

## Direcciones que puede apuntar una flecha y su vector (fila, col) en la grilla.
## Convención: fila crece hacia ABAJO, col crece hacia la DERECHA.

enum Tipo { ARRIBA, ABAJO, IZQUIERDA, DERECHA }

## Devuelve el vector de avance (dfila, dcol) para una dirección.
static func vector(tipo: int) -> Vector2i:
	match tipo:
		Tipo.ARRIBA:
			return Vector2i(-1, 0)
		Tipo.ABAJO:
			return Vector2i(1, 0)
		Tipo.IZQUIERDA:
			return Vector2i(0, -1)
		Tipo.DERECHA:
			return Vector2i(0, 1)
	return Vector2i.ZERO

## Dirección opuesta (útil para la generación por movimientos inversos).
static func opuesta(tipo: int) -> int:
	match tipo:
		Tipo.ARRIBA:
			return Tipo.ABAJO
		Tipo.ABAJO:
			return Tipo.ARRIBA
		Tipo.IZQUIERDA:
			return Tipo.DERECHA
		Tipo.DERECHA:
			return Tipo.IZQUIERDA
	return tipo

static func nombre(tipo: int) -> String:
	match tipo:
		Tipo.ARRIBA: return "ARRIBA"
		Tipo.ABAJO: return "ABAJO"
		Tipo.IZQUIERDA: return "IZQUIERDA"
		Tipo.DERECHA: return "DERECHA"
	return "?"

static func todas() -> Array[int]:
	return [Tipo.ARRIBA, Tipo.ABAJO, Tipo.IZQUIERDA, Tipo.DERECHA]
