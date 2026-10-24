# Producto — Flechas (Arrows)

> Steering permanente. Define QUÉ es el juego y para quién. Todo desarrollo debe
> ser coherente con este documento.

## Visión

**Flechas** es un juego de puzzle relajante y minimalista. El tablero contiene
flechas que solo pueden salir deslizándose en la dirección que apuntan. El reto
es descubrir el **orden correcto** para sacarlas todas sin que ninguna quede
bloqueada por otra, hasta despejar el tablero.

Eslogan interno: *"Despeja el tablero, una flecha a la vez."*

## Pilar de diseño

Es, en el fondo, un **problema de dependencias (grafo dirigido)**: sacar una
flecha libera espacio para otras. Un nivel tiene solución si y solo si su grafo
de bloqueo es acíclico (DAG). Ver `architecture.md`.

## Principios de producto

1. **Calma sobre adrenalina.** Estética suave, colores bonitos y no llamativos,
   sin timers agresivos ni ruido visual. Pensar puzzle, no reflejos.
2. **Reglas simples, profundidad emergente.** Una sola mecánica (tocar una flecha
   → sale en su dirección si el camino está libre). La dificultad nace de las
   dependencias entre flechas, no de reglas nuevas.
3. **Todo nivel SIEMPRE tiene solución.** Los niveles se generan/validan para
   garantizar solubilidad (generación por movimientos inversos + validación de
   grafo acíclico). Nunca frustrar con un nivel imposible.
4. **Progresión amable.** Se empieza muy fácil. El primer mundo es una rampa
   suave de aprendizaje.
5. **Sin fricción.** Cero cuentas, cero anuncios intrusivos, jugable de una.

## Mecánica central (canon)

- **Tablero:** una cuadrícula. Las celdas pueden estar ocupadas por una flecha o
  vacías. El **contorno del tablero puede ser cualquier forma** (no tiene que ser
  un rectángulo lleno): hay celdas "jugables" y celdas "fuera".
- **Flecha:** ocupa una o más celdas contiguas en línea (puede ser de **longitud
  variable**: unas más largas que otras). Apunta a una de 4 direcciones
  (arriba/abajo/izquierda/derecha).
- **Movimiento:** al tocar una flecha, intenta salir del tablero deslizándose en
  su dirección. Si todo su recorrido hasta el borde está libre → **sale**. Si hay
  otra flecha en el camino → **bloqueada** (feedback de "no puede", no pasa nada).
- **Victoria:** el tablero queda sin flechas.
- **Atascado:** ninguna flecha restante puede salir (ciclo de bloqueo). Se ofrece
  deshacer o reiniciar.

## Público

Jugadores casuales que disfrutan puzzles tranquilos tipo Unblock Me / Rush Hour,
en ratos cortos. Móvil primero (táctil), pero jugable en escritorio.

## Qué NO es (anti-metas)

- No es un juego de acción ni de tiempo/ritmo.
- No tiene combate, física realista ni gráficos 3D.
- El MVP no tiene monetización, cuentas, ni multijugador.
