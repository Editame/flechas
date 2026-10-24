# Arquitectura — Flechas

> Steering permanente. Cómo está modelado el juego por dentro.

## Modelo del dominio (core, lógica pura)

```
Direccion = ARRIBA | ABAJO | IZQUIERDA | DERECHA
  vector():  ARRIBA=(-1,0)  ABAJO=(+1,0)  IZQUIERDA=(0,-1)  DERECHA=(0,+1)

Flecha {
  id: int
  celdas: [ (fila,col), ... ]   # 1+ celdas contiguas en línea (longitud variable)
  direccion: Direccion
}

Tablero {
  jugables: Set<(fila,col)>     # celdas que existen (forma arbitraria del tablero)
  ocupacion: Map<(fila,col) -> id_flecha | vacía>
  flechas: Map<id -> Flecha>
}
```

## Regla de salida (mecánica central)

Una flecha sale si TODAS las celdas de su recorrido, desde su frente hasta salir
del área jugable en su dirección, están libres (o fuera = ya es salida).

```
intentar_sacar(flecha):
    (df,dc) = flecha.direccion.vector()
    # recorre desde el "frente" de la flecha hacia su dirección
    para cada paso hasta salir de `jugables`:
        celda = siguiente en (df,dc)
        si celda es jugable y está ocupada por OTRA flecha: return BLOQUEADA
    return EXITOSA   # despejó hasta el borde
```

Ojo: como las flechas tienen **longitud variable**, "el frente" es la celda
extrema en la dirección de avance; el cuerpo la sigue. Al salir, se liberan TODAS
sus celdas.

## El corazón: grafo de dependencias

- Nodo = flecha. Arista **A → B** = "A bloquea la salida de B" (A debe salir antes).
- **Nivel resoluble ⇔ el grafo es un DAG** (sin ciclos).
- **Resolver / dar pista** = ordenamiento topológico (algoritmo de Kahn:
  repetir "saca una flecha sin bloqueadores, actualiza dependencias").
- **Atascado** = quedan flechas pero el subgrafo restante tiene un ciclo
  (in-degree > 0 en todas).

## Generación de niveles: MOVIMIENTOS INVERSOS + validación

Estándar de la industria (Taylor & Parberry, 2011, para Sokoban). Garantiza
solubilidad porque parte de un estado resuelto.

```
generar(semilla, forma_tablero, n_flechas):
  1. Tablero vacío con la forma dada (rectángulo u otra).
  2. Repite n_flechas veces:
       - Elige una celda de borde libre y una dirección "hacia adentro".
       - INYECTA una flecha (de longitud aleatoria dentro de lo que quepa)
         empujándola hacia adentro = el inverso de sacarla.
       - CAPA 1 (prevención): rechaza la inyección si crea un deadlock obvio
         (dejaría una flecha sin ninguna salida futura / cerraría un ciclo).
  3. CAPA 2 (validación): construye el grafo y confirma que es DAG.
     Si NO lo es → descarta y reintenta con otra semilla (límite de intentos).
  4. Guarda el orden inverso de inyección como SOLUCIÓN de referencia.
```

Dos capas de defensa porque la generación inversa garantiza que el *camino* es
resoluble, pero puede producir un *tablero* con deadlock si no se filtra (lección
documentada en generadores reales de Sokoban).

## Dificultad (para el Mundo 1 = Fácil)

Medible por la estructura del grafo:
- **Fácil:** grafo poco profundo, casi lineal, pocas ramas, pocas flechas.
- El Mundo 1 usa: tableros rectangulares pequeños, 3–7 flechas, dependencias
  simples (cadenas cortas), longitudes de flecha variadas para dar variedad
  visual sin subir la dificultad lógica.

## Separación de capas

```
core/   (lógica pura, testeable)   →  no conoce Godot
game/   (nodos, escenas)           →  usa core, dibuja, captura toques
ui/     (menús, HUD)               →  navegación y presentación
levels/ (datos)                    →  niveles del Mundo 1
```
