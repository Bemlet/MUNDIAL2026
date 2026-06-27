-- Pick'em Fase Final: rankings separados Grupos / Fase Final.
-- Aplicada vía Supabase migration "pickem_fase_final".
-- Diseño: docs/superpowers/specs/2026-06-27-pickem-fase-final-design.md
--
-- Reglas de puntaje:
--   - Grupos: 6 (marcador exacto) / 3 (resultado) / 0, solo stage='group', cutoff 17-jun.
--   - Fase Final: el 6/3 base se MULTIPLICA por ronda → r32 x1, r16 x2, qf x4,
--     sf x8, final x16; 3er puesto (third) x1 (consolación).
--   - Penales: cuentan por el marcador (empate); sin bonus por clasificado.
--   - Los dos rankings son independientes: knockout nunca suma al de Grupos.

-- 1. Columna stage en matches + poblar (rangos fijos del fixture del Mundial 2026:
--    grupos 1-72, r32 73-88, r16 89-96, qf 97-100, sf 101-102, third 103, final 104).
alter table public.matches add column if not exists stage text;
update public.matches set stage = case
  when no between 1 and 72    then 'group'
  when no between 73 and 88   then 'r32'
  when no between 89 and 96   then 'r16'
  when no between 97 and 100   then 'qf'
  when no between 101 and 102  then 'sf'
  when no = 103 then 'third'
  when no = 104 then 'final'
end;

-- 2. leaderboard: SOLO fase de grupos (deja de sumar knockout).
create or replace view public.leaderboard as
 select p.id as user_id, p.nickname, p.country,
   coalesce(sum(case
     when m.stage <> 'group' then 0
     when m.kickoff < '2026-06-17 00:00:00+00'::timestamptz then 0
     when r.finished is not true then 0
     when pr.home = r.home and pr.away = r.away then 6
     when sign((pr.home - pr.away)::float) = sign((r.home - r.away)::float) then 3
     else 0 end), 0)::int as points,
   coalesce(sum(case
     when m.stage = 'group' and m.kickoff >= '2026-06-17 00:00:00+00'::timestamptz
       and r.finished and pr.home = r.home and pr.away = r.away then 1
     else 0 end), 0)::int as exact_count
 from profiles p
 left join predictions pr on pr.user_id = p.id
 left join match_results r on r.match_no = pr.match_no
 left join matches m on m.no = pr.match_no
 group by p.id, p.nickname, p.country;

-- 3. leaderboard_final: knockout con multiplicador por ronda.
create or replace view public.leaderboard_final as
 select p.id as user_id, p.nickname, p.country,
   coalesce(sum(
     case when m.stage in ('r32','r16','qf','sf','third','final') and r.finished then
       (case
          when pr.home = r.home and pr.away = r.away then 6
          when sign((pr.home - pr.away)::float) = sign((r.home - r.away)::float) then 3
          else 0 end)
       * (case m.stage
            when 'r32' then 1 when 'r16' then 2 when 'qf' then 4
            when 'sf' then 8 when 'final' then 16 when 'third' then 1
            else 0 end)
     else 0 end), 0)::int as points,
   coalesce(sum(case
     when m.stage in ('r32','r16','qf','sf','third','final') and r.finished
       and pr.home = r.home and pr.away = r.away then 1
     else 0 end), 0)::int as exact_count
 from profiles p
 left join predictions pr on pr.user_id = p.id
 left join match_results r on r.match_no = pr.match_no
 left join matches m on m.no = pr.match_no
 group by p.id, p.nickname, p.country;

grant select on public.leaderboard_final to anon, authenticated;

-- 4. locked_predictions: puntos por pick con multiplicador en knockout (transparencia).
create or replace view public.locked_predictions as
 select pr.user_id, pr.match_no, pr.home, pr.away,
   r.home as result_home, r.away as result_away,
   coalesce(r.finished, false) as finished,
   case
     when not (m.kickoff >= '2026-06-17 00:00:00+00'::timestamptz and r.finished) then 0
     else
       (case
          when pr.home = r.home and pr.away = r.away then 6
          when sign((pr.home - pr.away)::float) = sign((r.home - r.away)::float) then 3
          else 0 end)
       * (case m.stage
            when 'r16' then 2 when 'qf' then 4 when 'sf' then 8 when 'final' then 16
            else 1 end)  -- group, r32, third → x1
   end as points
 from predictions pr
 join matches m on m.no = pr.match_no
 left join match_results r on r.match_no = pr.match_no
 where m.kickoff <= now();
