---
title: Arquitectura
icon: lucide/layout-template
---

# Arquitectura

La app sigue un patrón **ChangeNotifier + Provider**: un único estado global
(`AppState`) es el *source of truth*, y las pantallas escuchan los cambios con
`Consumer`/`Provider`.

## Vista general

``` mermaid
graph TD
    UI[Pantallas Flutter<br/>groups · matches · bracket · prediction<br/>teams · players · stats] --> AS[AppState<br/>ChangeNotifier]
    AS --> SS[supabase_service.dart<br/>auth · picks · transparencia]
    AS --> LG[logic.dart<br/>grupos · bracket · puntajes]
    AS --> US[update_service.dart<br/>actualizaciones in-app]
    SS --> SB[(Supabase<br/>PostgreSQL + RLS + vistas)]
    US --> ST[Supabase Storage<br/>version.json + APK]
    EF[Edge Function<br/>ingest-results] --> SB
    ESPN[API pública ESPN] --> EF
    PY[tools/build_data.py] --> AD[assets/data<br/>teams.json · matches.json · players.json]
    AD --> AS
    WIKI[Wikipedia / Wikimedia] -.bio + foto on-demand.-> AS
```

## Estructura del código

```
lib/
├── main.dart                 # entrypoint + navegación
├── app_state.dart            # estado global (ChangeNotifier)
├── models.dart               # modelos (equipos, partidos, predicciones)
├── players.dart              # dataset curado de jugadores (atributos, bio)
├── logic.dart  · stats.dart  # grupos/bracket/puntajes · estadísticas
├── theme.dart  · l10n.dart   # tema Material 3 · localización
├── supabase_service.dart     # auth (anónima + Google), picks, leaderboard, transparencia
├── update_service.dart       # actualizaciones in-app (version.json + APK)
├── notification_service.dart # notificaciones y recordatorio de picks
├── supabase_config.dart      # URL + anon key (pública por diseño)
├── widgets.dart  · widgets/  # componentes compartidos
└── screens/                  # groups · matches · match_detail · bracket
                              # prediction · stats · teams · team_detail
                              # player_detail · onboarding
supabase/
├── schema.sql                    # tablas + políticas RLS + vista leaderboard
├── locked_predictions_view.sql   # vista de transparencia (picks post-kickoff)
├── pickem_match_by_match_migration.sql  # migración del Pick'em
├── seed_matches.sql              # carga inicial de partidos
└── functions/ingest-results/     # Edge Function: ESPN → match_results
tools/
└── build_data.py             # genera teams.json, matches.json y players.json
```

## Principios de diseño

- **Material Design 3** en toda la app, con tipografía variable **Outfit**.
- **`AppState` como único *source of truth*** — no hay estado local salvo UI efímera.
- **Datos de fixture estáticos** en `assets/data/` como JSON; los datos en vivo
  llegan desde Supabase.
- **Localización** vía `l10n.dart` — sin strings hardcodeados en los widgets.

## Capas

| Capa | Responsabilidad |
|---|---|
| **Pantallas** (`screens/`) | UI y navegación; escuchan a `AppState` |
| **Estado** (`app_state.dart`) | Orquesta datos, expone el estado a la UI |
| **Lógica** (`logic.dart`, `stats.dart`) | Motor de simulación: grupos, bracket, puntajes y estadísticas |
| **Servicios** (`supabase_service.dart`) | Auth (anónima + Google), predicciones, leaderboard y transparencia |
| **Actualizaciones** (`update_service.dart`) | Chequea `version.json` en Supabase Storage; descarga e instala el APK |
| **Backend** (`supabase/`) | PostgreSQL con RLS + vistas + Edge Function de ingesta |
