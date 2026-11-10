-- =============================================================================
-- Diagnostico del seguimiento de ubicacion del conductor (fase A, 2026-11-10)
-- =============================================================================
--
-- POR QUE. Un conductor "disponible" desaparece de las busquedas a los pocos
-- minutos de minimizar la aplicacion: `find_available_drivers` exige una
-- ubicacion reciente y en segundo plano solo la tarea nativa de `expo-location`
-- puede mandarla. Probado en un iPhone 16 el 2026-11-10: `driver_locations.
-- updated_at` se quedo parado mas de cinco minutos con la app minimizada.
--
-- Lo que no se puede saber desde fuera es POR QUE se detiene: si la tarea ni
-- siquiera se ejecuta (iOS no entrega posiciones), si se ejecuta y el envio
-- falla (red, sesion caducada, RLS), o si el permiso cambio. Esta tabla guarda
-- esos hechos, uno por fila, para poder distinguirlos con una consulta.
--
-- NO ES la ubicacion del conductor: esa sigue siendo `driver_locations`. Esto
-- es un diario tecnico, sin coordenadas.
--
-- Escribe el propio conductor (mismo patron que `driver_locations` y
-- `ride_locations`: no hay nada que validar mas alla de "es mi fila") y solo
-- lee un administrador. Retencion: borrar a mano lo anterior a 14 dias con
-- `delete from public.driver_tracking_events where occurred_at < now() -
-- interval '14 days'`; el volumen es de unas pocas filas por minuto y por
-- conductor mientras esta disponible.
-- =============================================================================

create table public.driver_tracking_events (
  id          bigint generated always as identity primary key,
  driver_id   uuid not null references public.drivers (id) on delete cascade,
  occurred_at timestamptz not null default now(),
  -- 'task' = la tarea en segundo plano; 'app' = la pantalla / el hook.
  source      text not null check (source in ('task', 'app')),
  kind        text not null check (char_length(kind) between 1 and 40),
  platform    text check (platform in ('android', 'ios')),
  -- Libre pero acotado: sin coordenadas, sin datos personales.
  detail      jsonb not null default '{}'::jsonb
                check (pg_column_size(detail) <= 2048)
);

comment on table public.driver_tracking_events is
  'Diario tecnico del seguimiento de ubicacion del conductor (diagnostico, sin coordenadas).';

create index driver_tracking_events_driver_time_idx
  on public.driver_tracking_events (driver_id, occurred_at desc);

alter table public.driver_tracking_events enable row level security;

create policy "driver_tracking_events_insert_own"
  on public.driver_tracking_events for insert to authenticated
  with check (driver_id = (select auth.uid()));

create policy "driver_tracking_events_select_admin"
  on public.driver_tracking_events for select to authenticated
  using (public.is_admin());

-- Sin UPDATE ni DELETE para nadie desde la API: un diario no se reescribe.
