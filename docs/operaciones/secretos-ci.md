<!--
  Runbook de los secretos del CI. Fase 25 paso 9.
  No lo lee ninguna herramienta: es para la persona que administra el repositorio.
-->

# Secretos del CI

El flujo de CI (`.github/workflows/ci.yml`) tiene tres trabajos:

| Trabajo        | Qué comprueba                                                             | ¿Necesita secretos?            |
| -------------- | ------------------------------------------------------------------------- | ------------------------------ |
| `movil`        | `lint`, `typecheck`, `format:check`, `test` (Jest) del cliente Expo       | **No**                         |
| `panel`        | `lint`, `typecheck`, `format:check`, `build` del panel Next.js (`admin/`) | No (usa marcadores si faltan)  |
| `regresion-bd` | Los `prueba_*.sql` y `.mjs` contra la base (`npm run test:db`)            | Sí, y **por defecto se omite** |

Los dos primeros son los que aportan y **no necesitan nada**: cualquier `push` ya
los ejecuta.

## Decisión: `regresion-bd` se deja omitiéndose

`regresion-bd` corre la regresión de base de datos contra el proyecto
`bosodjcehvqmmegxdmlu`, que **es el de producción** (mismo proyecto, Fase 25
paso 9). Los `prueba_*.sql` crean y borran datos de prueba —aislados por prefijo
e idempotentes, pero aun así escritura real— en cada corrida.

No merece la pena correr eso contra producción en cada `push`. El trabajo ya está
escrito para **omitirse solo** si no encuentra el secreto `SUPABASE_ACCESS_TOKEN`:
pasa en verde con un aviso en el resumen, sin bloquear el CI.

**Recomendación: no configurar los secretos de `regresion-bd`.** La regresión de
base de datos se corre a mano cuando haga falta:

```bash
npm run test:db
```

Si en algún momento se quiere en CI, la vía correcta es un **proyecto Supabase
aparte solo para pruebas** (no el de producción) y apuntar ahí el `--project-ref`
del trabajo.

## Los secretos, si algún día se configuran

Se añaden en GitHub: **Settings → Secrets and variables → Actions → New
repository secret**.

| Secreto                                | Qué es                                                                                                                                           | De dónde sale                                                                           |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| `SUPABASE_ACCESS_TOKEN`                | Token de acceso personal de Supabase. Permite `supabase link` y la CLI. **Es sensible**: da acceso a la cuenta.                                  | supabase.com → cuenta → **Access Tokens** → Generate new token. Nómbralo `ci-motomoto`. |
| `SUPABASE_DB_PASSWORD`                 | Contraseña de la base del proyecto.                                                                                                              | Panel del proyecto → **Settings → Database → Database password** (o resetéala ahí).     |
| `EXPO_PUBLIC_SUPABASE_URL`             | URL del proyecto (`https://bosodjcehvqmmegxdmlu.supabase.co`). **No es secreta** —viaja en la app— pero el flujo la lee de aquí por uniformidad. | Panel → Settings → API, o el `.env` local.                                              |
| `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Clave publicable (`sb_publishable_…`). **No es secreta** —viaja en la app—.                                                                      | Panel → Settings → API → Publishable key, o el `.env` local.                            |

`ci.yml` referencia también `EXPO_PUBLIC_SUPABASE_URL` y
`EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` en el trabajo `panel` (para la
compilación), con un marcador si no están. El panel compila igual sin ellos; los
valores solo importan en ejecución, no al construir.

## Rotación

- `SUPABASE_ACCESS_TOKEN`: revócalo en supabase.com → Access Tokens si se filtra
  o si deja de usarse. Genera uno nuevo y actualiza el secreto.
- `SUPABASE_DB_PASSWORD`: se resetea desde el panel del proyecto. Al hacerlo hay
  que actualizar también el `.env` local de quien tenga el proyecto enlazado.
- Las dos claves `EXPO_PUBLIC_*` cambian solo si se rota la API del proyecto
  (Settings → API), cosa que además obliga a recompilar la app.

## Qué NO va en secretos del CI

- El **token de descarga de Mapbox** (`sk.…`) y la **clave de Google Maps**: solo
  hacen falta para compilar la app nativa, que no ocurre en este CI (se hará con
  EAS o en local, Fase 26).
- `google-services.json` y la clave de servicio de FCM: igual, compilación
  nativa.
- La clave `service_role` de Supabase: **no se usa en ningún sitio del proyecto**
  (todo va por funciones `security definer` acotadas, D250/D264). No debe existir
  como secreto.
