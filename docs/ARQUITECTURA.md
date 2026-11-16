# Arquitectura de Editame Juegos

La app es un **hub** de juegos pequeños. El objetivo es que cada juego pueda
crecer (o desaparecer) sin arrastrar a los demás, y que un juego que no sea
Godot pueda vivir como app aparte sin romper el hub.

## Estructura

```
src/
  shared/            Código genérico de la app (no de un juego concreto)
    config.gd        Preferencias (idioma, tema, sonido, intro)
    sesion.gd        Estado entre escenas (juego/nivel actual)
    audio.gd         Sonido y vibración
    api_client.gd    API opcional (packs, sugerencias)
    tema.gd          4 temas visuales y estilos
    i18n.gd          Textos ES/EN
    version.gd       Versión visible
    features.gd      Banderas (servidor, etc.)
  ui/
    arranque.tscn    Decide intro (primera vez) o hub
    intro.tscn       Historia de Editame + sugerencias
    hub.tscn         Tarjetas de juegos (lee src/games/catalogo.json)
    ajustes.tscn     Ajustes globales, historia, legal, servidor (flag)
    tema_ui.tres     Tema base de Godot
  games/
    catalogo.json    Lista de juegos del hub
    flechas/
      menu.tscn      Menú del juego (diario, niveles, jugar)
      juego.tscn     Partida
      diario.tscn    Calendario del desafío
      pack.gd        Carga de los ZIP offline
      progreso.gd    Progreso de Flechas (nivel, estrellas, diario)
      core/          Reglas y generador (Tablero, Flecha, ...)
assets/
  fonts/             Poppins + Great Vibes (marca)
  iconos/            Iconos de UI
  packs/flechas/     Niveles pregenerados (ZIP)
docs/
  ARQUITECTURA.md
```

El **servidor** vive en otro repo (`flechas-servidor`): genera los packs, sirve
el formulario de sugerencias y (opcionalmente) manda correos. **El juego no
depende del servidor**: los niveles van en los packs offline.

## Catálogo de juegos

`src/games/catalogo.json` es la única lista que lee el hub:

```json
{
  "id": "flechas",
  "titulo": "Flechas",
  "descripcion": "Despeja el tablero...",
  "tipo": "godot",
  "estado": "listo",
  "escena": "res://src/games/flechas/menu.tscn",
  "fondo": "#241a3d", "acento": "#ffb703",
  "texto": "#fff4e6", "suave": "#c9b8e8"
}
```

Tipos:
- `godot`: se abre `escena` dentro del hub.
- `externo`: se abre `url` (o la ficha de Play usando `paquete`). Sirve para
  juegos que no son Godot o que se publican como app aparte.
- `pronto`: tarjeta de “Próximamente”, sin acción.

Para añadir un juego Godot: crear `src/games/<id>/` con su escena y assets,
añadir la entrada al catálogo y, si necesita niveles, un pack propio.

Para un juego que no sea Godot: crear `juegos_externos/<id>/` con un
`.gdignore` (para que Godot no lo escanee), publicarlo como app independiente y
poner su `paquete`/`url` en el catálogo. El hub lo abre; no se bundlea.

## Niveles offline (Flechas)

- `tools/generar_packs.py` (repo del servidor) genera:
  - `flechas_clasico.zip`: 1.000 niveles secuenciales (~4 MB).
  - `flechas_diario.zip`: 730 fechas 2026–2027 (~1,2 MB).
- Cada ZIP tiene `index.json` + un JSON compacto por nivel.
- `PackFlechas` abre los ZIP al arrancar y sirve el nivel por número/fecha.
- Si el pack no existe, el juego cae a la API (solo desarrollo).
- El export incluye `assets/packs/*.zip` y `src/games/catalogo.json`.

## Historia y sugerencias

- `arranque.tscn` muestra la historia la primera vez (`intro_vista` en Config).
- “Nuestra historia” en Ajustes la vuelve a abrir.
- La **caja de sugerencias** abre `static/sugerencias.html` del servidor:
  idea + referencia + imagen opcional. El servidor la guarda y la manda por
  correo si están configuradas las variables SMTP.

## Reglas de convivencia

- `shared/` no conoce ningún juego concreto.
- `ui/` es el chrome de la app (hub, ajustes, historia).
- `games/<id>/` solo depende de `shared/`; si se quita del catálogo, el resto
  de la app sigue funcionando.
- Un juego no Godot **no** se mete a la fuerza en este proyecto: se publica
  aparte y el hub lo enlaza.
