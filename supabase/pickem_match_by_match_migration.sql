-- ============================================================================
-- Pick'em match-by-match migration
-- Run once in the Supabase SQL Editor after deploying the app-side conversion.
-- Safe to re-run: policies/views are replaced and the delete is idempotent.
-- ============================================================================

-- Allow users to clear only their own predictions while the match is editable.
drop policy if exists pred_delete_own on public.predictions;
create policy pred_delete_own on public.predictions for delete using (
  auth.uid() = user_id
  and (select kickoff from public.matches m where m.no = match_no) > now()
);

-- Refresh leaderboard scoring cutoff for the match-by-match Pick'em model.
create or replace view public.leaderboard as
select
  p.id   as user_id,
  p.nickname,
  p.country,
  coalesce(sum(
    case
      when m.kickoff < timestamptz '2026-06-17 00:00:00+00' then 0
      when r.finished is not true then 0
      when pr.home = r.home and pr.away = r.away then 6
      when sign(pr.home - pr.away) = sign(r.home - r.away) then 3
      else 0
    end
  ), 0)::int as points,
  coalesce(sum(
    case when m.kickoff >= timestamptz '2026-06-17 00:00:00+00'
          and r.finished and pr.home = r.home and pr.away = r.away
         then 1 else 0 end
  ), 0)::int as exact_count
from public.profiles p
left join public.predictions  pr on pr.user_id = p.id
left join public.match_results r  on r.match_no = pr.match_no
left join public.matches       m  on m.no = pr.match_no
group by p.id, p.nickname, p.country;

grant select on public.leaderboard to anon, authenticated;

-- Legacy cleanup:
-- Knockout match numbers 73-104 could contain simulator-generated predictions
-- from before match-by-match Pick'em editing existed. Those picks were made
-- without confirmed real teams and can otherwise score later.
-- Adjust this cutoff to the exact production deployment time if needed.
do $$
declare
  match_by_match_cutoff timestamptz := timestamptz '2026-06-17 00:00:00+00';
begin
  delete from public.predictions pr
  where pr.match_no between 73 and 104
    and pr.updated_at < match_by_match_cutoff;
end $$;
