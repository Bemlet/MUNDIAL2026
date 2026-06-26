-- Analítica de uso: tabla de eventos + RLS + índices + vistas agregadas
-- Aplicada vía Supabase migration "analytics_events_and_views".
-- Diseño: docs/superpowers/specs/2026-06-26-analitica-uso-design.md
--
-- Seguridad:
--   - La tabla vive en `public` para poder insertar con la anon key, pero su
--     única policy es INSERT del propio user_id; no hay SELECT (RLS bloquea
--     lectura desde anon/authenticated).
--   - Las vistas viven en el schema `analytics`, que NO está expuesto por
--     PostgREST. Solo se leen por conexión directa (ej. Metabase con un rol
--     read-only dedicado).

-- 1. Schema separado para vistas (NO expuesto por PostgREST)
create schema if not exists analytics;

-- 2. Tabla de eventos (en public, para insertar vía anon key)
create table if not exists public.analytics_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  session_id  uuid not null,
  event_name  text not null,
  props       jsonb not null default '{}'::jsonb,
  app_version text,
  platform    text,
  created_at  timestamptz not null default now()
);

-- 3. Índices para consultas analíticas
create index if not exists idx_analytics_events_created
  on public.analytics_events (created_at);
create index if not exists idx_analytics_events_name_created
  on public.analytics_events (event_name, created_at);
create index if not exists idx_analytics_events_user_created
  on public.analytics_events (user_id, created_at);

-- 4. RLS: solo INSERT del propio evento; nadie lee vía API
alter table public.analytics_events enable row level security;

create policy analytics_events_insert_own
  on public.analytics_events for insert
  to authenticated
  with check (auth.uid() = user_id);
-- (sin policy SELECT → lectura bloqueada para anon/authenticated)

-- 5. Vistas analíticas (schema analytics, fuera del API)
create or replace view analytics.v_daily_active_users as
  select date_trunc('day', created_at)::date as day,
         count(distinct user_id) as dau
  from public.analytics_events
  group by 1 order by 1;

create or replace view analytics.v_screen_popularity as
  select coalesce(props->>'screen','(desconocida)') as screen,
         date_trunc('day', created_at)::date as day,
         count(*) as views,
         count(distinct user_id) as unique_users
  from public.analytics_events
  where event_name = 'screen_view'
  group by 1,2 order by 2 desc, 3 desc;

create or replace view analytics.v_pickem_engagement as
  select date_trunc('day', created_at)::date as day,
         count(*) filter (where event_name='prediction_created') as picks_created,
         count(*) filter (where event_name='prediction_updated') as picks_updated,
         count(distinct user_id) filter
           (where event_name in ('prediction_created','prediction_updated')) as active_predictors
  from public.analytics_events
  group by 1 order by 1;

create or replace view analytics.v_retention as
  with first_seen as (
    select user_id, min(created_at)::date as cohort_day
    from public.analytics_events group by user_id
  ),
  activity as (
    select distinct user_id, created_at::date as active_day
    from public.analytics_events
  )
  select f.cohort_day,
         (a.active_day - f.cohort_day) as day_offset,
         count(distinct a.user_id) as returning_users
  from first_seen f
  join activity a on a.user_id = f.user_id
  group by 1,2 order by 1,2;

create or replace view analytics.v_errors as
  select coalesce(props->>'context','(sin contexto)') as context,
         app_version,
         date_trunc('day', created_at)::date as day,
         count(*) as errors
  from public.analytics_events
  where event_name = 'app_error'
  group by 1,2,3 order by 3 desc, 4 desc;

-- 6. Defensa en profundidad: revocar todo acceso de los roles del cliente al
--    schema analytics. Aunque PostgREST no lo expone, esto evita una fuga si
--    alguna vez se agrega `analytics` a los schemas expuestos. Solo conexiones
--    directas (Metabase con su rol read-only) deben leer estas vistas.
revoke all on all tables in schema analytics from anon, authenticated;
revoke all on schema analytics from anon, authenticated;
alter default privileges in schema analytics revoke all on tables from anon, authenticated;
