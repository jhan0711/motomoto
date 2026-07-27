# MotoMoto

Plataforma movil para solicitar servicios de transporte en motorratones, vehiculos de tres
ruedas tipo tuk-tuk con capacidad para hasta tres pasajeros.

Prueba piloto en el municipio de Amalfi, Antioquia, Colombia.

> **Nombre provisional.** El nombre comercial definitivo esta pendiente de decision.

La plataforma **no procesa pagos** y **no calcula tarifas**. El pago se acuerda y se realiza
fuera de la aplicacion. La arquitectura permite incorporar pagos mas adelante sin
reconstruir el sistema.

---

## Estado del proyecto

El estado detallado, las decisiones tomadas y el plan por fases estan en
[PROJECT_STATUS.md](./PROJECT_STATUS.md). **Ese archivo es la fuente de verdad del
proyecto**: si retomas el trabajo tras una pausa, empieza por ahi.

| Fase                                    | Estado     |
| --------------------------------------- | ---------- |
| 0. Definicion funcional                 | Completada |
| 1. Preparacion del equipo               | Completada |
| 2. Creacion y organizacion del proyecto | En curso   |
| 3 a 26                                  | Pendientes |

---

## Stack

| Capa                    | Tecnologia                                           |
| ----------------------- | ---------------------------------------------------- |
| Aplicacion movil        | React Native 0.86 sobre Expo SDK 57                  |
| Lenguaje                | TypeScript 6 en modo estricto                        |
| Navegacion              | expo-router, enrutado por archivos con rutas tipadas |
| Backend y base de datos | Supabase (PostgreSQL, Auth, Realtime) — Fase 5       |
| Panel administrativo    | Next.js — Fase 20                                    |
| Mapas                   | Por decidir entre Google Maps y Mapbox — Fase 8      |

Plataforma objetivo del MVP: **Android**. iOS queda fuera del alcance inicial.

---

## Requisitos

- Node.js 20.19.4 o superior. Desarrollado con v24.15.0
- JDK 17. Versiones superiores **no** son compatibles con la compilacion de Android
- Android Studio con el SDK Platform 36 y una imagen de emulador x86_64
- Un dispositivo Android fisico o un emulador en funcionamiento

La instalacion completa del entorno esta documentada en la seccion 15 de
[PROJECT_STATUS.md](./PROJECT_STATUS.md).

---

## Aviso para desarrollo en Windows

La politica de ejecucion de scripts de PowerShell impide invocar `npm` y `npx` directamente.
**Usa siempre el sufijo `.cmd`**:

```powershell
npm.cmd install
npx.cmd expo start
```

Sin el sufijo obtendras un error `PSSecurityException`. En CMD o en otros sistemas
operativos no es necesario.

---

## Puesta en marcha

```powershell
npm.cmd install
```

```powershell
copy .env.example .env
```

Rellena los valores en `.env`. Consulta ese archivo: documenta cada variable y explica
por que la clave `service_role` de Supabase nunca debe aparecer ahi.

```powershell
npx.cmd expo start
```

Con el servidor arrancado, pulsa `a` para abrir la aplicacion en el emulador Android.

---

## Comandos disponibles

| Comando                    | Que hace                                              |
| -------------------------- | ----------------------------------------------------- |
| `npm.cmd start`            | Arranca el servidor de desarrollo                     |
| `npm.cmd run android`      | Arranca y abre directamente en Android                |
| `npm.cmd run typecheck`    | Verifica los tipos de todo el proyecto sin ejecutarlo |
| `npm.cmd run lint`         | Analiza el codigo en busca de malas practicas         |
| `npm.cmd run format`       | Formatea todo el proyecto con Prettier                |
| `npm.cmd run format:check` | Comprueba el formato sin modificar archivos           |

**Antes de cada commit**, ejecuta `typecheck`, `lint` y `format:check`. Los tres deben
terminar sin errores.

---

## Estructura de carpetas

```
src/
  app/          Solo rutas y layouts de expo-router. Sin logica de negocio
  components/   Componentes genericos, reutilizables en cualquier pantalla
    ui/         Primitivas del sistema de diseno: Button, Input, Card, BottomSheet
  features/     Codigo agrupado por dominio del negocio
    auth/
    rides/
    drivers/
    profile/
  lib/          Clientes de servicios externos: supabase, mapas, notificaciones
  theme/        Tokens de diseno: colores, tipografia, espaciados, radios, sombras
  hooks/        Hooks reutilizables no ligados a un dominio concreto
  types/        Tipos compartidos y tipos generados desde la base de datos
  utils/        Funciones puras: formateo de fechas, calculo de distancias
```

### Tres reglas que sostienen la estructura

**1. En `src/app/` solo van rutas.** Con expo-router, cada archivo dentro de `app/` se
convierte en una URL navegable. Un `helpers.ts` guardado ahi crea una pantalla fantasma en
`/helpers`, sin ningun aviso. Todo lo que no sea pantalla o layout vive fuera.

**2. `features/` agrupa por dominio, no por tipo de archivo.** Si algo lo usan dos o mas
features, sube a `src/components/` o `src/hooks/`. Si lo usa una sola, se queda dentro de
su feature.

**3. Las carpetas se crean cuando hacen falta.** Git no versiona directorios vacios y un
esqueleto sin contenido solo es ruido.

---

## Carpeta `example/`

Contiene la aplicacion de demostracion que traia la plantilla de Expo, apartada con el
script oficial `reset-project`. Se conserva como referencia hasta terminar la Fase 3 y
esta excluida de Git, de TypeScript, de ESLint y de Prettier.

Puede borrarse sin consecuencias.

---

## Variables de entorno

Toda variable con prefijo `EXPO_PUBLIC_` **queda incrustada en el paquete de la
aplicacion** y es extraible por cualquiera que descargue el APK. No es un fallo, es el
comportamiento documentado de Expo.

Por eso:

- La clave anonima de Supabase si va ahi. Es publica por diseno y su unica proteccion son
  las politicas de Row Level Security. **Las politicas RLS no son opcionales en este
  proyecto.**
- La clave `service_role` no va ahi bajo ninguna circunstancia. Ignora todas las politicas
  RLS y solo puede vivir en un servidor.

Consulta [.env.example](./.env.example) para el detalle de cada variable.

---

## Convenciones

- Codigo, comentarios y nombres de variables en ingles. Textos de interfaz en espanol
- **Prohibido el uso de emojis en la interfaz.** Toda representacion visual mediante iconos
  de la libreria elegida
- Mensajes de commit en ingles con prefijo de tipo: `feat:`, `fix:`, `refactor:`, `docs:`,
  `chore:`, `test:`
- No se ejecuta `npm audit fix` en este proyecto. Rompe las versiones fijadas por Expo. La
  herramienta correcta es `npx.cmd expo install --check`
