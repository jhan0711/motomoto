-- Punto 3 del plan del 2026-09-23 (D279), segunda entrega, parte que NO depende de
-- las llaves de Wompi: las intenciones de recarga y las funciones que acreditan.
-- Ver `docs/operaciones/wompi-recargas.md` para el diseño completo.
--
-- Principio: el monto que se acredita sale de lo que NOSOTROS creamos antes de que
-- el conductor pague (la intencion), nunca de lo que diga el aviso de pago. El
-- aviso solo dice "esta referencia se pago"; cuanto vale lo sabe esta tabla.
--
-- Todas las funciones son SOLO para `service_role`: las llama la Edge Function
-- despues de verificar la firma del aviso. Ni un conductor ni un administrador
-- pueden acreditarse saldo llamando a esto desde la app o el panel (para eso
-- esta `admin_adjust_driver_balance`, con motivo y auditoria).

create table public.topup_intents (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null,
  -- La que viaja a Wompi. Unica por transaccion, alfanumerica con guiones.
  reference text not null unique,
  amount integer not null,
  status text not null default 'pending',
  wompi_transaction_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ti_amount_range check (amount between 1000 and 1000000),
  constraint ti_status check (status in ('pending', 'approved', 'declined', 'voided', 'error', 'review'))
);

-- Sin llave foranea a `drivers`, por lo mismo que `driver_ledger`: es un registro
-- de dinero y tiene que sobrevivir a la cuenta.
create index ti_driver_created on public.topup_intents (driver_id, created_at desc);

comment on table public.topup_intents is
  'Recargas iniciadas por conductores. Nacen antes del pago; el aviso de Wompi solo las confirma.';
comment on column public.topup_intents.status is
  'pending: creada, sin resolver. approved: acreditada. declined/error: no se pago. voided: pagada y luego anulada (se reverso). review: el aviso no cuadro con la intencion y NO se acredito; la revisa una persona.';

alter table public.topup_intents enable row level security;

revoke all on public.topup_intents from public, anon, authenticated;
grant select on public.topup_intents to authenticated;

-- El conductor ve las suyas (para mostrar "pago pendiente"); el administrador,
-- todas. Nadie escribe directo.
create policy topup_intents_select_own on public.topup_intents
  for select to authenticated
  using (driver_id = (select auth.uid()) or (select public.is_admin()));

-- ---------------------------------------------------------------------------
-- Crear una intencion
-- ---------------------------------------------------------------------------

