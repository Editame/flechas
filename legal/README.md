# Legal · Patio de Juegos

Páginas listas para publicar en `editame.dev`:

- `privacidad.html` → `https://editame.dev/juegos/privacidad/`
- `terminos.html` → `https://editame.dev/juegos/terminos/`

En Cloudflare Pages/Workers, subir los dos archivos dentro de `juegos/` y
renombrarlos a `index.html` en carpetas separadas, o configurar las rutas para
que sirvan el HTML con esos nombres.

Si se publican en otra ruta, actualizar:

- `src/ui/ajustes.gd` (botones de privacidad y términos)
- Play Console → Contenido de la app → Política de privacidad
- Play Console → Ficha de Play Store (si se añade el enlace al sitio)

Contacto público usado: `soporte@editame.dev`.
