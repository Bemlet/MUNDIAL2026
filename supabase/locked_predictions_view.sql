-- ============================================================================
-- Transparencia del Pick'em — vista locked_predictions
-- Correr una vez en el SQL Editor de Supabase.
--
-- Expone las predicciones de TODOS los participantes, pero SOLO de partidos que
-- ya empezaron (kickoff <= now). Así se puede ver, por transparencia, qué puso
-- cada uno y cuánto sumó, sin filtrar los pronósticos de partidos por venir.
--
-- Es una vista (corre con privilegios del owner = postgres), así que saltea la
-- RLS de predictions, igual que la vista leaderboard. No se expone nada de
-- partidos futuros porque el WHERE filtra por kickoff <= now().
-- ============================================================================

create or replace view public.locked_predictions as
select
  pr.user_id,
  pr.match_no,
  pr.home,
  pr.away,
  r.home as result_home,
  r.away as result_away,
  coalesce(r.finished, false) as finished,
  case
    when m.kickoff >= timestamptz '2026-06-17 00:00:00+00'
         and r.finished
         and pr.home = r.home and pr.away = r.away then 6
    when m.kickoff >= timestamptz '2026-06-17 00:00:00+00'
         and r.finished
         and sign(pr.home - pr.away) = sign(r.home - r.away) then 3
    else 0
  end as points
from public.predictions pr
join public.matches       m on m.no = pr.match_no
left join public.match_results r on r.match_no = pr.match_no
where m.kickoff <= now();

grant select on public.locked_predictions to anon, authenticated;
