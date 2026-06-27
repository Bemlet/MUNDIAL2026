# Pick'em Fase Final — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`).

**Goal:** Crear un Pick'em "Fase Final" con leaderboard y puntaje propios (6/3 que se duplica por ronda), separado del de Grupos, con el perfil mostrando la fase activa y un push de reenganche al iniciar 16vos.

**Architecture:** El puntaje de eliminatorias = puntaje base (6/3/0) × multiplicador por ronda. Dos rankings independientes: Grupos (solo `stage=group`) y Fase Final (knockout, con multiplicador). Backend en Supabase (vistas + columna `stage`); lógica + UI en Flutter.

**Tech Stack:** Flutter/Dart, Supabase (Postgres + vistas), `supabase_flutter`.

## Global Constraints

- Multiplicador por ronda (sobre el 6/3 base): **r32 ×1, r16 ×2, qf ×4, sf ×8, final ×16, third ×1**. Grupos sin multiplicador.
- Tabla de puntos resultante por ronda: 16vos 6/3 · 8vos 12/6 · 4tos 24/12 · semis 48/24 · final 96/48 · 3er puesto 6/3.
- Grupos cuenta SOLO `stage='group'`. Fase Final cuenta SOLO knockout (`r32,r16,qf,sf,third,final`). Nunca se mezclan.
- El perfil muestra el total de la **fase activa** (Grupos hasta que arranca el knockout; Fase Final después). Trigger de fase activa: `now >= ` primer kickoff de un partido knockout.
- Cutoff pickem grupos: `2026-06-17` (existente, no tocar para grupos).
- Material 3; strings vía `l10n.dart`; sin hardcodear español en widgets. TDD. `flutter test` verde antes de PR.
- `Stage` enum: `group, r32, r16, qf, sf, third, finalMatch`. JSON usa string `'final'` para `finalMatch`. `isKnockout = stage != group`.

---

### Task 1: Backend Supabase — columna `stage` + vistas (Grupos / Fase Final)

**Aplica:** vía MCP `apply_migration` (lo ejecuta el orquestador, NO un subagente). Versionar el SQL en `supabase/pickem_fase_final_migration.sql`.

**Interfaces que produce:**
- `public.matches.stage` (text) poblado.
- Vista `public.leaderboard` redefinida → `points` = SOLO grupos.
- Vista nueva `public.leaderboard_final` → `user_id, nickname, country, points, exact_count` (knockout con multiplicador).
- Vista `public.locked_predictions` → `points` por pick con multiplicador aplicado en knockout.

- [ ] **Step 1: Agregar y poblar `stage`**

```sql
alter table public.matches add column if not exists stage text;
update public.matches set stage = case
  when no between 1 and 72   then 'group'
  when no between 73 and 88  then 'r32'
  when no between 89 and 96  then 'r16'
  when no between 97 and 100  then 'qf'
  when no between 101 and 102 then 'sf'
  when no = 103 then 'third'
  when no = 104 then 'final'
end;
-- Verificación: deben dar 72/16/8/4/2/1/1
-- select stage, count(*) from public.matches group by stage;
```

- [ ] **Step 2: Redefinir `leaderboard` (solo grupos)**

```sql
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
```

- [ ] **Step 3: Crear `leaderboard_final` (knockout con multiplicador)**

```sql
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
-- Mismos grants que leaderboard (lo usa el cliente con anon key):
grant select on public.leaderboard_final to anon, authenticated;
```

- [ ] **Step 4: Actualizar `locked_predictions` (puntos por pick con multiplicador)**

```sql
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
            else 1 end)  -- group, r32 y third → ×1
   end as points
 from predictions pr
 join matches m on m.no = pr.match_no
 left join match_results r on r.match_no = pr.match_no
 where m.kickoff <= now();
```

- [ ] **Step 5: Verificar y versionar**

Ejecutar `get_advisors(security)` (sin issues nuevos). Guardar el SQL completo en `supabase/pickem_fase_final_migration.sql` y commit:
```bash
git add supabase/pickem_fase_final_migration.sql
git commit -m "feat: backend Pick'em fase final (stage en matches + vistas grupos/final con multiplicador)"
```

---

### Task 2: Lógica de puntaje por ronda en Dart (logic + AppState)

