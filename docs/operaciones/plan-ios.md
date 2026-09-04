# Plan de la versión iOS de AmalfiGoApp

Documento de arranque para desarrollar la versión iOS. Reemplaza la decisión
**D2** ("Android únicamente. iOS fuera del MVP", Fase 1) ahora que la app
Android está publicada. Escrito para dárselo a una IA (o retomarlo en una
sesión nueva) sin perder contexto.

## 0. Prompt listo para copiar y pegar

```
Vamos a desarrollar la versión iOS de AmalfiGoApp, una app de mototaxi para
Amalfi (Antioquia, Colombia), construida en Expo/React Native + Supabase. Ya
existe una versión Android publicada (o en proceso de publicación) del mismo
código: este es el MISMO proyecto, no uno nuevo. Léete primero
PROJECT_STATUS.md (es la fuente de verdad del proyecto, se actualiza después
de cada paso) y docs/operaciones/plan-ios.md (el análisis de qué falta para
iOS y las fases propuestas).

Reglas de trabajo, no negociables:
- Se avanza por fases, con mi autorización explícita antes de cada una. No
  asumas que puedes seguir a la siguiente fase sin que yo lo confirme.
- Antes de dar algo por hecho, verifícalo contra la realidad (el código, un
  build real, una respuesta real de EAS/App Store Connect) — no supongas.
- Actualiza PROJECT_STATUS.md al cerrar cada paso, seccion propia (nueva,
  numerada tras la Fase 26), igual que se hizo con el resto del proyecto.
- Antes de cada fase, dame un resumen de cinco puntos: objetivo, qué toca
  (archivos/comandos), cómo se verifica, riesgo, y qué necesitas de mí
  (cuentas, decisiones, pagos, cosas que solo yo puedo hacer).
- Si necesitas que yo pruebe algo en un iPhone o en TestFlight, dímelo
  explícitamente y espera mi confirmación antes de continuar.

Empieza por: leer el estado actual del proyecto, confirmar conmigo que el
diagnóstico de docs/operaciones/plan-ios.md sigue siendo correcto (el código
puede haber cambiado desde que se escribió), y proponerme las fases con el
formato de cinco puntos antes de tocar nada.
```

## 1. Contexto

El proyecto es un único código Expo/React Native (`AmalfiGoApp`, antes
`MotoMoto`) con panel administrativo en Next.js aparte (`admin/`) y backend en
Supabase. La Fase 26 (publicación en Google Play) está en curso: paquete
`co.amalfigo.app`, build de producción listo, bloqueado por la verificación de
identidad de Google y el texto legal del abogado.

Este documento cubre **solo la parte iOS**. No repite lo ya resuelto para
Android (backend, RLS, lógica de negocio, panel) porque es exactamente lo
mismo: Supabase no distingue plataforma.

## 2. Qué se reutiliza tal cual

La cifra real es "casi todo". Revisado el código el 2026-09-05:

- **Todo `src/`** (pantallas, hooks, lógica de negocio, Zod, Supabase,
  `react-hook-form`) — cero cambios. Es JavaScript/TypeScript puro sobre
  componentes de React Native, no hay una sola pantalla escrita contra la API
  nativa de Android.
- **El mapa.** `@rnmapbox/maps` (Mapbox), no `react-native-maps`/Google Maps
  -esa dependencia se quitó del proyecto el 2026-09-04 por no usarse-.
  Mapbox soporta iOS igual que Android, mismo componente, mismo código.
- **Todas las dependencias nativas son Expo puras** (`expo-location`,
  `expo-notifications`, `expo-image-picker`, `expo-splash-screen`,
  `expo-file-system`, etc.), sin nada exclusivo de Android en `package.json`.
- **El código YA tiene las pocas ramas por plataforma que necesitaba,**
  correctas: `KeyboardAvoidingView` en
  [`screen.tsx`](../../src/components/ui/screen.tsx) usa `behavior="padding"`
  en iOS (patrón estándar de RN); la creación de canal de notificación en
  [`use-push-registration.ts`](../../src/features/notifications/use-push-registration.ts)
  se salta en iOS porque ahí no existen los canales de Android. No hay que
  escribir nada nuevo para esto, ya está.
- **Backend, RLS, Edge functions, panel administrativo** — sin cambios, no
  aplica el concepto de plataforma.
- **Eliminación de cuenta** (Fase 26, paso 7b) — Apple exige lo mismo que
  Google (Guideline 5.1.1(v)): borrar la cuenta desde dentro de la app. Ya
  está construido y verificado (`delete_my_account`, botón en
  `passenger/profile`, página web). Cero trabajo nuevo.
- **Sign in with Apple: no hace falta.** Apple solo lo exige cuando la app
  ofrece login social de terceros (Google, Facebook...) como alternativa; acá
  el único método es correo/contraseña.

## 3. Qué falta

