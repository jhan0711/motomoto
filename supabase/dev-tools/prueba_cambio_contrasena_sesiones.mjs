// =============================================================================
// HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
// =============================================================================
//
// Prueba de la Fase 22, paso 3: al cambiar la contrasena, las sesiones abiertas
// en otros dispositivos dejan de valer.
//
//   node supabase/dev-tools/prueba_cambio_contrasena_sesiones.mjs
//
// NO ES SQL: esto vive en GoTrue, no en la base de datos, asi que se prueba por
// la API de autenticacion. Usa el pasajero de prueba y le devuelve su contrasena
// original al terminar.
//
// EL RESULTADO, cuando se escribio: GoTrue **ya revoca** todas las demas
// sesiones al cambiar la contrasena, sin que la aplicacion haga nada. El
// pendiente que decia "Supabase no lo hace por defecto" venia de la Fase 6 y
// quedo obsoleto. Este script existe para que un cambio de version o de
// configuracion que rompa ese comportamiento se note.
// =============================================================================

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const env = readFileSync(resolve(raiz, '.env'), 'utf8');
const leer = (k) => (env.match(new RegExp('^' + k + '=(.*)$', 'm')) || [])[1]?.trim();

const URL = leer('EXPO_PUBLIC_SUPABASE_URL');
const KEY = leer('EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY');
const EMAIL = 'pasajero.prueba@motomoto-qa.co';
const ORIGINAL = 'Pasajero.2026';
const NUEVA = 'Pasajero.2026-temp';

const cliente = () =>
  createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });

const resultados = [];
const comprobar = (n, comprobacion, ok, detalle) =>
  resultados.push({ n, comprobacion, ok, detalle });

async function refrescoVive(refreshToken) {
  const c = cliente();
  const { error } = await c.auth.refreshSession({ refresh_token: refreshToken });
  return !error;
}

async function main() {
  // --- Camino 1: cambio directo (updatePassword, como en el enlace de correo) ---
  const esteAparato = cliente();
  const otroAparato = cliente();

  let r = await esteAparato.auth.signInWithPassword({ email: EMAIL, password: ORIGINAL });
  if (r.error)
    throw new Error('No se pudo iniciar sesion con la contrasena original: ' + r.error.message);

  r = await otroAparato.auth.signInWithPassword({ email: EMAIL, password: ORIGINAL });
  const otroRefresh1 = r.data.session.refresh_token;

  comprobar(1, 'El otro dispositivo entra y su sesion vale', await refrescoVive(otroRefresh1));

  r = await esteAparato.auth.updateUser({ password: NUEVA });
  comprobar(2, 'updatePassword cambia la contrasena', !r.error, r.error?.message);

  const otroRefresh1b =
    (await otroAparato.auth.getSession()).data.session?.refresh_token ?? otroRefresh1;
  comprobar(
    3,
    'Tras el cambio, la sesion del otro dispositivo ya NO vale',
    !(await refrescoVive(otroRefresh1b)),
  );

  comprobar(
    4,
    'La sesion de este dispositivo SIGUE valiendo',
    !(await esteAparato.auth.getUser()).error,
  );

  // --- Camino 2: cambio desde dentro de la app (changePassword: reautentica) ---
  const otro2 = cliente();
  r = await otro2.auth.signInWithPassword({ email: EMAIL, password: NUEVA });
  const otro2Refresh = r.data.session.refresh_token;

  const appDev = cliente();
  await appDev.auth.signInWithPassword({ email: EMAIL, password: NUEVA }); // sesion vieja de este aparato
  const viejaRefresh = (await appDev.auth.getSession()).data.session.refresh_token;

  await appDev.auth.signInWithPassword({ email: EMAIL, password: NUEVA }); // reautenticacion -> sesion nueva
  r = await appDev.auth.updateUser({ password: ORIGINAL });
  comprobar(
    5,
    'changePassword: la reautenticacion y el cambio funcionan',
    !r.error,
    r.error?.message,
  );

  comprobar(
    6,
    'changePassword: la sesion previa a la reautenticacion, en este aparato, ya NO vale',
    !(await refrescoVive(viejaRefresh)),
  );
  comprobar(
    7,
    'changePassword: la sesion del otro dispositivo ya NO vale',
    !(await refrescoVive(otro2Refresh)),
  );
  comprobar(
    8,
    'changePassword: la sesion nueva de este aparato SIGUE valiendo',
    !(await appDev.auth.getUser()).error,
  );

  // --- Restaurar ---
  const restaurar = cliente();
  r = await restaurar.auth.signInWithPassword({ email: EMAIL, password: ORIGINAL });
  comprobar(9, 'La contrasena quedo restaurada a la original', !r.error, r.error?.message);
}

main()
  .then(() => {
    let fallando = 0;
    for (const x of resultados) {
      if (!x.ok) fallando++;
      console.log(
        `${x.n}\t${x.ok ? 'OK  ' : 'FALLA'}\t${x.comprobacion}${x.detalle && !x.ok ? '  -> ' + x.detalle : ''}`,
      );
    }
    console.log(
      `999\t${fallando === 0 ? 'OK  ' : 'FALLA'}\tTOTAL\t${resultados.length} comprobaciones, ${fallando} fallando`,
    );
    process.exit(fallando === 0 ? 0 : 1);
  })
  .catch((e) => {
    console.error('ERROR:', e.message);
    console.error(
      'Puede que la contrasena del pasajero de prueba haya quedado en',
      NUEVA,
      '- revisar.',
    );
    process.exit(1);
  });
