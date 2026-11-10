# iOS: guía de lanzamiento (desde que se paga la cuenta de Apple)

Complementa a `plan-ios.md` (el análisis) y a `ficha-app-store.md` (los textos).
Aquí solo está **el orden de los pasos y quién hace cada uno**, para tardar lo
menos posible. Escrito el 2026-11-10.

**Quién hace qué.** Todo lo que pide el usuario y la contraseña de Apple (o el
código de verificación) lo hace Jhan en su propia terminal: nadie más escribe esas
credenciales. Lo demás lo hace Claude.

## Ya está listo (verificado)

- Código y configuración: `bundleIdentifier co.amalfigo.app`, solo iPhone,
  ubicación en segundo plano, ícono sin alfa, navegación con Apple Maps (D285).
- Ficha de App Store, privacidad, edad, notas para el revisor y video (D286, D289).
- Política de privacidad y términos de uso aprobados y publicados (D288, D291).
- EAS: sesión iniciada como `jhan160711` y el token de descarga de Mapbox
  (`RNMAPBOX_MAPS_DOWNLOAD_TOKEN`) ya está cargado en los entornos `production` y
  `preview`. El iOS lo necesita igual que el Android.
- Los correos de la cuenta (confirmar, recuperar contraseña) **funcionan en iOS
  sin Universal Links**: `amalfigo.app/auth` abre `motomoto://auth`, que iOS
  entrega a la app. Los Universal Links solo quitan el aviso "¿abrir en la app?",
  así que NO bloquean el primer envío.
- La rama `deps/expo-57-parche` sube Expo a 57.0.32 y corrige una regresión de
  memoria de Hermes que `expo-doctor` marcaba (D291). **Conviene fundirla antes
  del primer build de iOS**, para que las dos plataformas salgan con lo mismo.

## Pasos

| #   | Quién  | Qué                                                                                                                                                                                                                                               | Tiempo                    |
| --- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| 1   | Jhan   | Pagar y completar el alta en https://developer.apple.com/programs/enroll/ (**cuenta individual**). Apple puede pedir verificar identidad.                                                                                                         | 24-48 h, a veces más      |
| 2   | Jhan   | En developer.apple.com → Certificates, Identifiers & Profiles → Identifiers: registrar el App ID `co.amalfigo.app` (EAS también puede hacerlo solo en el paso 4).                                                                                 | 5 min                     |
| 3   | Jhan   | En appstoreconnect.apple.com → Apps → "+" → Nueva app: nombre `AmalfiGoApp`, idioma Español (México), bundle id `co.amalfigo.app`, SKU `amalfigoapp`. Apunta el **Apple ID de la app** (un número) que sale en Información de la app.             | 5 min                     |
| 4   | Jhan   | En su terminal, dentro de `C:\dev\motomoto`: `npx eas-cli build -p ios --profile production`. Pide el usuario y la contraseña de Apple y el código de verificación. Responder **sí** a generar certificado, perfil y **clave de notificaciones**. | 30-40 min en la nube      |
| 5   | Jhan   | `npx eas-cli submit -p ios --latest` y dar el Apple ID de la app del paso 3. Sube el build a TestFlight.                                                                                                                                          | 10 min + el procesamiento |
| 6   | Jhan   | Instalar **TestFlight** en un iPhone, aceptar la invitación (Jhan es el "Probador interno") y abrir la app. Hace falta un iPhone real: sin él no se puede probar nada de lo que sigue.                                                            | 10 min                    |
| 7   | Ambos  | Probar lo de la lista de abajo. Jhan toca, Claude mira los registros del servidor.                                                                                                                                                                | 1 h                       |
| 8   | Jhan   | Tomar las capturas en el iPhone y rehacer el video (ver `ficha-app-store.md` secciones 2 y 6).                                                                                                                                                    | 1 h                       |
| 9   | Claude | Preparar el texto final de cada campo de App Store Connect; Jhan lo pega. Completar "App Privacy", edad, notas del revisor y cuentas de demostración.                                                                                             | 30 min                    |
| 10  | Jhan   | "Añadir para revisión" y "Enviar". Apple suele tardar 24-48 h.                                                                                                                                                                                    | 24-48 h                   |
| 11  | Claude | **Opcional, después:** Universal Links. Con el Team ID (developer.apple.com → Membership) se añade `associatedDomains` y `site/.well-known/apple-app-site-association`.                                                                           | 15 min                    |

## Qué se prueba en TestFlight (paso 7)

1. Registro, correo de confirmación (abre la app desde el correo), inicio de sesión.
2. Pasajero: ubicación con la app abierta, elegir destino, **proponer un precio**,
   pedir el servicio.
3. Conductor (cuenta de prueba): ponerse disponible, **permiso "Siempre"**, minimizar
   la app y comprobar en la base de datos que `driver_locations.updated_at` sigue
   avanzando. Es la prueba más importante: es lo que Apple suspende si no está
   bien configurado.
4. **Notificación push** ("Tu motocarro llegó") con la app minimizada.
5. "Ir a la recogida" abre Apple Maps.
6. Recarga de saldo con Wompi (abre el navegador y vuelve).
7. Eliminar la cuenta desde el perfil del pasajero.

## Riesgos que siguen abiertos

Están en `ficha-app-store.md`, sección 6: el revisor no puede probar un viaje desde
fuera de Colombia, las recargas de Wompi frente a las reglas 3.1.1/3.1.3(e), y que
no existe "bloquear a un usuario". Además, **Mapbox**: hay que confirmar en el
build real que su telemetría está apagada (afecta a "App Privacy").
