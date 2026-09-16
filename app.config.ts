import type { ExpoConfig } from 'expo/config';

/**
 * Configuración de la aplicación.
 *
 * Sustituye a app.json desde la Fase 8. El motivo es la clave de Google Maps:
 * app.json es JSON estático y no puede leer variables de entorno, así que la
 * clave habría acabado escrita en un archivo que sí sube al repositorio.
 * Este archivo se ejecuta en Node al compilar y puede leer del .env.
 *
 * Sobre la clave de mapas: acaba dentro del APK, en el AndroidManifest. Eso es
 * inevitable y es cómo funciona el SDK de Google Maps. Por eso la clave se
 * restringe en Google Cloud por nombre de paquete y huella SHA-1: aunque
 * alguien la extraiga del APK, no puede usarla desde otra aplicación.
 */

/**
 * Token SECRETO de descarga de Mapbox, distinto del público.
 *
 * El público (`EXPO_PUBLIC_MAPBOX_SEARCH_TOKEN`) viaja dentro de la aplicación y
 * sirve para buscar direcciones y calcular rutas. Este otro no viaja a ninguna
 * parte: lo usa Gradle **al compilar**, para bajar el SDK nativo de Mapbox de un
 * repositorio privado. Por eso empieza por `sk.` y por eso no lleva el prefijo
 * `EXPO_PUBLIC_`, que es lo que marca a las variables que sí se incrustan.
 *
 * Sin él, la compilación falla con un 401 de Maven que no menciona a Mapbox por
 * ninguna parte. De ahí el aviso explícito.
 *
 * AQUÍ SOLO SE COMPRUEBA QUE EXISTA, NO SE LE PASA AL PLUGIN. El plugin admitía
 * recibirlo como opción, y esa vía está desaconsejada por dos motivos: escribe el
 * token en `android/gradle.properties`, y cualquier volcado de la configuración
 * —`expo config`, un registro de compilación— lo imprime entero. Leyéndolo el
 * plugin del entorno, el valor no aparece en ningún archivo del proyecto ni en
 * ninguna salida. El nombre de la variable lo fija el plugin, no nosotros.
 */
const mapboxDownloadToken = process.env.RNMAPBOX_MAPS_DOWNLOAD_TOKEN;

if (!mapboxDownloadToken) {
  console.warn(
    '[app.config] Falta RNMAPBOX_MAPS_DOWNLOAD_TOKEN en .env. La compilación nativa fallará al bajar el SDK de Mapbox.',
  );
}

