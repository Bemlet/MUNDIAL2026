-- ============================================================================
-- Golazo — Pick'em leaderboard (Supabase)
-- Correr en el SQL Editor de Supabase. Después correr seed_matches.sql.
-- ============================================================================

-- Cutoff del campeonato de aciertos: partidos antes de esta fecha NO puntúan.
-- (Se usa inline en la vista de leaderboard.)

-- ----------------------------------------------------------------- tablas
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  nickname   text not null check (char_length(nickname) between 2 and 24),
  country    text,
  created_at timestamptz not null default now()
);

create table if not exists public.matches (
  no       int primary key,
  espn_id  text unique,
  kickoff  timestamptz not null
);

create table if not exists public.predictions (
  user_id    uuid not null references auth.users(id) on delete cascade,
  match_no   int  not null references public.matches(no),
  home       int  not null check (home between 0 and 30),
  away       int  not null check (away between 0 and 30),
  updated_at timestamptz not null default now(),
  primary key (user_id, match_no)
);

create table if not exists public.match_results (
  match_no   int primary key references public.matches(no),
  home       int not null,
  away       int not null,
  finished   boolean not null default false,
  updated_at timestamptz not null default now()
);

-- --------------------------------------------------------------------- RLS
alter table public.profiles      enable row level security;
alter table public.predictions   enable row level security;
alter table public.matches       enable row level security;
alter table public.match_results enable row level security;

-- profiles: cualquiera lee (para mostrar apodos en el leaderboard); cada uno
-- crea/edita el suyo.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select using (true);
drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles for insert with check (auth.uid() = id);
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update using (auth.uid() = id);

-- predictions: cada uno ve y edita SOLO las suyas, y SOLO antes del kickoff.
drop policy if exists pred_select_own on public.predictions;
create policy pred_select_own on public.predictions for select using (auth.uid() = user_id);
drop policy if exists pred_insert_own on public.predictions;
create policy pred_insert_own on public.predictions for insert with check (
  auth.uid() = user_id
  and (select kickoff from public.matches m where m.no = match_no) > now()
);
drop policy if exists pred_update_own on public.predictions;
create policy pred_update_own on public.predictions for update using (
  auth.uid() = user_id
  and (select kickoff from public.matches m where m.no = match_no) > now()
);

-- matches y match_results: lectura pública. La escritura de resultados es solo
-- vía service_role (la Edge Function), que bypassea RLS — sin policy de write.
drop policy if exists matches_read on public.matches;
create policy matches_read on public.matches for select using (true);
drop policy if exists results_read on public.match_results;
create policy results_read on public.match_results for select using (true);

-- ------------------------------------------------------------- leaderboard
-- Vista (security definer por defecto): agrega las predicciones de TODOS sin
-- exponer las predicciones individuales. 6 exacto / 3 resultado / 0; los
-- partidos previos al 16/jun no puntúan.
create or replace view public.leaderboard as
select
  p.id   as user_id,
  p.nickname,
  p.country,
  coalesce(sum(
    case
      when m.kickoff < timestamptz '2026-06-16 00:00:00+00' then 0
      when r.finished is not true then 0
      when pr.home = r.home and pr.away = r.away then 6
      when sign(pr.home - pr.away) = sign(r.home - r.away) then 3
      else 0
    end
  ), 0)::int as points,
  coalesce(sum(
    case when m.kickoff >= timestamptz '2026-06-16 00:00:00+00'
          and r.finished and pr.home = r.home and pr.away = r.away
         then 1 else 0 end
  ), 0)::int as exact_count
from public.profiles p
left join public.predictions  pr on pr.user_id = p.id
left join public.match_results r  on r.match_no = pr.match_no
left join public.matches       m  on m.no = pr.match_no
group by p.id, p.nickname, p.country;

grant select on public.leaderboard to anon, authenticated;
