// Golazo — ingesta de resultados reales desde ESPN a match_results.
// Deploy:  supabase functions deploy ingest-results
// Programar (cron) cada ~5 min desde el dashboard de Supabase (Schedules) o pg_cron.
//
// Usa SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY, que Supabase inyecta solo en las
// Edge Functions desplegadas — NO hay que pegar la secret key en ningún lado.
// El service_role bypassea RLS para poder escribir match_results.

import { createClient } from "jsr:@supabase/supabase-js@2";

const ESPN_URL =
  "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard?dates=20260611-20260719&limit=200";

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Mapa espn_id -> no (desde la tabla matches sembrada).
  const { data: matches, error: mErr } = await supabase
    .from("matches")
    .select("no, espn_id");
  if (mErr) {
    return new Response(JSON.stringify({ error: mErr.message }), { status: 500 });
  }
  const byEspn = new Map<string, number>();
  for (const m of matches ?? []) {
    if (m.espn_id) byEspn.set(String(m.espn_id), m.no);
  }

  const data = await (await fetch(ESPN_URL)).json();
  const rows: Record<string, unknown>[] = [];
  for (const e of data.events ?? []) {
    const no = byEspn.get(String(e.id));
    if (!no) continue;
    const comp = e.competitions?.[0];
    const type = comp?.status?.type ?? e.status?.type ?? {};
    const finished = type.completed === true || type.state === "post";
    let home: number | null = null;
    let away: number | null = null;
    for (const c of comp?.competitors ?? []) {
      const score = parseInt(c.score);
      if (c.homeAway === "home") home = Number.isNaN(score) ? null : score;
      else away = Number.isNaN(score) ? null : score;
    }
    if (home === null || away === null) continue;
    rows.push({
      match_no: no,
      home,
      away,
      finished,
      updated_at: new Date().toISOString(),
    });
  }

  if (rows.length) {
    const { error } = await supabase
      .from("match_results")
      .upsert(rows, { onConflict: "match_no" });
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }
  }

  return new Response(JSON.stringify({ updated: rows.length }), {
    headers: { "Content-Type": "application/json" },
  });
});
