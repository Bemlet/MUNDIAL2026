# Pickem Partido A Partido Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the Pick'em from a tournament simulator into a real-fixture, match-by-match prediction game that feeds Supabase leaderboard correctly.

**Architecture:** Keep `preds` as the single local prediction store and Supabase `predictions` as the backend store. UI must use real fixture teams for prediction availability, especially knockouts, and scoring remains by `match_no` against real results. Group tables, best thirds, and simulated bracket logic remain available for real tournament screens but stop driving Pick'em participation.

**Tech Stack:** Flutter/Dart, `AppState` ChangeNotifier, SharedPreferences, Supabase SQL/view, Flutter widget tests.

---

### Task 1: Lock In Scoring Cutoff And Edit Rules

**Files:**
- Modify: `lib/app_state.dart`
- Modify: `supabase/schema.sql`
- Test: `test/pickem_logic_test.dart`

- [ ] Add tests proving `pickemStart` is `2026-06-17T00:00:00Z`, matches before that do not score, and matches from that date do score when they have a prediction and real result.
- [ ] Change `AppState.pickemStart` from `2026-06-16` to `2026-06-17`.
- [ ] Update `supabase/schema.sql` leaderboard cutoff from `2026-06-16` to `2026-06-17`.
- [ ] Verify `pickemLocked` closes at kickoff (`now >= kickoff` equivalent behavior in app UI; backend already enforces `kickoff > now()`).

### Task 2: Replace Pick'em Simulator UI With Real Match List

**Files:**
- Modify: `lib/screens/prediction_screen.dart`
- Modify: `lib/l10n.dart`
- Test: `test/leaderboard_test.dart`

- [ ] Replace the four-tab simulator (`Groups`, `Best thirds`, `Bracket`, `Ranking`) with a two-tab Pick'em (`Predictions`, `Ranking`).
- [ ] Render all real group matches and knockout matches whose teams are known through `state.realTeams(m)`.
- [ ] Show unresolved knockout matches as locked/unavailable instead of requiring simulated group/bracket completion.
- [ ] Use `state.setPred(match.no, Pred(...))` for all editable matches so Supabase upsert behavior remains unchanged.
- [ ] Keep locked rows showing real score, user's saved pick, and points earned.
- [ ] Remove quick simulation, predicted best thirds, and predicted bracket controls from the Pick'em UI.

### Task 3: Align Match Detail Prediction Editing

**Files:**
- Modify: `lib/screens/match_detail.dart`
- Test: `test/pickem_logic_test.dart` or widget coverage if practical

- [ ] Prevent editing predictions from match detail once `state.pickemLocked(match)` is true.
- [ ] For knockout detail, display saved prediction against real confirmed teams when available.
- [ ] Do not allow editing unresolved knockout fixtures.

### Task 4: Verify Supabase/Leaderboard Contract

**Files:**
- Modify: `supabase/schema.sql`
- Test: `test/leaderboard_test.dart`

- [ ] Confirm `predictions` schema remains unchanged: `user_id`, `match_no`, `home`, `away`, `updated_at`.
- [ ] Confirm `leaderboard` view still scores by `match_no` and `match_results`, with no dependency on predicted standings or bracket.
- [ ] Update comments to explain Pick'em is match-by-match from `2026-06-17` onward.

### Task 5: Verification And APK Build

**Files:**
- Android build output under `build/app/outputs/flutter-apk/`

- [ ] Run `dart format` on changed Dart files and tests.
- [ ] Run targeted Flutter tests covering Pick'em and leaderboard.
- [ ] Run full `flutter test`.
- [ ] Build release APK with `flutter build apk --release`.
- [ ] Report APK path and required Supabase SQL change.

### Self-Review

- Spec coverage: plan covers match-by-match participation, cutoff, knockout real-team availability, Supabase leaderboard, and APK build.
- Placeholder scan: no placeholders remain.
- Type consistency: existing `Pred`, `WcMatch`, `AppState.setPred`, `realTeams`, and `pickemPoints` are reused.
