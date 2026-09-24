import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import { AppState } from 'react-native';

import type { Database } from '@/types/database';

/**
 * Cliente de Supabase.
 *
 * Es el unico punto de la aplicacion que conoce las credenciales del backend.
 * Todo acceso a datos pasa por aqui.
 */

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

// Falla al arrancar y no al primer uso. Un error aqui es un despliegue mal
// configurado, y es mucho mejor descubrirlo en el arranque que cuando un
// pasajero intenta pedir un motocarro.
if (!supabaseUrl || !supabaseKey) {
  throw new Error(
    'Faltan EXPO_PUBLIC_SUPABASE_URL o EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY. ' +
      'Copia .env.example como .env y rellena los valores.',
  );
}

/**
 * El tipo Database lo genera la CLI de Supabase a partir del esquema real:
 *
 *   npx.cmd supabase gen types typescript --linked
 *
 * Gracias a el, una consulta a una columna que no existe o una comparacion con
 * un estado invalido son errores de compilacion. Los tipos no se escriben a
 * mano: se regeneran despues de cada migracion.
 */
export const supabase = createClient<Database>(supabaseUrl, supabaseKey, {
  auth: {
    // Sin esto la sesion se pierde al cerrar la aplicacion y el usuario tendria
    // que volver a entrar cada vez.
    //
    // ASYNCSTORAGE Y NO EXPO-SECURE-STORE (D93, confirmado en la Fase 22 paso 4).
    // La sesion de Supabase medida son ~1518 bytes y crece con cada claim del
    // JWT; secure-store en Android avisa y puede fallar por encima de ~2048, asi
    // que cifrarla aqui cambiaria un riesgo por un cierre de sesion silencioso.
    // El token no queda expuesto: el sandbox de Android y el cifrado de disco lo
    // protegen en reposo, y `android.allowBackup: false` (app.config.ts) impide
    // que salga en la copia de Google Drive del usuario.
    storage: AsyncStorage,
    persistSession: true,
    autoRefreshToken: true,

    // En web, Supabase busca el token en la URL tras un enlace de correo. En
    // React Native no hay URL de navegador, y dejarlo activo provoca avisos.
    detectSessionInUrl: false,
  },
});

/**
 * Renovacion del token segun el estado de la aplicacion.
 *
 * Supabase mantiene un temporizador que renueva el token de sesion antes de que
 * caduque. Ese temporizador no debe seguir corriendo con la aplicacion en
 * segundo plano: consume bateria y, en Android, el sistema puede congelarlo y
 * dejar la sesion sin renovar sin que nadie se entere.
 *
 * Importa especialmente para el conductor, que tendra la aplicacion abierta
 * durante toda su jornada.
 */
AppState.addEventListener('change', (state) => {
  if (state === 'active') {
    void supabase.auth.startAutoRefresh();
  } else {
    void supabase.auth.stopAutoRefresh();
  }
});
