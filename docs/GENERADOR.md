# Generador de niveles — investigación, estado y camino a seguir

> Documento de trabajo. Recoge por qué el generador es como es, qué se cambió
> para llegar a niveles con dificultad real, y qué falta para cerrar el MVP.

---

## 1. El problema que nos trajo aquí

Los niveles se resolvían **demasiado fácil**. Pedir "más flechas" no bastaba: al
agrandar los tableros, la generación en vivo pasó a tardar **40 segundos por
nivel** y además caía a un *fallback* de 8×8 que devolvía un "difícil" de 16
flechas. Es decir: más tamaño, más flechas y más tiempo, pero **menos
dificultad**.

Conclusión: el problema no era el tamaño, era el **algoritmo**.

---

## 2. Referencia: cómo lo hacen otros

Se estudió `gtxPrime/arrow-escape` (MIT), que documenta su generador en
`level_design_requirements.md` y su README. De ahí salieron cuatro ideas que
nos faltaban:

| Idea de la referencia | Qué aporta | ¿La tenemos? |
|-----------------------|------------|--------------|
| **Tangle Factor** 0.0→1.0 | Controla cuánto se enredan los caminos. 0.0 = rectas, 1.0 = zig-zag máximo. Escala por nivel. | **Sí** (implementada) |
| **Reverse placement**: muy larga → larga → media | Las primeras flechas en construcción inversa son las más largas; enredan el tablero desde el principio | **Sí** (versión híbrida) |
| **Doble verificación** greedy + DFS | Solo acepta niveles que pasan dos solvers | **Parcial** (ver §5) |
| **Delta-encoding** de rutas | 500 niveles en 741 KB | **Pendiente** |

También notamos que la referencia **topa el tablero en 35×35** (1600 celdas
máximo) por jugabilidad. Nuestros niveles de1632 celdas ya están en ese límite.

---

## 3. Qué cambiamos (y por qué)

### 3.1 Tangle Factor
`_camino_serpiente` recibía un `tangle` (0.0–1.0). Con tangle bajo, el camino
intenta seguir recto; con alto, gira en cada paso.

**Bug encontrado y corregido al implementarlo:** con `tangle` 0.0–0.25 la
generación **fallaba** (0 tableros). En modo recto el camino se cortaba al
chocar y quedaban flechas de 1 celda, que se descartaban. Como el tutorial usa
tangle 0.0, los niveles 1–5 no se generaban. Arreglo:
- el primer paso elige el eje con más recorrido libre;
- si la vía recta se traba, se permite girar como salida de emergencia.

`tangle` es un **sesgo**, no una restricción dura.

### 3.2 Orden de longitudes (híbrido)
La referencia usa una rampa monótona (muy larga → … → media). Medido en nuestro
motor, la rampa pura **empeoraba** los dos objetivos a la vez: pocas flechas
(27) y poca profundidad (4–6).

Solución: **híbrido**.
- **Columna vertebral**: el primer 22% de las flechas son muy largas → crean las
  cadenas de dependencias profundas (la dificultad).
- **Resto (78%)**: medias/cortas → rellenan y dan densidad ("muchas flechas").

### 3.3 No abandonar si la flecha larga no cabe
Si no se encontraba ninguna flecha de la longitud pedida, el bucle de saturación
se rompía y el tablero quedaba ralo. Ahora se reintenta con longitudes
progresivamente menores (100% → 65% → 40% → 25%) antes de rendirse.

### 3.4 Generar-y-elegir-el-mejor
**Este era el bug de fondo.** `_construir` devolvía el **primer** nivel que
pasaba un umbral flojo (profundidad ≥ 3). Resultado: se aceptaban niveles de
23–34 flechas con profundidad 4–5 etiquetados como "difícil".

Ahora se prueban todos los intentos y se conserva el mejor por puntuación real:

```
score = profundidad × 3 + nº_flechas × 0.05 + ratio_bloqueo × 10
```

### 3.5 Rendimiento
| Optimización | Efecto |
|--------------|--------|
| Sesgo por profundidad sin clonar el tablero | Simular el grafo por candidato tardaba minutos |
| Conteo de bloqueadores **incremental** (el corredor de una flecha es fijo) | Quitó el O(n²): 40 s → 4,5 s |
| 80 → 30 búsquedas por colocar | Solo se buscan 6 candidatos |
| 20 → 4 formas por nivel | Multiplicaba el coste total |

---

## 4. Estado medido

Diagnóstico `tools/diag_calidad.gd` (14 semillas por tamaño, tangle 0.9):

