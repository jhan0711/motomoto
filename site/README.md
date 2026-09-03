# Sitio de AmalfiGoApp — `amalfigo.app` (dominio por comprar)

Sitio estático mínimo. Sirve tres cosas y nada más:

1. `/.well-known/assetlinks.json` — para que Android abra la app con los enlaces
   `https://amalfigo.app/...` en vez del navegador (App Links).
   - Hoy lleva la huella SHA-256 de la **clave de depuración** (`android/app/debug.keystore`),
     para poder probar los App Links en un build de desarrollo.
   - **Antes de publicar hay que AÑADIR** (no reemplazar) la huella de la clave de
     firma de producción. Con Play App Signing, esa huella la da Play Console en
     _Configuración → Firma de la app_. El array admite varias.
2. `/privacidad` y `/terminos` — los textos legales.
3. `/` — una página de presentación breve.

## Cómo se genera

```
node site/build.mjs
```

Lee los borradores de `docs/legal/*.md`, los envuelve en la plantilla HTML y
escribe `site/dist/`. **Ojo:** mientras `docs/legal/` sean borradores con marcas
`[REVISAR]`, el HTML también lo es y NO debe publicarse.

## Cómo se despliega (cuando esté el dominio)

Recomendado: **Cloudflare Pages** (gratis).

1. Comprar el dominio en Cloudflare Registrar (precio de costo, DNS y SSL
   incluidos).
2. Crear un proyecto de Pages apuntando a este repositorio, con:
   - Comando de build: `node site/build.mjs`
   - Carpeta de salida: `site/dist`
3. Conectar el dominio al proyecto de Pages.
4. Verificar que `https://amalfigo.app/.well-known/assetlinks.json` responde con
   `Content-Type: application/json` y sin redirección.

Alternativas equivalentes: Netlify, Vercel, GitHub Pages.
