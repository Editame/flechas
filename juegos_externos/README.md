# Juegos externos

Aquí van los juegos que **no** son Godot (Unity, web, nativo, etc.). La carpeta
tiene un `.gdignore` para que el proyecto Godot no la escanee.

Cada juego se publica como **app independiente** (o web) y el hub lo enlaza
desde `src/games/catalogo.json`:

```json
{
  "id": "mi-juego",
  "titulo": "Mi juego",
  "descripcion": "Lo que sea",
  "tipo": "externo",
  "paquete": "com.editame.mijuego"
}
```

o con una URL:

```json
{
  "id": "mi-juego-web",
  "titulo": "Mi juego web",
  "tipo": "externo",
  "url": "https://juegos.editame.dev/mi-juego"
}
```

El hub abre la ficha de Play (si hay `paquete`) o la URL. No se bundlea nada de
esta carpeta en la app. Si algún día queremos integrarlo dentro del hub, se
puede hacer con un WebView o con un puente nativo, pero no es necesario para
empezar.
