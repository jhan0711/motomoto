# Actualizar la app: del arreglo a Google Play

Qué hacer cada vez que se corrige o cambia algo. La regla de oro: **no todo
cambio necesita un build nuevo ni pasar por Play.**

## 1. ¿Qué tipo de cambio es?

| Cambio                                                                            | Qué se hace                          | ¿Build nuevo? | ¿Play?                 |
| --------------------------------------------------------------------------------- | ------------------------------------ | ------------- | ---------------------- |
| **Código de la app** (`src/`, `app.config.ts`, `eas.json`, dependencias)          | Commit → build → subir a Play        | **Sí**        | **Sí**                 |
| **Parámetro de operación** (`offer_response_seconds`, tarifas, máx. pasajeros...) | SQL o panel administrativo (Tarifas) | No            | No                     |
| **Migración de Supabase / backend** (sin tocar `src/`)                            | `supabase db push --linked`          | No            | No                     |
| **Textos o gráficos de la ficha** (descripción, capturas, icono)                  | Editar en Play Console → guardar     | No            | Sí, pero solo la ficha |
| **Textos legales del sitio** (`docs/legal/`, `site/`)                             | `git push` → Cloudflare redespliega  | No            | No                     |
| **Panel administrativo** (`admin/`)                                               | `git push` → Vercel redespliega      | No            | No                     |

## 2. Cambio de código: el flujo completo

### a) Commit y APK de pruebas local

```
# tras el cambio, siempre:
npx tsc --noEmit && npx eslint <archivos> && npx prettier --check <archivos> && npx jest
git add -A && git commit -m "..."
```

Actualizar el APK de pruebas de la raíz (para probar en la tablet por adb, va
firmado con la clave de depuración, que está en `assetlinks.json`):

```
cd android
./gradlew.bat assembleRelease -PreactNativeArchitectures=arm64-v8a
cp app/build/outputs/apk/release/app-release.apk ../AmalfiGoApp.apk
```

Instalar: `adb install -r AmalfiGoApp.apk`. En la tablet Xiaomi, "Instalar vía
USB" (Opciones de desarrollador) tiene que estar activo y a veces pide
confirmar en pantalla. El emulador **no sirve**: el APK es solo arm64 y el
código nativo de la New Architecture crashea bajo traducción ARM en x86_64.

### b) Build de producción con EAS (cuando el cambio va a Play)

```
npx eas-cli build --platform android --profile production --non-interactive --no-wait
```

- El **versionCode sube solo** (EAS lo lleva en remoto, `appVersionSource:
"remote"` en `eas.json`). El `versionName` ("1.0.0") sale de `version` en
  `app.config.ts`; se sube a mano solo si se quiere (p. ej. 1.0.1).
- Las variables de entorno del build ya están en EAS (`eas env:list production`).
  `GOOGLE_SERVICES_JSON` es una variable tipo `file`.
- Tarda ~15-20 min. Al terminar: `npx eas-cli build:list --platform android
--limit 1` da la URL del `.aab`. Descargarlo:
  `curl -sL <url> -o AmalfiGoApp-produccion.aab` (está en `.gitignore`).

### c) Subir a Play Console

1. **Prueba y lanza** → la pista activa: **Prueba interna** (hoy), luego
   **Prueba cerrada**, luego **Producción**.
2. Pestaña **Versiones** → **Crear versión**.
3. **Subir** el `.aab`. El nombre de la versión se autocompleta (`5 (1.0.0)`).
4. **Notas de la versión**, entre las etiquetas `<es-419>...</es-419>`: una
   frase de qué cambió, para los testers.
5. **Guardar y publicar** (interna) o **Guardar y enviar a revisión** (cerrada/
   producción).

### d) Tiempos y revisión

| Pista              | Revisión de Google                       | Cuándo está disponible  |
| ------------------ | ---------------------------------------- | ----------------------- |
| **Prueba interna** | No (o mínima automática)                 | Minutos                 |
| **Prueba cerrada** | Sí                                       | Horas a 1-2 días        |
| **Producción**     | Sí + más estricta con apps de transporte | 1-3 días, puede rebotar |

**Cuenta personal:** antes de producción hay que completar una **prueba
cerrada con ≥ 12 testers durante ≥ 14 días** y solicitar acceso a producción.

## 3. Cosas que NO cambian con cada build

- **`assetlinks.json`**: solo si cambia una clave de firma. Hoy tiene las tres
  que hacen falta (depuración, subida de EAS, Play App Signing). La de Play App
  Signing es permanente.
- **Credenciales de EAS** (keystore, clave FCM V1): permanentes.
- **La ficha de Play, la clasificación, Data Safety**: solo se re-tocan si
  cambia lo que declaran (p. ej. si la app empieza a recoger un dato nuevo, hay
  que actualizar Data Safety **antes** de publicar ese build).

## 4. Instalar en un dispositivo la versión de Play (no la local)

Si en la tablet está la local (firma de depuración) y se quiere la de Play:
**desinstalar** la local primero (firmas distintas, no se puede "actualizar"
encima), y luego instalar desde el enlace de prueba interna
(`play.google.com/apps/internaltest/...`). La instalación desde Play **no**
tiene la restricción de "Instalar vía USB" de Xiaomi.
