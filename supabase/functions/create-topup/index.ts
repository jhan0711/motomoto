// Edge Function `create-topup` (D279). La llama la app del conductor con su
// sesion: Supabase verifica el JWT antes de que llegue aqui (`verify_jwt` por
// defecto), y de ahi sale QUIEN es el conductor. El cuerpo solo trae el monto.
//
// Corre en Deno. NO hay Deno en esta maquina y NO se ha ejecutado nunca: la firma
// del cobro esta probada con jest en `_shared/`, y este pegamento se prueba por
// primera vez en sandbox, con las llaves.
//
// Por que existe en el servidor y no en la app: la URL del checkout lleva una
// firma de integridad que se calcula con un secreto. Si el calculo viviera en el
// telefono, el secreto viajaria en la aplicacion y cualquiera podria fabricar un
// cobro por el monto que quisiera.

import { createClient } from 'npm:@supabase/supabase-js@2';

import { buildCheckoutUrl } from '../_shared/wompi.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(cuerpo: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(cuerpo), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

/** Los codigos que `create_topup_intent` puede lanzar y que el conductor debe entender. */
const ERRORES_CONOCIDOS = new Set([
  'NOT_AN_ACTIVE_DRIVER',
  'TOPUP_BELOW_MINIMUM',
  'TOPUP_ABOVE_MAXIMUM',
  'TOPUP_RATE_LIMITED',
]);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const publicKey = Deno.env.get('WOMPI_PUBLIC_KEY') ?? '';
  const integritySecret = Deno.env.get('WOMPI_INTEGRITY_SECRET') ?? '';
  const redirectUrl = Deno.env.get('WOMPI_REDIRECT_URL') ?? 'https://amalfigo.app/recarga';

  if (
    supabaseUrl === '' ||
    anonKey === '' ||
    serviceKey === '' ||
    publicKey === '' ||
    integritySecret === ''
  ) {
    console.error('create-topup: faltan secretos de configuracion');
    return json({ error: 'not_configured' }, 500);
  }

  // Quien llama: se le pregunta a Auth con el JWT que mando, no se le cree al
  // cuerpo. El identificador del conductor NUNCA viene del cliente.
  const authHeader = req.headers.get('Authorization') ?? '';
  const usuario = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: sesion, error: errorSesion } = await usuario.auth.getUser();

  if (errorSesion !== null || sesion.user === null) return json({ error: 'unauthorized' }, 401);

  let amount: unknown;
  try {
    ({ amount } = await req.json());
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  if (typeof amount !== 'number' || !Number.isInteger(amount)) {
    return json({ error: 'invalid_amount' }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const { data, error } = await admin.rpc('create_topup_intent', {
    p_driver: sesion.user.id,
    p_amount: amount,
  });

  if (error) {
    const codigo = error.hint ?? '';
    if (ERRORES_CONOCIDOS.has(codigo)) return json({ error: codigo }, 400);
    console.error('create-topup: create_topup_intent', error);
    return json({ error: 'db_error' }, 500);
  }

  const fila = (data as { reference: string; amount: number }[] | null)?.[0];
  if (fila === undefined) return json({ error: 'db_error' }, 500);

  const url = await buildCheckoutUrl({
    publicKey,
    reference: fila.reference,
    amountPesos: fila.amount,
    integritySecret,
    redirectUrl,
  });

  return json({ url, reference: fila.reference, amount: fila.amount }, 200);
});
