-- Vistas de detalle para Metabase: QUIÉN está activo (no solo cuántos) y el
-- MENSAJE real de los errores (no solo el conteo). Viven en el schema analytics
-- (fuera de la API), legibles por el rol metabase_ro.

-- Usuarios activos con identidad (nickname del perfil; (anónimo) si no tiene).
create or replace view analytics.v_active_users as
select
  date_trunc('day', e.created_at)::date as day,
  coalesce(p.nickname, '(anónimo)') as nickname,
  e.user_id,
  count(*) as eventos,
  count(*) filter (where e.event_name = 'screen_view') as pantallas,
  min(e.platform) as plataforma,
  max(e.created_at) as ultima_actividad
from public.analytics_events e
left join public.profiles p on p.id = e.user_id
group by 1, p.nickname, e.user_id
order by day desc, eventos desc;

-- Detalle de errores: el mensaje real agrupado, con conteo y última vez.
create or replace view analytics.v_errors_detail as
select
  coalesce(props->>'context', '(sin contexto)') as context,
  coalesce(props->>'message', '(sin mensaje)') as message,
  app_version,
  count(*) as veces,
  max(created_at) as ultima_vez
from public.analytics_events
where event_name = 'app_error'
group by 1, 2, app_version
order by veces desc, ultima_vez desc;

grant select on analytics.v_active_users to metabase_ro;
grant select on analytics.v_errors_detail to metabase_ro;
