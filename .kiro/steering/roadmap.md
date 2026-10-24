# Hoja de ruta y MVPs — Flechas

> Steering permanente. Define el ALCANCE por fases.
> **Nota:** el alcance original ("Mundo 1" de 10 niveles fáciles) quedó
> superado: el juego pasó a **progresión nivel a nivel sin mundos**, con niveles
> generados y dificultad creciente. Ver `docs/GENERADOR.md` para el detalle
> técnico del generador y el camino a seguir.

## Enfoque de juego (actual)

- **Sin mundos ni niveles fijos.** El jugador avanza **nivel a nivel** de forma
  indefinida: si quiere mil niveles, los hay.
- **Niveles 1–5: tutorial.** Niveles fáciles para aprender la mecánica.
- **Niveles 6+:** dificultad creciente con **tangle** (enredado) escalonado.
  Se sirven desde un **pool pre-generado** para que la carga sea instantánea.
- Figuras de tablero **aleatorias** (no solo rectángulos), de tamaño grande, con
  **zoom y paneo** para que quepan en pantalla.
- Referencia de dificultad: *Amaze GO* / *Arrow Escape* — muchas flechas y
  cadenas de dependencias profundas, no solo tableros más grandes.

## MVP 1 — Cerrar el bucle jugable (META ACTUAL) 🎯

Objetivo: que el jugador pueda jugar niveles del 1 al infinito con dificultad
real y comprobarla en el móvil.

### Alcance incluido
- Mecánica de salida/bloqueo con feedback, deshacer y reiniciar. ✅
- Progresión nivel a nivel con progreso persistente. ✅
- Tutorial de 5 niveles + niveles avanzados. ✅ (falta validar jugando)
- Generador con tangle, orden de longitudes y generar-y-elegir. ✅
- Pool pre-generado para carga instantánea. ⚠️ falta regenerar
- Estética suave, colores no llamativos. ✅
- Pan/zoom para tableros grandes. ✅ (falta validar en dispositivo)

### Fuera de alcance
- Monetización, cuentas, logros, multijugador.
- Sonido y música como bloqueante (el código existe, faltan los archivos).

### Criterio de "MVP 1 terminado"
1. Se pueden jugar niveles del 1 al infinito sin que el generador falle.
2. Los niveles 6+ tienen **profundidad ≥10** y **≥45 flechas** (medido).
3. Un humano los resuelve **con dificultad real**, no al primer intento.
4. El tablero grande se ve encuadrado y usable en móvil.
5. `core/` con tests en verde. ✅ (17/17)

## MVP 2 — Variedad y curva de dificultad
- Mecánicas nuevas para subir dificultad sin solo agrandar (flechas que empujan).
- Curva de dificultad medida con datos de juego real.
- "Etapas"/desbloqueos como contenido de larga duración.

## MVP 3 — Escala y plataforma
- Delta-encoding del pool para reducir tamaño.
- Keystore de release y publicación.
- Exportación a otras plataformas.

## Decisiones abiertas
- **¿Qué pasa al agotar el pool?** Regenerar, ciclar, o "etapas".
- Colores exactos de la paleta (definir en spec de UI).
- ¿Deshacer ilimitado o limitado? (actual: ilimitado, más amable).