const config: ExpoConfig = {
  // Nombre visible: bajo el icono, en el conmutador de apps y en los diálogos
  // de permisos (Fase 25 paso 3). El `scheme` sigue siendo `motomoto`: es el
  // esquema de enlace profundo, no es visible, y cambiarlo rompería el enlace de
  // recuperación de contraseña (D95, paso 6).
  name: 'AmalfiGoApp',
  // El `slug` es el identificador interno del proyecto en Expo (`jhan160711/motomoto`,
  // creado en la Fase 19). No es visible para nadie y no se puede renombrar desde
  // el panel, así que se deja como el proyecto ya existe: cambiarlo a `amalfigoapp`
  // rompía todos los comandos de `eas` por no cuadrar con `extra.eas.projectId`.
  slug: 'motomoto',
  version: '1.0.0',
  orientation: 'portrait',
  icon: './assets/images/icon.png',
  scheme: 'motomoto',
  userInterfaceStyle: 'automatic',

  ios: {
    icon: './assets/expo.icon',
  },

  android: {
    // Identifica la app ante Google Maps (la clave está restringida a este
    // nombre) y es el id con el que se publica en Google Play.
    //
    // Fase 26 paso 1: se renombró de `com.motomoto.app` a `co.amalfigo.app`
    // ANTES de la primera subida a Play -después no se puede cambiar-. El
    // cambio arrastra: la clave de Google Maps (Google Cloud), el
    // `google-services.json` de Firebase (proyecto `motomoto2026-444cb`) y, más
    // adelante, las credenciales de EAS. El `scheme` de enlace profundo sigue
    // siendo `motomoto` a propósito: solo se usa como respaldo de los App
    // Links y renombrarlo no aporta nada.
    package: 'co.amalfigo.app',

    // Fase 22, paso 4 (D93). Sin esto, Android sube los datos de la aplicación
    // —incluida la sesión de Supabase, que vive en AsyncStorage sin cifrar— a la
    // copia de seguridad de Google Drive del usuario, de forma automática. La
    // sesión no es un dato que deba sobrevivir a un restore en otro aparato: no
    // hay nada aquí que valga la pena respaldar, todo está en el servidor.
    // TOMA EFECTO EN LA PRÓXIMA COMPILACIÓN NATIVA (cambia el AndroidManifest).
    allowBackup: false,
    // Fase 19. Expo Push entrega por FCM en Android, y FCM exige este archivo:
    // sin el, `getExpoPushTokenAsync` falla con "Default FirebaseApp is not
    // initialized" y el token nunca llega al servidor.
    //
    // NO ESTA EN EL REPOSITORIO: la plantilla de Expo ya lo ignoraba de fabrica
    // y se respeto esa decision. No es que sea secreto —Firebase lo documenta
    // como publico y acaba dentro del APK, igual que la clave de mapas—, pero
    // tampoco hace falta versionarlo con un solo desarrollador. Consecuencia a
    // no olvidar: **si este archivo falta, la compilacion nativa falla**, y hay
    // que volver a bajarlo de Firebase Console (proyecto motomoto2026-444cb,
    // paquete co.amalfigo.app). Queda anotado en la seccion 15.20.
    //
    // Fase 26 paso 4b: EAS Build en la nube solo sube lo que rastrea git, asi
    // que este archivo ignorado no llegaba y el build fallaba. Se subio a EAS
    // como variable de tipo `file` (`GOOGLE_SERVICES_JSON`), que EAS escribe en
    // disco y expone por su ruta. En local sigue leyendo `./google-services.json`.
    googleServicesFile: process.env.GOOGLE_SERVICES_JSON ?? './google-services.json',
    adaptiveIcon: {
      // El fondo del logo (Fase 25 paso 3). Color plano en vez de imagen: el
      // logo ya trae ese tono, y una imagen de un solo color es peso de más.
      backgroundColor: '#2A323C',
      foregroundImage: './assets/images/android-icon-foreground.png',
      monochromeImage: './assets/images/android-icon-monochrome.png',
    },
    predictiveBackGestureEnabled: false,

    // Fase 25, paso 2. Permisos que meten las herramientas y que la aplicación
    // no usa. Google Play pregunta por los dos.
    //
    // RECORD_AUDIO lo añade `expo-image-picker` para grabar vídeo, que aquí no
    // se hace. Se quita en origen con `microphonePermission: false` (más abajo) y
    // se bloquea aquí también, por si otra herramienta lo reintrodujera.
    //
    // SYSTEM_ALERT_WINDOW vive solo en la variante `debug` -lo pone
    // `android/app/src/debug/AndroidManifest.xml`, que genera `expo-dev-client`
    // para la burbuja flotante de su menú-. El build de release NO lo lleva, así
    // que en producción esto es defensivo: no lo quita del debug (esa variante
    // tiene prioridad de fusión y ahí la burbuja se quiere), y en release no hay
    // nada que quitar. Verificado con `processReleaseMainManifest`.
    blockedPermissions: [
      'android.permission.SYSTEM_ALERT_WINDOW',
      'android.permission.RECORD_AUDIO',
    ],

    // Fase 25, paso 6. Enlace de aplicación de Android para los correos de la
    // cuenta (recuperar contraseña, y en esta fase también confirmar la cuenta y
    // cambiar el correo). `autoVerify` hace que Android compruebe la propiedad
    // del dominio contra `https://amalfigo.app/.well-known/assetlinks.json`; si
    // cuadra, entrega `https://amalfigo.app/auth...` a la app sin pasar por el
    // navegador (D95, H7). Solo esa ruta: el resto del dominio -la página, los
    // textos legales- sigue abriéndose en el navegador.
    intentFilters: [
      {
        action: 'VIEW',
        autoVerify: true,
        data: [{ scheme: 'https', host: 'amalfigo.app', pathPrefix: '/auth' }],
        category: ['BROWSABLE', 'DEFAULT'],
      },
    ],
  },

  web: {
    output: 'static',
    favicon: './assets/images/favicon.png',
  },

  plugins: [
    'expo-router',
    'expo-dev-client',
    // Sin opciones: el token de descarga lo lee el plugin del entorno, y el
    // público lo registra el código al arrancar. Ver el comentario de arriba.
    '@rnmapbox/maps',
    [
      'expo-image-picker',
      {
        photosPermission:
          'AmalfiGoApp necesita acceso a tus fotos para que puedas elegir tu foto de perfil.',
        cameraPermission:
          'AmalfiGoApp necesita acceso a la cámara para que puedas tomarte una foto de perfil.',
        // No se graba vídeo: sin esto el plugin añade RECORD_AUDIO al manifest
        // (Fase 25 paso 2).
        microphonePermission: false,
      },
    ],
    [
      'expo-location',
      {
        locationWhenInUsePermission:
          'AmalfiGoApp usa tu ubicación para mostrarte en el mapa y saber dónde recogerte.',
        // Pedido de la empresa, validado con el dueño del producto
        // (2026-09-15): un conductor "disponible" con la aplicación
        // minimizada dejaba de recibir ofertas a los dos minutos (D116, R10).
        // Ampliado a "en viaje" el 2026-09-16 -ver la cabecera de
        // use-background-location.ts para el porque-. Exige el permiso "en
        // todo momento" de Android mas el servicio en primer plano con su
        // notificacion fija, los dos activados aqui. La pantalla de
        // justificacion que Android 10+ exige antes de pedir el permiso vive
        // inline en app/driver/(tabs)/index.tsx (el Aviso de "Sigue enviando
        // tu ubicación..."), no en un archivo aparte: este texto de abajo es
        // el que ve el sistema operativo, no el que ve el conductor.
        locationAlwaysPermission:
          'AmalfiGoApp usa tu ubicación en segundo plano para que los pasajeros sigan viéndote mientras estás disponible o llevando un servicio, aunque minimices la aplicación.',
        isAndroidBackgroundLocationEnabled: true,
        isAndroidForegroundServiceEnabled: true,
      },
    ],
    [
      'expo-splash-screen',
      {
        // Fase 25 paso 3: el fondo del logo y la marca centrada.
        backgroundColor: '#2A323C',
        image: './assets/images/splash-icon.png',
        imageWidth: 160,
      },
    ],
    [
      'expo-notifications',
      {
        // Sin icono ni sonido propios: el icono monocromo de notificacion es
        // un activo de diseno que no existe todavia (D44 no lo cubrio), y usar
        // el de la aplicacion a secas es aceptable para el MVP. Se revisa si
        // hace falta cuando el sistema de diseno pase por aqui.
        color: '#F27127',
      },
    ],
  ],

  experiments: {
    typedRoutes: true,
    reactCompiler: true,
  },

  // Vinculado con `eas init` en la Fase 19. Sin cuenta de Expo hasta entonces
  // (D113); esto no cambia como se compila hoy, solo identifica el proyecto
  // ante el servicio de notificaciones push, que es lo que lo exige.
  extra: {
    eas: {
      projectId: '93c1536c-ce38-4977-8588-7362b53d761a',
    },
  },
  owner: 'jhan160711',
};

export default config;
