-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260925120000_topup_intents.sql` (D279): las intenciones de
-- recarga y las funciones que acreditan, reversan y marcan fallos. Es la parte
-- del punto 3 que NO depende de las llaves de Wompi.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_recargas.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
-- Las funciones son solo de `service_role`; aqui se llaman como el propietario,
-- y la comprobacion de permisos se hace por `has_function_privilege`.
-- =============================================================================

begin;

create temp table resultados (
  n integer,
  comprobacion text,
  esperado text,
  obtenido text,
  ok boolean
) on commit drop;

do $recargas$
declare
  v_cond uuid;
  v_ref text;
  v_ref2 text;
  v_amount integer;
  v_r text;
  v_h text;
  v_n integer := 0;
  v_bal integer;
  v_cuenta integer;
  v_st text;
  v_firma text;
begin
  select d.id into v_cond
  from public.drivers d join public.profiles p on p.id = d.id
  where d.approval_status = 'approved' and p.status = 'active'
  order by d.id limit 1;

  -- ------------------------------------------------------------- permisos
  foreach v_firma in array array[
    'public.create_topup_intent(uuid,integer)',
    'public.credit_driver_topup(text,text,integer)',
    'public.fail_driver_topup(text,text,text)',
    'public.reverse_driver_topup(text,text)'
  ] loop
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Solo service_role ejecuta ' || v_firma,
      'anon=f auth=f service=t',
      'anon=' || has_function_privilege('anon', v_firma, 'execute')
        || ' auth=' || has_function_privilege('authenticated', v_firma, 'execute')
        || ' service=' || has_function_privilege('service_role', v_firma, 'execute'),
      not has_function_privilege('anon', v_firma, 'execute')
        and not has_function_privilege('authenticated', v_firma, 'execute')
        and has_function_privilege('service_role', v_firma, 'execute'));
  end loop;

  -- ------------------------------------------------------ crear intenciones
  begin
    perform public.create_topup_intent(v_cond, 9999);
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Recarga bajo el minimo', 'TOPUP_BELOW_MINIMUM', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Recarga bajo el minimo', 'TOPUP_BELOW_MINIMUM',
      coalesce(v_h, sqlstate), v_h = 'TOPUP_BELOW_MINIMUM');
  end;

  begin
    perform public.create_topup_intent(v_cond, 1000001);
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Recarga sobre el maximo', 'TOPUP_ABOVE_MAXIMUM', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Recarga sobre el maximo', 'TOPUP_ABOVE_MAXIMUM',
      coalesce(v_h, sqlstate), v_h = 'TOPUP_ABOVE_MAXIMUM');
  end;

  begin
    perform public.create_topup_intent(gen_random_uuid(), 10000);
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Recarga de quien no es conductor', 'NOT_AN_ACTIVE_DRIVER', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Recarga de quien no es conductor', 'NOT_AN_ACTIVE_DRIVER',
      coalesce(v_h, sqlstate), v_h = 'NOT_AN_ACTIVE_DRIVER');
  end;

  select t.reference, t.amount into v_ref, v_amount from public.create_topup_intent(v_cond, 20000) t;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Una recarga valida devuelve referencia AGA- y el monto',
    'AGA-... / 20000', v_ref || ' / ' || v_amount,
    v_ref like 'AGA-%' and length(v_ref) = 36 and v_amount = 20000);

  -- ------------------------------------------------------------- acreditar
  select public.driver_balance(v_cond) into v_bal;

  v_r := public.credit_driver_topup('AGA-noexiste', 'tx-1', 20000);
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Referencia desconocida', 'unknown_reference', v_r, v_r = 'unknown_reference');

  -- El monto pagado no es el de la intencion: NO se acredita y queda en revision.
  v_r := public.credit_driver_topup(v_ref, 'tx-mal', 19999);
  select status into v_st from public.topup_intents where reference = v_ref;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Monto que no cuadra: no acredita y queda en review',
    'amount_mismatch / review / saldo igual',
    v_r || ' / ' || v_st || ' / ' || (public.driver_balance(v_cond) = v_bal),
    v_r = 'amount_mismatch' and v_st = 'review' and public.driver_balance(v_cond) = v_bal);

  -- Una intencion en revision no se acredita despues por un aviso "bueno": la
  -- resuelve una persona.
  v_r := public.credit_driver_topup(v_ref, 'tx-bien', 20000);
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Una intencion en review no se acredita sola', 'not_pending', v_r, v_r = 'not_pending');

  select t.reference into v_ref2 from public.create_topup_intent(v_cond, 20000) t;
  v_r := public.credit_driver_topup(v_ref2, 'tx-ok', 20000);
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Un pago que cuadra se acredita', 'credited', v_r, v_r = 'credited');
  v_n := v_n + 1;
  insert into resultados values (v_n, 'El saldo sube 20.000', (v_bal + 20000)::text,
    public.driver_balance(v_cond)::text, public.driver_balance(v_cond) = v_bal + 20000);

  -- Wompi reintenta y un mismo pago puede llegar dos veces.
  v_r := public.credit_driver_topup(v_ref2, 'tx-ok', 20000);
  select count(*) into v_cuenta from public.driver_ledger where external_ref = 'tx-ok';
  v_n := v_n + 1;
  insert into resultados values (v_n, 'El aviso repetido no acredita dos veces',
    'already_credited / 1 fila / saldo +20000',
    v_r || ' / ' || v_cuenta || ' fila / saldo ' || (public.driver_balance(v_cond) - v_bal),
    v_r = 'already_credited' and v_cuenta = 1 and public.driver_balance(v_cond) = v_bal + 20000);

  -- ---------------------------------------------- una recarga que no se pago
  select t.reference into v_ref from public.create_topup_intent(v_cond, 10000) t;
  v_r := public.fail_driver_topup(v_ref, 'declined', 'tx-no');
  select status into v_st from public.topup_intents where reference = v_ref;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Una recarga declinada se marca', 'marked / declined', v_r || ' / ' || v_st,
    v_r = 'marked' and v_st = 'declined');

  -- Y despues un aviso "aprobada" con la misma referencia no la acredita.
  v_r := public.credit_driver_topup(v_ref, 'tx-no', 10000);
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Una recarga declinada no se acredita despues', 'not_pending', v_r, v_r = 'not_pending');

  -- Una recarga ya acreditada no se marca como fallida por un aviso tardio.
  v_r := public.fail_driver_topup(v_ref2, 'declined', 'tx-ok');
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Una recarga acreditada no se marca como fallida', 'not_pending', v_r, v_r = 'not_pending');

  -- ------------------------------------------------------------- reversar
  v_r := public.reverse_driver_topup(v_ref2, 'tx-ok');
  select status into v_st from public.topup_intents where reference = v_ref2;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Una recarga anulada se reversa con un ajuste',
    'reversed / voided / saldo igual al inicial',
    v_r || ' / ' || v_st || ' / ' || (public.driver_balance(v_cond) - v_bal),
    v_r = 'reversed' and v_st = 'voided' and public.driver_balance(v_cond) = v_bal);

  v_r := public.reverse_driver_topup(v_ref2, 'tx-ok');
  select count(*) into v_cuenta from public.driver_ledger where external_ref = 'void:tx-ok';
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Anular dos veces no reversa dos veces', 'already_reversed / 1 fila',
    v_r || ' / ' || v_cuenta || ' fila', v_r = 'already_reversed' and v_cuenta = 1);

  -- El libro conserva las dos filas: recarga y ajuste. Nada se borro.
  select count(*) into v_cuenta from public.driver_ledger
  where driver_id = v_cond and external_ref in ('tx-ok', 'void:tx-ok');
  v_n := v_n + 1;
  insert into resultados values (v_n, 'El libro conserva la recarga y su reverso', '2', v_cuenta::text, v_cuenta = 2);

  -- ------------------------------------------------------------- el freno
  -- Ya hay 3 intenciones de esta hora; se crean 7 mas hasta llegar a 10 y la siguiente
  -- se rechaza.
  for i in 1..7 loop
    perform public.create_topup_intent(v_cond, 10000);
  end loop;
  begin
    perform public.create_topup_intent(v_cond, 10000);
    v_n := v_n + 1;
    insert into resultados values (v_n, 'La intencion numero 11 en una hora', 'TOPUP_RATE_LIMITED', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'La intencion numero 11 en una hora', 'TOPUP_RATE_LIMITED',
      coalesce(v_h, sqlstate), v_h = 'TOPUP_RATE_LIMITED');
  end;
end
$recargas$;


select
  r.n,
  case when r.ok then 'OK  ' else 'FALLA' end as estado,
  r.comprobacion,
  r.esperado,
  r.obtenido
from resultados r
union all
select
  999,
  case when bool_and(coalesce(x.ok, false)) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not coalesce(x.ok, false)) || ' fallando'
from resultados x
order by 1;

rollback;
