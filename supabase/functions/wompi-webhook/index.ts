// Edge Function `wompi-webhook` (D279). La llama WOMPI, no la app: por eso se
// despliega SIN verificacion de JWT (`--no-verify-jwt`, ver config.toml). Sin
// sesion de nadie, lo unico que autoriza un aviso es su firma.
//
// Corre en Deno. NO hay Deno en esta maquina y NO se ha ejecutado nunca contra un
// Wompi real: la logica de firma esta probada con jest en `_shared/`, pero esta
// pieza de pegamento se prueba por primera vez en sandbox, con las llaves.
//
// Que hace, en orden, y por que en este orden:
//   1. Verifica la firma del aviso. Un aviso sin firma valida no toca nada.
//   2. Le pregunta a Wompi, con la llave privada, como quedo esa transaccion. El
//      estado y el monto que cuentan son los de esa respuesta, no los del aviso:
//      aunque alguien consiguiera el secreto de eventos, no se acredita nada que
//      Wompi no confirme por su propio canal.
//   3. Llama a la funcion SQL que corresponda. El monto que se acredita es el de
//      la intencion que NOSOTROS creamos; el pagado solo se compara con el.
//
// Codigos de respuesta: 200 = "recibido, no reintentes" (tambien para avisos que
// se descartan a proposito); 401 = firma invalida; 400 = cuerpo que no es un
// aviso; 500 = fallo nuestro o de Wompi, para que REINTENTE (a los 30 min, 3 h y
// 24 h).

import { createClient } from 'npm:@supabase/supabase-js@2';

import { parseWompiEvent, transactionRefOf, verifyEventChecksum } from '../_shared/wompi.ts';

function json(cuerpo: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(cuerpo), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/** Lo que devuelve GET /v1/transactions/{id}, solo lo que se usa. */
interface WompiApiTransaction {
  id: string;
  reference: string;
  status: string;
  amount_in_cents: number;
  currency: string;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const eventsSecret = Deno.env.get('WOMPI_EVENTS_SECRET') ?? '';
  const privateKey = Deno.env.get('WOMPI_PRIVATE_KEY') ?? '';
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

  // Sin secretos no se puede verificar nada: mejor fallar fuerte que aceptar.
  if (eventsSecret === '' || privateKey === '' || supabaseUrl === '' || serviceKey === '') {
    console.error('wompi-webhook: faltan secretos de configuracion');
    return json({ error: 'not_configured' }, 500);
  }

  let cuerpo: unknown;
  try {
    cuerpo = await req.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  const evento = parseWompiEvent(cuerpo);
  if (evento === null) return json({ error: 'not_an_event' }, 400);

  // 1. La firma.
  const firmaValida = await verifyEventChecksum(
    evento,
    eventsSecret,
    req.headers.get('x-event-checksum'),
  );
  if (!firmaValida) {
    console.warn('wompi-webhook: firma invalida');
    return json({ error: 'invalid_signature' }, 401);
  }

  // Solo nos interesan los cambios de una transaccion. Los demas eventos
  // (tokens de Nequi, etc.) se reciben y se descartan.
  if (evento.event !== 'transaction.updated') return json({ ok: true, ignored: evento.event }, 200);

  const ref = transactionRefOf(evento);
  if (ref === null) return json({ error: 'no_transaction' }, 400);

  // Solo las referencias que NOSOTROS creamos. Otros cobros de la misma cuenta de
  // Wompi (si la empresa la usara para algo mas) no son asunto de esta funcion.
  if (!ref.reference.startsWith('AGA-'))
    return json({ ok: true, ignored: 'foreign_reference' }, 200);

  // 2. La confirmacion por el canal propio de Wompi.
  const base =
    (Deno.env.get('WOMPI_ENV') ?? 'sandbox') === 'production'
      ? 'https://production.wompi.co/v1'
      : 'https://sandbox.wompi.co/v1';

  let tx: WompiApiTransaction;
  try {
    const r = await fetch(`${base}/transactions/${encodeURIComponent(ref.id)}`, {
      headers: { Authorization: `Bearer ${privateKey}` },
    });
    if (!r.ok) {
      console.error('wompi-webhook: Wompi respondio', r.status);
      return json({ error: 'wompi_lookup_failed' }, 500);
    }
    tx = (await r.json()).data as WompiApiTransaction;
  } catch (e) {
    console.error('wompi-webhook: no se pudo consultar a Wompi', e);
    return json({ error: 'wompi_unreachable' }, 500);
  }

  // Lo que dijo el aviso y lo que dice Wompi tienen que ser la misma transaccion.
  if (tx.id !== ref.id || tx.reference !== ref.reference) {
    console.error('wompi-webhook: la transaccion consultada no es la del aviso');
    return json({ error: 'transaction_mismatch' }, 500);
  }

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

  // 3. La accion.
  let resultado: string;

  if (tx.status === 'APPROVED') {
    // Centavos que no son pesos enteros, o una moneda que no es COP, no son un
    // pago nuestro: se manda con monto imposible para que caiga en 'review'.
    const esPesosEnteros = tx.currency === 'COP' && tx.amount_in_cents % 100 === 0;
    const { data, error } = await admin.rpc('credit_driver_topup', {
      p_reference: ref.reference,
      p_wompi_transaction_id: tx.id,
      p_amount: esPesosEnteros ? tx.amount_in_cents / 100 : -1,
    });
    if (error) {
      console.error('wompi-webhook: credit_driver_topup', error);
      return json({ error: 'db_error' }, 500);
    }
    resultado = data as string;
  } else if (tx.status === 'VOIDED') {
    const { data, error } = await admin.rpc('reverse_driver_topup', {
      p_reference: ref.reference,
      p_wompi_transaction_id: tx.id,
    });
    if (error) {
      console.error('wompi-webhook: reverse_driver_topup', error);
      return json({ error: 'db_error' }, 500);
    }
    resultado = data as string;
  } else if (tx.status === 'DECLINED' || tx.status === 'ERROR') {
    const { data, error } = await admin.rpc('fail_driver_topup', {
      p_reference: ref.reference,
      p_status: tx.status.toLowerCase(),
      p_wompi_transaction_id: tx.id,
    });
    if (error) {
      console.error('wompi-webhook: fail_driver_topup', error);
      return json({ error: 'db_error' }, 500);
    }
    resultado = data as string;
  } else {
    // PENDING: todavia no hay nada que hacer. Wompi avisara cuando cambie.
    return json({ ok: true, pending: true }, 200);
  }

  // Un monto que no cuadra deja la intencion en 'review' para que la mire una
  // persona; se responde 200 para que Wompi NO reintente algo que no va a cambiar.
  if (resultado === 'amount_mismatch' || resultado === 'unknown_reference') {
    console.error('wompi-webhook: revisar a mano', resultado, ref.reference);
  }

  return json({ ok: true, result: resultado }, 200);
});
