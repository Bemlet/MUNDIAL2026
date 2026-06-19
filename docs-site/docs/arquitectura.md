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
    UI[Pantallas Flutter<br/>groups · matches · bracket · prediction · teams] --> AS[AppState<br/>ChangeNotifier]
    AS --> SS[supabase_service.dart]
    AS --> LG[logic.dart<br/>grupos · bracket · puntajes]
    SS --> SB[(Supabase<br/>PostgreSQL + RLS)]
    EF[Edge Function<br/>ingest-results] --> SB
    ESPN[API pública ESPN] --> EF
    PY[tools/build_data.py] --> AD[assets/data<br/>teams.json · matches.json]
    AD --> AS
```

## Estructura del código

```
lib/
├── main.dart                 # entrypoint + navegación
├── app_state.dart            # estado global (ChangeNotifier)
├── models.dart               # modelos (equipos, partidos, predicciones)
├── logic.dart                # cálculo de grupos, bracket y puntajes
├── theme.dart  · l10n.dart   # tema Material 3 · localización
├── supabase_service.dart     # auth, predicciones y leaderboard
├── notification_service.dart # notificaciones de partidos
└── screens/                  # groups · matches · bracket · prediction
                              # stats · teams · team_detail · onboarding
supabase/
├── schema.sql                # tablas + políticas RLS + vista leaderboard
└── functions/ingest-results/ # Edge Function: ESPN → match_results
tools/
└── build_data.py             # genera teams.json y matches.json
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
| **Lógica** (`logic.dart`) | Motor de simulación: grupos, bracket, puntajes |
| **Servicios** (`supabase_service.dart`) | Auth, predicciones y leaderboard |
| **Backend** (`supabase/`) | PostgreSQL con RLS + Edge Function de ingesta |
