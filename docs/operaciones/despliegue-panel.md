<!--
  Runbook para desplegar el panel administrativo (admin/). Fase 26 paso 6.
  No lo lee ninguna herramienta: es para la persona que administra el proyecto.
-->

# Despliegue del panel administrativo

El panel (`admin/`) es una app **Next.js** con renderizado en servidor
(middleware de sesión + páginas dinámicas), así que necesita un runtime de Node.
Se despliega en **Vercel** (nivel gratis, soporte nativo de Next.js).

Repositorio: `github.com/jhan0711/motomoto`. El panel vive en la subcarpeta
`admin/`, con su propio `package-lock.json`.

## Variables de entorno

Solo dos, y **ninguna es secreta** (la clave publicable viaja también en la app
móvil; quien protege los datos es la RLS y las funciones `security definer`, no
esta cadena):

| Variable                               | Valor                                                                                         |
| -------------------------------------- | --------------------------------------------------------------------------------------------- |
| `NEXT_PUBLIC_SUPABASE_URL`             | `https://bosodjcehvqmmegxdmlu.supabase.co`                                                    |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | La `sb_publishable_…` del proyecto (misma que el `.env` de la app móvil / `admin/.env.local`) |

## Pasos

1. **vercel.com** → inicia sesión **con GitHub** (cuenta `jhan0711`).
2. **Add New → Project** → importa el repo **`jhan0711/motomoto`**.
3. **Root Directory: `admin`** ← imprescindible. La raíz del repo es la app
   móvil; sin esto Vercel intenta compilar Expo y falla.
4. Framework Preset: **Next.js** (lo detecta solo). Build/install por defecto.
5. **Environment Variables:** añade las dos de la tabla de arriba (para
   Production, Preview y Development).
6. **Deploy.** Sale una URL `motomoto-xxx.vercel.app`.
7. Prueba: abre esa URL → `/acceso` → inicia sesión con el super admin
   (`jhank.45617@gmail.com`) → debe cargar el panel y la lista de servicios.

## Dominio propio: `panel.amalfigo.app`

1. En Vercel: **Project → Settings → Domains** → añade `panel.amalfigo.app`.
   Vercel muestra un destino CNAME (algo como `cname.vercel-dns.com`).
2. En **Cloudflare** (DNS de `amalfigo.app`): añade un registro **CNAME**
   `panel` → el destino que dio Vercel. Puede quedar en **Proxied** (naranja) o
   **DNS only**; las dos funcionan.
3. Vercel emite el certificado TLS solo en unos minutos.

## Después

- **Auto-deploy:** cada `push` a `main` redespliega el panel (comportamiento por
  defecto de Vercel). Los cambios que no tocan `admin/` también disparan un
  build; es rápido y no molesta.
- El panel y la app móvil comparten el proyecto de Supabase de **producción**.
  No hay backend propio del panel: habla directo con Supabase por RLS.
- Si algún día el panel necesita un secreto de verdad (no `NEXT_PUBLIC_`), va en
  las Environment Variables de Vercel, nunca en el repo.

## Estado

**Desplegado el 2026-09-03.** Proyecto Vercel `motomoto` (cuenta Hobby), en vivo
en `https://panel.amalfigo.app`. Dos cosas que costaron y quedan anotadas para la
próxima:

- **Root Directory** hay que fijarlo en `admin` en Settings → General; si se
  queda en `./`, Vercel compila la app Expo de la raíz y falla.
- Las dos env vars van como tipo **Config**, no Secret, y con el valor **exacto**
  (sin el prefijo `EXPO_PUBLIC_...=`, sin espacios). Con ellas mal, el login da
  "correo o contraseña incorrectos" aunque la clave sea buena.
- El panel **no tiene "recuperar contraseña"**: un admin que la olvide la
  recupera desde la app móvil o el panel de Supabase.