| Tamaño | Flechas (media) | Profundidad (media) | Fallos |
|--------|------------------|----------------------|--------|
| 18×N | 31 | 7.3 | — |
| 22×N | 41 | 6.9 | — |
| 26×N | 52 | 8.3 | — |
| 30×N | 66 | 8.3 | — |

- **Fallos totales: 2 de 56 (3.6%)**, antes **33%**.
- Máximo observado: **profundidad 14**, **93 flechas**.
- Los niveles del tutorial (1–5) generan en **20–65 ms** con tangle 0.0.

### Arquitectura de carga

| Niveles | Origen | Tiempo |
|---------|--------|--------|
| 1–5 (tutorial) | Generación en vivo | 20–65 ms |
| 6+ | Pool pre-generado (`src/levels/dificiles.json`) | instantáneo |

Motivo: los tableros grandes tardan demasiado en generarse en vivo, y el nivel se
construye **al jugar** (bloquearía la UI). El pool se genera **offline** en el PC
con `tools/generar_pool.gd`, que tiene presupuesto de tiempo y **guarda tras
cada nivel** (se puede interrumpir sin perder trabajo).

---

## 5. Decisión pendiente: ¿hace falta el solver DFS?

La referencia usa **greedy + DFS**. En nuestro caso **el DFS no aporta nada**, y
es una decisión consciente, no una omisión:

Nuestro juego es **monótono**: `puede_salir` solo pasa de `false` a `true` al
sacar flechas (sacar solo libera celdas, nunca las ocupa). Por tanto, **cualquier
jugada disponible sigue disponible**, y si el greedy no encuentra ninguna jugada
es que **no existe ninguna**: el greedy ya es un solver completo. El DFS solo
sería necesario si añadéramos mecánicas querompan esa monotonía (puntos
desviadores de dirección, flechas con candado de color), que la referencia sí
tiene y nosotros no.

**Conclusión:** verificaciones extra solo tienen sentido si adoptamos esas
mecánicas. En el estado actual, `orden_solucion` basta.

---

## 6. Camino a seguir

### Prioridad 1 — Cerrar lo que ya está a medio hacer
- [ ] Regenerar el pool con el algoritmo nuevo (`tools/generar_pool.gd`) y
      verificar que los niveles 6+ dan profundidad ≥10 y ≥45 flechas.
- [ ] Instalar y **jugar** los niveles: el dato real es si el jugador los
      resuelve con demasiada facilidad.
- [ ] Confirmar en el móvil que el zoom/encuadre funciona con tableros de
      1000+ celdas (ya está el código, falta probarlo en dispositivo).

### Prioridad 2 — Reordenar el flujo de niveles
- [ ] Quitar la suposición de "mundo" que queda en la documentación.
- [ ] Definir el **modo tutorial** de los 5 primeros niveles (la premisa era
      activarlo, no existe).
- [ ] Definir el **pool como finito**: qué pasa al agotarlo (regenerar, ciclar
      o subir a "etapas" con desbloqueos).

### Prioridad 3 — Calidad de la curva de dificultad
- [ ] Medir si `tangle` escalonado da una curva suave o escalones.
- [ ] Subir la dificultad con **mecánicas nuevas** en lugar de solo más tamaño
      (p. ej. flechas que empujan), como planteaba el MVP 3.
- [ ] Ajustar los umbrales de `dificultad()` con datos de juego real (ahora están
      calibrados con la distribución generada, no con cómo lo juega la gente).

### Prioridad 4 — Optimización y tamaño
- [ ] Delta-encoding de rutas para el pool (referencia: 500 niveles en 741 KB).
- [ ] Regeneración del pool: si hay que hacerlo a menudo, lanzarlo en background
      o por lotes.

### Pendientes del MVP original (sin tocar)
- [ ] Sprites y assets de audio (el código existe, los archivos no).
- [ ] Resolver la exportación con keystore de *release*.

---

## 7. Archivos útiles

| Archivo | Para qué |
|---------|----------|
| `tools/generar_pool.gd` | Genera el pool offline (presupuesto de tiempo, guardado incremental) |
| `tools/diag_calidad.gd` | Calidad por semilla (flechas/profundidad/fallos) |
| `tools/diag_tangle.gd` | Efecto del tangle sobre giros y profundidad |
| `tools/diag_tiempo.gd` | Tiempo de generación por nivel |
| `src/core/generador.gd` | Generador (tangle, orden de longitudes, generar-y-elegir) |
| `src/core/grafo_dependencias.gd` | Solver y métricas del grafo de dependencias |

> Los `diag_*.gd` son diagnósticos de desarrollo. Conviene dejarlos fuera del
> APK o limpiarlos antes de cerrar.