**Files:**
- Modify: `lib/logic.dart` (multiplicador por ronda)
- Modify: `lib/app_state.dart` (totales grupos/final + fase activa)
- Test: `test/app_state_test.dart`

**Interfaces:**
- Produces:
  - `int roundMultiplier(Stage stage)` en `logic.dart` → r32:1, r16:2, qf:4, sf:8, finalMatch:16, third:1, group:1.
  - `AppState.pickemTotalGroups` → int (base 6/3/0, solo `stage==group`, respeta cutoff 17-jun).
  - `AppState.pickemTotalFinal` → int (knockout, `scorePick × roundMultiplier`).
  - `AppState.finalPhaseActive` → bool (`now >= ` primer kickoff knockout).
  - `AppState.pickemTotal` pasa a devolver el total de la **fase activa** (final si `finalPhaseActive`, si no grupos).

- [ ] **Step 1: Test que falla** (en `test/app_state_test.dart`)

```dart
test('fase final: puntaje se multiplica por ronda', () async {
  SharedPreferences.setMockInitialValues({});
  final s = AppState();
  await s.load(initialSync: false);

  // Partido de r16 (octavos, ×2): marcador exacto = 6*2 = 12
  final r16 = s.matches.firstWhere((m) => m.stage == Stage.r16);
  s.live[r16.espnId] = LiveInfo(homeScore: 2, awayScore: 1, isFinished: true);
  s.preds[r16.no] = Pred(2, 1);
  expect(s.pickemPointsFinal(r16), 12);

  // 3er puesto (×1): exacto = 6
  final third = s.matches.firstWhere((m) => m.stage == Stage.third);
  s.live[third.espnId] = LiveInfo(homeScore: 0, awayScore: 0, isFinished: true);
  s.preds[third.no] = Pred(0, 0);
  expect(s.pickemPointsFinal(third), 6);

  // Grupos NO entra en el total final
  expect(s.pickemTotalFinal >= 12 + 6, isTrue);
});
```
> Ajustar nombres de `LiveInfo`/`Pred` a las firmas reales (ver tests existentes de pickem que ya setean `live`/`preds`).

- [ ] **Step 2: Correr y ver fallar.** `flutter test test/app_state_test.dart` → FAIL.

- [ ] **Step 3: `roundMultiplier` en `logic.dart`**

```dart
/// Multiplicador de puntos por ronda en la fase final (el 6/3 base se duplica
/// cada ronda). Grupos y 3er puesto = ×1.
int roundMultiplier(Stage stage) => switch (stage) {
  Stage.r16 => 2,
  Stage.qf => 4,
  Stage.sf => 8,
  Stage.finalMatch => 16,
  _ => 1, // group, r32, third
};
```

- [ ] **Step 4: Totales y fase activa en `app_state.dart`**

Junto a `pickemPoints`/`pickemTotal` (líneas ~858-889):

```dart
/// Puntos del pick'em de GRUPOS (base, solo fase de grupos, respeta cutoff).
int pickemPointsGroups(WcMatch m) {
  if (m.stage != Stage.group || !pickemCounts(m)) return 0;
  final pred = preds[m.no];
  final real = realPredFor(m);
  if (pred == null || real == null) return 0;
  return scorePick(pred, real);
}

/// Puntos del pick'em de FASE FINAL (knockout, con multiplicador por ronda).
int pickemPointsFinal(WcMatch m) {
  if (!m.isKnockout) return 0;
  final pred = preds[m.no];
  final real = realPredFor(m);
  if (pred == null || real == null) return 0;
  return scorePick(pred, real) * roundMultiplier(m.stage);
}

int get pickemTotalGroups {
  var t = 0;
  for (final m in matches) t += pickemPointsGroups(m);
  return t;
}

int get pickemTotalFinal {
  var t = 0;
  for (final m in matches) t += pickemPointsFinal(m);
  return t;
}

/// La fase final está activa cuando ya empezó el primer partido de knockout.
bool get finalPhaseActive {
  final firstKo = matches
      .where((m) => m.isKnockout)
      .map((m) => m.dateUtc)
      .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
  return firstKo != null && !DateTime.now().toUtc().isBefore(firstKo);
}

/// La fase de grupos concluyó (se congela el ranking de grupos) cuando arranca
/// el knockout. Se usa para coronar al Campeón de Grupos.
bool get groupsConcluded => finalPhaseActive;

/// El torneo terminó cuando el partido final (Stage.finalMatch) está finalizado.
/// Se usa para coronar al Campeón del torneo (ranking de fase final).
bool get tournamentOver {
  final fin = matches.where((m) => m.stage == Stage.finalMatch);
  if (fin.isEmpty) return false;
  final m = fin.first;
  return realPredFor(m) != null; // realPredFor != null ⇒ partido finalizado
}
```
> `realPredFor` ya devuelve no-null solo si el partido terminó (ver su definición). Si hay una vía más directa de "partido finalizado" (`liveFor(m)?.isFinished`), usar esa.

