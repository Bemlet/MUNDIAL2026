# Pickem Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add quick filters to the Pick'em predictions list so users can jump to relevant matches without scrolling through the full fixture.

**Architecture:** Keep filtering local to `PredictionScreen`; no scoring, Supabase, or state persistence changes. Add localized labels in `l10n.dart` and widget coverage in `leaderboard_test.dart`.

**Tech Stack:** Flutter/Dart, `AppState`, widget tests.

---

### Task 1: Filter Model And UI

**Files:**
- Modify: `lib/screens/prediction_screen.dart`
- Modify: `lib/l10n.dart`
- Test: `test/leaderboard_test.dart`

- [ ] Write a failing widget test that renders the six filter chips: Pendientes, Próximos, Hoy, Mis picks, Cerrados, Todos.
- [ ] Add a compact filter chip row above the predictions list.
- [ ] Default to Pendientes.
- [ ] Implement filters:
  - Pendientes: `state.canEditPickem(match)` and no prediction.
  - Próximos: teams are resolved and kickoff is in the future.
  - Hoy: local date equals today.
  - Mis picks: `state.preds.containsKey(match.no)`.
  - Cerrados: not editable and already started or does not count.
  - Todos: no filtering.
- [ ] Show a localized empty state when a filter has no matches.

### Task 2: Verification And Build

**Files:**
- Android APK output under `build/app/outputs/flutter-apk/`

- [ ] Run `dart format` on changed files.
- [ ] Run targeted widget tests.
- [ ] Run `flutter analyze`.
- [ ] Run full `flutter test`.
- [ ] Build release APK with `flutter build apk --release`.

### Self-Review

- Spec coverage: covers all requested filters and APK build.
- Placeholder scan: no placeholders remain.
- Type consistency: uses existing `AppState.canEditPickem`, `preds`, `realTeams`, and `WcMatch.dateUtc`.