| Elemento | Estado hoy | Equivalente en Android |
|---|---|---|
| Cuenta de Apple Developer Program | No existe | Play Console (pero cuesta USD 99/año, no un pago único) |
| `ios.bundleIdentifier` en `app.config.ts` | Solo hay `ios.icon`, sin identificador | `android.package` |
| Ícono real para iOS | `assets/expo.icon` es el placeholder de la plantilla de Expo (el símbolo genérico), nunca se tocó | `assets/images/android-icon-*.png`, generados por `assets/brand/generate.mjs` desde `logo.svg` |
| Universal Links (abrir `amalfigo.app/auth` directo en la app) | No existe `site/.well-known/apple-app-site-association` ni `associatedDomains` en `app.config.ts` | `assetlinks.json` + `intentFilters` (ya resuelto) |
| Push notifications | Sin clave APNs subida a EAS | Clave FCM V1 (ya subida) — es una credencial nueva, no reutiliza nada de Firebase; Expo Push habla directo con Apple |
| Perfiles iOS en `eas.json` | No existen (`development`/`preview`/`production` solo llevan bloque `android`) | Ya existen para Android |
| Ficha de App Store Connect | No existe | `docs/operaciones/ficha-play-store.md` sirve de base (mismo texto, descripción, categoría), pero el formato de Apple es distinto: capturas por tamaño de pantalla (6.9″, 6.5″, 5.5″), "App Privacy" en vez de Data Safety, clasificación de edad propia |
| Cuenta de demostración para la revisión | No existe | Google no la pidió; Apple casi siempre sí (usuario/contraseña de una cuenta QA en el formulario de envío) |

## 4. Lo que NO hace falta rehacer

- Nada de arquitectura ni de modelo de datos.
- Ninguna pantalla se reescribe.
- No hace falta un Mac para el build en sí -EAS Build compila en la nube-,
  solo para depurar nativo en el simulador si algún día hiciera falta
  (`expo run:ios`). Probar el resultado sí requiere un iPhone real (vía
  TestFlight) o el simulador de Xcode en un Mac.

## 5. Fases propuestas

Mismo protocolo que la Fase 26 (Android): un paso a la vez, con autorización
explícita y verificación real antes de seguir.

1. **Cuenta de Apple Developer Program** (USD 99/año) + registrar el bundle
   id (`co.amalfigo.app`, para que coincida con el de Android, aunque Apple
   no lo exige).
2. **EAS para iOS**: perfiles en `eas.json` (`development`/`preview`/
   `production`), credenciales gestionadas por EAS (certificado y
   provisioning profile los genera EAS solo, no hay que tocarlos a mano),
   clave APNs subida (`eas credentials -p ios`).
3. **Ícono real**: extender `assets/brand/generate.mjs` para sacar el
   formato que se decida (un PNG plano de 1024, sin transparencia, es lo
   simple; el `.icon` de Icon Composer para el efecto "Liquid Glass" de
   iOS 26 es opcional y más trabajo -el proyecto ya trae `expo-glass-effect`
   instalado sin usar, así que en algún momento se pensó en esto-).
4. **Universal Links**: `associatedDomains: ['applinks:amalfigo.app']` en
   `app.config.ts` + publicar `apple-app-site-association` en
   `site/.well-known/` (JSON sin extensión, con el Team ID de Apple).
5. **Primer build** (perfil `preview`) y prueba en un iPhone real vía
   TestFlight -o en el simulador si hay Mac a mano-.
6. **Ficha de App Store Connect**, adaptando `ficha-play-store.md`: capturas
   nuevas (proporción de iPhone, no de Android), texto de App Privacy,
   clasificación de edad, cuenta de demostración para el revisor.
7. **Envío a revisión.**

## 6. Riesgos y particularidades de Apple

- **Revisión humana más exigente con apps de transporte.** Apple pide a
  veces evidencia de que el servicio es real (capturas del flujo completo,
  a veces la cuenta de demostración debe poder completar un viaje de punta a
  punta). Dejar lista una cuenta de pasajero Y una de conductor con datos
  reales en el formulario de envío.
- **Tiempos.** La aprobación de la cuenta de Apple Developer puede tardar
  24–48 h y a veces pide verificación de identidad, como está pasando ahora
  con Google. La revisión de la app en sí suele ser más rápida que Google
  (24–48 h típico), pero puede rebotar por motivos de contenido/negocio, no
  solo técnicos.
- **No hay equivalente obligatorio a la prueba cerrada de 12 testers/14 días
  de Play** (eso era una condición de las cuentas *personales* de Google).
  Apple usa TestFlight, que es más simple, pero conviene pasar por ahí antes
  de enviar a revisión pública de todas formas.
- **El pago es recurrente** (USD 99/año, contra el pago único de USD 25 de la
  cuenta personal de Play), a tener en cuenta en el costo de mantener las dos
  tiendas.

## 7. Referencia técnica rápida

- Stack: Expo SDK 57, React Native 0.86, TypeScript, Supabase, Mapbox
  (`@rnmapbox/maps`), EAS Build/Submit.
- Archivos que se van a tocar en este trabajo: `app.config.ts`, `eas.json`,
  `assets/brand/generate.mjs`, `site/build.mjs`, `site/.well-known/`.
- `PROJECT_STATUS.md` es la fuente de verdad del proyecto entero y se
  actualiza al cerrar cada paso, con el mismo estilo narrativo que las fases
  anteriores (qué se hizo, qué se verificó, qué se le pidió al usuario).
