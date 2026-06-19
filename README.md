<h1 align="center">⚽ Mundial 2026 — Fixture &amp; Pick'em</h1>

<p align="center">
  App móvil del Mundial 2026: calendario real, resultados en vivo, fase de grupos,
  bracket eliminatorio, fichas de equipos y un juego de predicciones con leaderboard.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white">
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white">
  <img src="https://img.shields.io/badge/Material%203-757575?style=for-the-badge&logo=materialdesign&logoColor=white">
</p>

---

## ✨ Características

| | Funcionalidad |
|---|---|
| 📅 | **Calendario completo** con horarios reales (kickoff en tu zona horaria) y sedes |
| 🟢 | **Resultados en vivo**, sincronizados desde la API pública de ESPN |
| 🏆 | **Fase de grupos** con tablas de posiciones calculadas automáticamente |
| 🔢 | **Bracket eliminatorio** desde los playoffs hasta la final |
| 🎯 | **Predicciones (Pick'em)**: pronosticá los marcadores antes del kickoff y sumá puntos (6 exacto · 3 resultado · 0) |
| 📊 | **Leaderboard global** con apodos y países |
| 🌍 | **Fichas de equipos**: ranking FIFA, participaciones, títulos, figuras e historia |
| 🔔 | **Notificaciones** de partidos |
| 🧭 | **Onboarding** y tour guiado para nuevos usuarios |

---

## 🛠️ Stack técnico

- **Frontend:** Flutter 3.x / Dart · Material Design 3 · tipografía variable **Outfit**
- **Estado:** `AppState` con `ChangeNotifier`
- **Backend:** **Supabase** — autenticación, PostgreSQL (con Row Level Security) y Edge Functions
- **Datos en vivo:** Edge Function que ingiere resultados desde la **API pública de ESPN** (el `service_role` se inyecta solo en el backend; el cliente usa la `anon key`, protegida por RLS)
- **Pipeline de datos:** script en **Python** que combina la API de ESPN con el fixture oficial

---

## 🏗️ Arquitectura

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

### Seguridad (RLS)
La base usa **Row Level Security** en todas las tablas: cada usuario solo ve y edita
sus propias predicciones (y solo antes del kickoff), los resultados se escriben únicamente
desde la Edge Function (`service_role`), y el leaderboard se expone mediante una vista que
agrega los puntajes sin filtrar las predicciones individuales.

---

## 🚀 Cómo correrlo

**Requisitos:** Flutter SDK 3.x

```bash
flutter pub get
flutter run
```

Compilar el APK de release:

```bash
flutter build apk --release
```

### Regenerar los datos (opcional)
El fixture y los equipos viven en `assets/data/`. Para regenerarlos:

```bash
python3 tools/build_data.py
```

> Para usar tu propio backend, reemplazá `supabaseUrl` y `supabaseAnonKey` en
> `lib/supabase_config.dart` y corré `supabase/schema.sql` en tu proyecto de Supabase.

---

## 📱 Capturas

> _(Próximamente)_

---

<p align="center">
  Proyecto personal de <b>Ever Mosquera</b> · Hecho con Flutter 💙<br>
  <a href="https://www.linkedin.com/in/ever-mosquera-dev">LinkedIn</a>
</p>
