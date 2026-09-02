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

const googleMapsApiKey = process.env.GOOGLE_MAPS_ANDROID_KEY;

if (!googleMapsApiKey) {
  // Un aviso, no un fallo. Permite seguir trabajando en pantallas que no son el
  // mapa, pero deja claro por qué el mapa saldría en gris si se abre.
  console.warn(
    '[app.config] Falta GOOGLE_MAPS_ANDROID_KEY en .env. El mapa se verá como una cuadrícula gris.',
  );
}

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
  name: 'motomoto',
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
    // Necesario desde la Fase 8: identifica la aplicación ante Google Maps.
    // La clave de la API está restringida a este nombre exacto.
    package: 'com.motomoto.app',

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
    // paquete com.motomoto.app). Queda anotado en la seccion 15.20.
    googleServicesFile: './google-services.json',
    adaptiveIcon: {
      backgroundColor: '#E6F4FE',
      foregroundImage: './assets/images/android-icon-foreground.png',
      backgroundImage: './assets/images/android-icon-background.png',
      monochromeImage: './assets/images/android-icon-monochrome.png',
    },
    predictiveBackGestureEnabled: false,
    config: {
      googleMaps: {
        apiKey: googleMapsApiKey,
      },
    },
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
          'MotoMoto necesita acceso a tus fotos para que puedas elegir tu foto de perfil.',
        cameraPermission:
          'MotoMoto necesita acceso a la cámara para que puedas tomarte una foto de perfil.',
      },
    ],
    [
      'expo-location',
      {
        // Solo primer plano. La ubicación en segundo plano es de la Fase 14, y
        // pedirla antes de tiempo añadiría un permiso que Google Play exige
        // justificar y que hoy no usamos para nada.
        locationWhenInUsePermission:
          'MotoMoto usa tu ubicación para mostrarte en el mapa y saber dónde recogerte.',
        isAndroidBackgroundLocationEnabled: false,
        isAndroidForegroundServiceEnabled: false,
      },
    ],
    [
      'expo-splash-screen',
      {
        backgroundColor: '#208AEF',
        image: './assets/images/splash-icon.png',
        imageWidth: 76,
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