Y `pickemTotal` (existente) pasa a:
```dart
int get pickemTotal => finalPhaseActive ? pickemTotalFinal : pickemTotalGroups;
```
> Si `pickemTotal`/`pickemBreakdown` ya existían con otra firma, mantené la firma y solo cambiá la fuente para `pickemTotal`. Revisar `pickemBreakdown` para que también respete la fase activa (exactos de la fase activa).

- [ ] **Step 5: Correr tests.** `flutter test test/app_state_test.dart` → PASS. Verificar que los tests viejos de pickem (6/3/0 grupos) siguen verdes.

- [ ] **Step 6: Commit**
```bash
git add lib/logic.dart lib/app_state.dart test/app_state_test.dart
git commit -m "feat: puntaje pick'em fase final con multiplicador por ronda + fase activa"
```

---

### Task 3: SupabaseService — fetch del leaderboard de fase final

**Files:**
- Modify: `lib/supabase_service.dart`
- Modify: `lib/app_state.dart` (wrapper si `fetchLeaderboard` se expone vía AppState)

**Interfaces:**
- Consumes: vista `leaderboard_final` (Task 1).
- Produces: `SupabaseService.fetchLeaderboardFinal()` → `Future<List<LeaderEntry>>` (misma forma que `fetchLeaderboard`, columnas `user_id, nickname, points, exact_count`, mismo orden/limit). Y `AppState.fetchLeaderboardFinal()` si el patrón actual expone `fetchLeaderboard` desde AppState.

- [ ] **Step 1: Implementar `fetchLeaderboardFinal`** copiando `fetchLeaderboard` (líneas 207-230) pero `.from('leaderboard_final')`. Reusar el modelo `LeaderEntry` y `sortLeaderboardForDisplay`.

- [ ] **Step 2: Exponer desde AppState** igual que `fetchLeaderboard` (si aplica).

- [ ] **Step 3: Análisis estático.** `flutter analyze` limpio.

- [ ] **Step 4: Commit**
```bash
git add lib/supabase_service.dart lib/app_state.dart
git commit -m "feat: fetchLeaderboardFinal (ranking de fase final desde Supabase)"
```

---

### Task 4: UI — dos rankings con prominencia + perfil por fase activa

**Files:**
- Modify: `lib/screens/prediction_screen.dart`
- Modify: `lib/l10n.dart`

**Interfaces:**
- Consumes: `AppState.pickemTotal` (ya = fase activa), `finalPhaseActive`, `fetchLeaderboard`, `fetchLeaderboardFinal`.

- [ ] **Step 1: Strings en `l10n.dart`**

```dart
String get groupsRankingTab => isEn ? 'Groups' : 'Grupos';
String get finalRankingTab => isEn ? 'Final phase' : 'Fase Final';
String get yourScoreFinal => isEn ? 'Your score · Final phase' : 'Tu puntaje · Fase Final';
String get yourScoreGroups => isEn ? 'Your score · Groups' : 'Tu puntaje · Grupos';
String get leaderLabel => isEn ? 'Leader' : 'Líder';
String get groupsChampionLabel => isEn ? 'Groups champion' : 'Campeón de Grupos';
String get tournamentChampionLabel => isEn ? 'Tournament champion' : 'Campeón del torneo';
```

- [ ] **Step 2: Dos rankings en `_LeaderboardTab`**

Dentro de la tab "Ranking", agregar un sub-selector (sub-`TabBar` o `SegmentedButton`) **Grupos / Fase Final**:
- "Grupos" → `fetchLeaderboard()`.
- "Fase Final" → `fetchLeaderboardFinal()`.
- **Prominencia:** si `state.finalPhaseActive`, el sub-tab por defecto = **Fase Final**; si no, Grupos. La de Fase Final puede destacarse (ej. ícono 🏆 / color de acento).
- Reusar `_LeaderRow` / orden existente para ambos.