create function public.create_topup_intent(p_driver uuid, p_amount integer)
returns table (reference text, amount integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_min integer := (public.get_setting('min_topup_amount', '10000'))::integer;
  v_ref text;
begin
  if not exists (
    select 1
    from public.drivers d join public.profiles p on p.id = d.id
    where d.id = p_driver and p.status = 'active'
  ) then
    raise exception 'Solo un conductor con la cuenta activa puede recargar'
      using errcode = 'P0001', hint = 'NOT_AN_ACTIVE_DRIVER';
  end if;

  if p_amount is null or p_amount < v_min then
    raise exception 'La recarga minima es de % pesos', v_min
      using errcode = 'P0001', hint = 'TOPUP_BELOW_MINIMUM';
  end if;

  if p_amount > 1000000 then
    raise exception 'La recarga maxima es de 1.000.000 de pesos'
      using errcode = 'P0001', hint = 'TOPUP_ABOVE_MAXIMUM';
  end if;

  -- Un freno contra el que abre intenciones en bucle. Cada una es una fila y una
  -- referencia que Wompi recuerda para siempre.
  if (
    select count(*) from public.topup_intents t
    where t.driver_id = p_driver and t.created_at > now() - interval '1 hour'
  ) >= 10 then
    raise exception 'Demasiados intentos de recarga. Espera un rato'
      using errcode = 'P0001', hint = 'TOPUP_RATE_LIMITED';
  end if;

  -- 'AGA-' + 32 hexadecimales: alfanumerica, sin nada que Wompi rechace, y no
  -- adivinable (no lleva el id del conductor ni un contador).
  v_ref := 'AGA-' || replace(gen_random_uuid()::text, '-', '');

  insert into public.topup_intents (driver_id, reference, amount)
  values (p_driver, v_ref, p_amount);

  return query select v_ref, p_amount;
end;
$$;

revoke all on function public.create_topup_intent(uuid, integer) from public, anon, authenticated;
grant execute on function public.create_topup_intent(uuid, integer) to service_role;

-- ---------------------------------------------------------------------------
-- Acreditar
-- ---------------------------------------------------------------------------

-- Devuelve TEXTO y no lanza cuando el aviso no cuadra: una excepcion deshace la
-- transaccion y con ella la marca de 'review', y el aviso se perderia sin dejar
-- rastro. Los resultados posibles:
--   credited          se acredito ahora
--   already_credited  el aviso llego repetido (Wompi reintenta): no se hace nada
--   unknown_reference no hay intencion con esa referencia
--   amount_mismatch   el monto pagado no es el de la intencion: NO se acredita
--   not_pending       la intencion ya se resolvio de otra forma (declinada...)
create function public.credit_driver_topup(
  p_reference text,
  p_wompi_transaction_id text,
  p_amount integer
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_intent public.topup_intents;
begin
  -- `for update`: dos avisos simultaneos del mismo pago se turnan y el segundo ve
  -- el resultado del primero. El indice unico del libro es el respaldo.
  select * into v_intent from public.topup_intents where reference = p_reference for update;

  if not found then
    return 'unknown_reference';
  end if;

  if v_intent.status = 'approved' then
    return 'already_credited';
  end if;

  if v_intent.status <> 'pending' then
    return 'not_pending';
  end if;

  if p_amount is distinct from v_intent.amount then
    update public.topup_intents
    set status = 'review', wompi_transaction_id = p_wompi_transaction_id, updated_at = now()
    where id = v_intent.id;
    return 'amount_mismatch';
  end if;

  insert into public.driver_ledger (driver_id, kind, amount, external_ref)
  values (v_intent.driver_id, 'topup', v_intent.amount, p_wompi_transaction_id);

  update public.topup_intents
  set status = 'approved', wompi_transaction_id = p_wompi_transaction_id, updated_at = now()
  where id = v_intent.id;

  return 'credited';
end;
$$;

revoke all on function public.credit_driver_topup(text, text, integer) from public, anon, authenticated;
grant execute on function public.credit_driver_topup(text, text, integer) to service_role;

-- ---------------------------------------------------------------------------
-- Marcar una recarga que no se pago
-- ---------------------------------------------------------------------------

create function public.fail_driver_topup(p_reference text, p_status text, p_wompi_transaction_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_intent public.topup_intents;
begin
  if p_status not in ('declined', 'error') then
    raise exception 'Estado no valido' using errcode = 'P0001', hint = 'INVALID_TOPUP_STATUS';
  end if;

  select * into v_intent from public.topup_intents where reference = p_reference for update;

  if not found then
    return 'unknown_reference';
  end if;

  -- Solo una recarga pendiente pasa a fallida. Una ya acreditada no se toca por
  -- un aviso de "declinada" tardio o falso: para deshacerla esta `reverse_...`.
  if v_intent.status <> 'pending' then
    return 'not_pending';
  end if;

  update public.topup_intents
  set status = p_status, wompi_transaction_id = p_wompi_transaction_id, updated_at = now()
  where id = v_intent.id;

  return 'marked';
end;
$$;

revoke all on function public.fail_driver_topup(text, text, text) from public, anon, authenticated;
grant execute on function public.fail_driver_topup(text, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- Reversar una recarga anulada
-- ---------------------------------------------------------------------------

-- Wompi puede anular una transaccion de tarjeta DESPUES de aprobarla (VOIDED). El
-- libro no se edita: se anade un ajuste en contra con el motivo, y la intencion
-- pasa a 'voided'. Si el conductor ya gasto el saldo, el resultado es un saldo
-- negativo -deuda-, que la recarga siguiente paga primero (D278).
create function public.reverse_driver_topup(p_reference text, p_wompi_transaction_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_intent public.topup_intents;
begin
  select * into v_intent from public.topup_intents where reference = p_reference for update;

  if not found then
    return 'unknown_reference';
  end if;

  if v_intent.status = 'voided' then
    return 'already_reversed';
  end if;

  if v_intent.status <> 'approved' then
    -- Nunca se acredito: no hay nada que reversar, solo se deja constancia.
    update public.topup_intents
    set status = 'voided', wompi_transaction_id = coalesce(wompi_transaction_id, p_wompi_transaction_id),
        updated_at = now()
    where id = v_intent.id and status = 'pending';
    return 'not_credited';
  end if;

  insert into public.driver_ledger (driver_id, kind, amount, reason, external_ref)
  values (
    v_intent.driver_id, 'adjustment', -v_intent.amount,
    'Recarga anulada por la pasarela (' || p_reference || ')',
    -- Otro identificador que el de la recarga: `external_ref` es unico en todo el
    -- libro, y la fila de la recarga ya usa el de la transaccion.
    'void:' || coalesce(p_wompi_transaction_id, p_reference)
  );

  update public.topup_intents
  set status = 'voided', updated_at = now()
  where id = v_intent.id;

  return 'reversed';
end;
$$;

revoke all on function public.reverse_driver_topup(text, text) from public, anon, authenticated;
grant execute on function public.reverse_driver_topup(text, text) to service_role;
