# Flechas (Arrows)

> Puzzle relajante y minimalista. Despeja el tablero sacando flechas que solo se
> mueven en la dirección que apuntan, en el orden correcto para que ninguna quede
> bloqueada.

## Qué es

Un juego de puzzle tipo *Unblock Me / Rush Hour* con flechas. Cada flecha sale
del tablero deslizándose en su dirección **si el camino está libre**. El reto es
descubrir el orden para vaciar el tablero. Todo nivel tiene solución garantizada.

Por dentro es un **problema de grafo de dependencias**: sacar una flecha libera a
otras; un nivel es resoluble si su grafo de bloqueo es acíclico (DAG). Los
niveles se generan por **movimientos inversos** y se validan como DAG. Ver
`.kiro/steering/architecture.md`.

## Stack

- **Godot Engine 4.x** + **GDScript**, render 2D.
- Lógica del puzzle (`src/core/`) separada del render, testeable de forma aislada.

## Estado

**MVP 1 en desarrollo:** progresión **nivel a nivel sin mundos**. Los 5
primeros niveles son de tutorial (fáciles); del 6 en adelante la dificultad
crece (muchas flechas, cadenas de dependencias profundas y caminos enredados),
con figuras aleatorias grandes y zoom/paneo para verlas enteras en pantalla.

Los niveles avanzados se sirven desde un **pool pre-generado** para que la carga
sea inmediata. Ver `docs/GENERADOR.md` para el detalle del generador y
`.kiro/steering/roadmap.md` para el alcance y el camino a seguir.

## Estructura

```
src/core/     # lógica pura: Tablero, Flecha, reglas, grafo, generador inverso
src/game/     # escenas y nodos de juego
src/ui/       # menús, selector de niveles, HUD
src/levels/   # datos de los 10 niveles del Mundo 1
assets/       # sprites y audio
tests/        # pruebas de la lógica de core/
docs/specs/   # specs por feature
```

## Puesta en marcha

1. Instalar **Godot 4.x** (stable).
2. Abrir la carpeta del proyecto en Godot (generará `project.godot`).
3. Ejecutar la escena principal.

> Nota: el proyecto empieza como estructura de carpetas + steering. La escena
> Godot y `project.godot` se crean al abrir en el editor.

## Documentación de diseño

Todo el "por qué" y el alcance viven en `.kiro/steering/`:
- `product.md` — visión y mecánica canónica.
- `architecture.md` — modelo de grafo y generación por movimientos inversos.
- `tech.md` — stack y convenciones.
- `roadmap.md` — MVPs y criterios de terminado.