- [ ] **Step 3: Banner de Campeón / Líder en cada ranking**

Arriba de cada ranking, mostrar al **#1** (primer `LeaderEntry` ya ordenado) en un banner destacado:
- **Grupos:** etiqueta `l.groupsChampionLabel` (🏆) si `state.groupsConcluded`; si no, `l.leaderLabel`.
- **Fase Final:** etiqueta `l.tournamentChampionLabel` (🏆) si `state.tournamentOver`; si no, `l.leaderLabel`.
- Si la lista está vacía, no mostrar banner.

```dart
final isChampion = isFinalTab ? state.tournamentOver : state.groupsConcluded;
final label = isFinalTab
    ? (state.tournamentOver ? l.tournamentChampionLabel : l.leaderLabel)
    : (state.groupsConcluded ? l.groupsChampionLabel : l.leaderLabel);
// banner con trophy si isChampion, mostrando entries.first.nickname y points
```

- [ ] **Step 4: Header "Tu puntaje" según fase activa**

Donde hoy se muestra `state.pickemTotal` con el label "Tu puntaje" (prediction_screen.dart ~líneas 20-22), usar el label según fase:
```dart
final scoreLabel = state.finalPhaseActive ? l.yourScoreFinal : l.yourScoreGroups;
```
`state.pickemTotal` ya devuelve el total de la fase activa (Task 2).

- [ ] **Step 5: analyze + test**

`flutter analyze` limpio; `flutter test` verde. Los tests de `leaderboard_test.dart` que buscan 'Ranking'/'Tu puntaje' deben seguir pasando (si el texto exacto "Tu puntaje" cambió, actualizar el test o mantener el prefijo).

- [ ] **Step 6: Commit**
```bash
git add lib/screens/prediction_screen.dart lib/l10n.dart
git commit -m "feat: UI rankings Grupos/Fase Final + campeón/líder + perfil por fase activa"
```

---

### Task 5: Push de reenganche al iniciar la fase final

**Files:**
- Modify: `lib/app_state.dart`
- Modify: `lib/l10n.dart` (texto del push)

**Interfaces:**
- Consumes: `finalPhaseActive`, `_notifyOnce` (patrón existente líneas 772-784), `NotificationService`.

- [ ] **Step 1: Strings del push en `l10n.dart`**
```dart
String get finalPhaseNudgeTitle => isEn ? 'Clean slate 🏆' : 'Borrón y cuenta nueva 🏆';
String get finalPhaseNudgeBody => isEn
  ? 'The knockouts are here — everyone starts at 0. Make your final-phase picks!'
  : 'Empiezan las eliminatorias — todos arrancan en 0. ¡Hacé tus picks de la fase final!';
```

- [ ] **Step 2: Disparar el push una sola vez**

En el método de chequeo de recordatorios (junto a `checkPickemReminder()`/`checkMatchReminders()`), cuando `finalPhaseActive` es true:
```dart
if (finalPhaseActive) {
  await _notifyOnce(
    key: 'fase_final_nudge',
    id: 500001,
    title: l10n.finalPhaseNudgeTitle,
    body: l10n.finalPhaseNudgeBody,
  );
}
```
`_notifyOnce` ya deduplica por `key`, así que solo se manda una vez.

- [ ] **Step 3: analyze + test.** `flutter analyze` limpio; `flutter test` verde.

- [ ] **Step 4: Commit**
```bash
git add lib/app_state.dart lib/l10n.dart
git commit -m "feat: push de reenganche al iniciar la fase final"
```

---

## Verificación final
- [ ] `flutter analyze` sin issues; `flutter test` todo verde.
- [ ] Confirmar en Supabase: `select stage, count(*) from matches group by stage` da 72/16/8/4/2/1/1.
- [ ] `leaderboard` ya NO suma knockout; `leaderboard_final` aplica multiplicador correcto.
- [ ] Perfil muestra Grupos antes del knockout y Fase Final después.

## Fuera de alcance
- Bola de cristal (campeón/finalistas por adelantado).
- Bracket completo estilo LoL (acertar quién avanza).
- Ligas privadas / multi-competición (estrategia evergreen).
