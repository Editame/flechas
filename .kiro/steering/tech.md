# Tecnología y convenciones — Flechas

> Steering permanente. Stack y reglas de código.

## Stack

| Capa | Elección | Por qué |
|------|----------|---------|
| Motor | **Godot Engine 4.x** (stable) | Gratis, open source, excelente 2D, exporta a móvil/escritorio/web |
| Lenguaje | **GDScript** | Nativo de Godot, rápido de iterar, ideal para 2D/puzzle |
| Render | **2D** (Node2D / Control) | El juego es una cuadrícula 2D |
| Datos de nivel | **Recursos `.tres` o JSON** | Niveles como datos, no hardcodeados en escenas |
| Animación | **Tween** | Deslizamiento de flechas, feedback |

Regla: **la lógica del puzzle es independiente del render.** El "modelo"
(tablero, flechas, reglas de salida, grafo de dependencias) debe poder probarse
sin abrir el motor gráfico. La UI solo dibuja y envía eventos de toque.

## Estructura de carpetas (objetivo)

```
flechas/
├─ project.godot            # proyecto Godot (se crea al abrir en el editor)
├─ .kiro/steering/          # este steering (product, tech, architecture)
├─ docs/specs/              # specs por feature
├─ src/
│  ├─ core/                 # LÓGICA PURA (sin nodos): Tablero, Flecha, reglas,
│  │                        #   grafo de dependencias, generador inverso
│  ├─ game/                 # escenas y scripts de juego (nodos Godot)
│  ├─ ui/                   # menús, HUD, selector de niveles
│  └─ levels/               # datos de los niveles del Mundo 1
├─ assets/
│  ├─ sprites/              # flechas, tablero, fondos
│  └─ audio/                # sfx suaves (opcional en MVP)
└─ tests/                   # pruebas de la lógica pura (GUT o gdscript test)
```

## Convenciones de código

- **Idioma del dominio en español** (Tablero, Flecha, Direccion, Nivel).
- **Separación estricta modelo/vista:** nada de lógica de reglas dentro de nodos
  visuales. El `core/` no importa nada de `game/` ni `ui/`.
- **Datos inmutables donde tenga sentido**; el estado del tablero se muta de
  forma controlada por métodos claros (`intentar_sacar`, `esta_bloqueada`).
- **Niveles como datos**, no como escenas hechas a mano.
- **Determinismo:** el generador de niveles usa una **semilla** para poder
  reproducir un nivel exacto.

## Verificación

- La lógica de `core/` se prueba con tests (solubilidad, bloqueos, salida).
- Antes de dar por hecho un nivel: **validar que es resoluble** (grafo acíclico).

## Qué NO usar (en el MVP)

- Físicas (RigidBody), 3D, shaders complejos.
- Plugins pesados o de un solo mantenedor para piezas críticas.
- Lógica de juego dentro de la UI.
