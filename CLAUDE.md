# Mundial 2026 — Claude Code Workspace

## Proyecto

App Flutter de fixture y simulador del Mundial 2026 con backend Supabase. Calendario real, resultados en vivo, predicciones (Pick'em) y leaderboard.

- **Stack**: Flutter 3.x / Dart, Material Design 3, Supabase (PostgreSQL + RLS + Edge Function)
- **Datos**: JSON estático en `assets/data/` (`teams.json`, `matches.json`, `players.json`), banderas en `assets/flags/`; datos en vivo y predicciones desde Supabase
- **Estado**: `AppState` (ChangeNotifier) en `lib/app_state.dart`
- **Pantallas**: groups, matches, match_detail, bracket, prediction, stats, teams, team_detail, player_detail, onboarding
- **Font**: Outfit Variable

## Ecosistema de desarrollo

Este proyecto usa **Superpowers + Gentle-AI + plugins oficiales** integrados en el flujo de trabajo.

### Qué hay instalado

| Herramienta | Rol |
|---|---|
| **Superpowers** | Metodología: brainstorming → plan → TDD → review → merge |
| **Gentle-AI SDD** | Spec-Driven Development para features grandes (>1 pantalla o cambio de arquitectura) |
| **Engram** | Memoria persistente entre sesiones — guarda decisiones, bugs resueltos, patrones |
| **security-guidance** | Review de seguridad automático en cada edit/commit |
| **code-review** | Review multi-agente en PRs (`/code-review`) |
| **feature-dev** | Workflow guiado de 7 fases para features (`/feature-dev`) |

### Cuándo usar cada flujo

```
Tarea pequeña (fix, ajuste visual, texto)
  → Directo. Superpowers aún aplica TDD para bugfixes.

Feature nueva (componente, pantalla, lógica)
  → /feature-dev  (7 fases: discovery → design → implement → review)
  → O manual: Skill brainstorming → writing-plans → executing-plans

Feature grande (nueva sección, arquitectura, integración de datos)
  → /sdd-init  (Spec-Driven: explore → propose → spec → design → tasks → apply → verify)

PR listo para review
  → /code-review  (4 agentes paralelos: compliance, bugs, blame, estructura)
```

### Skills disponibles (Skill tool)

**Superpowers**
- `brainstorming` — diseño antes de codear (SIEMPRE antes de features)
- `writing-plans` — plan de implementación paso a paso
- `executing-plans` — ejecutar plan con subagentes
- `test-driven-development` — RED→GREEN→REFACTOR estricto
- `systematic-debugging` — debugging sin adivinanzas
- `verification-before-completion` — verificar antes de marcar done
- `dispatching-parallel-agents` — lanzar subagentes en paralelo
- `requesting-code-review` / `receiving-code-review` — protocolo de review
- `using-git-worktrees` — branches aislados por feature
- `finishing-a-development-branch` — cierre limpio de branch
- `subagent-driven-development` — delegar a subagentes especializados
- `using-superpowers` — bootstrap (se carga automáticamente al inicio)

**Gentle-AI**
- `sdd-init` / `sdd-explore` / `sdd-propose` / `sdd-spec` / `sdd-design` / `sdd-tasks` / `sdd-apply` / `sdd-verify` / `sdd-archive` — fases SDD
- `work-unit-commits` — commits como unidades de trabajo revisables
- `cognitive-doc-design` — docs con bajo carga cognitiva
- `branch-pr` — crear branches y PRs correctamente
- `chained-pr` — PRs encadenados para cambios grandes
- `judgment-day` — review de calidad con múltiples jueces
- `skill-registry` — catálogo de skills disponibles

### Comandos disponibles

```bash
/sdd-init       # Inicializar SDD en este proyecto
/sdd-new        # Comenzar nueva feature con SDD
/sdd-continue   # Retomar SDD en progreso
/sdd-status     # Estado actual de SDD
/sdd-explore    # Fase de exploración
/sdd-apply      # Fase de implementación
/sdd-verify     # Fase de verificación
/sdd-archive    # Archivar feature completada
/feature-dev    # Workflow de 7 fases para features
/code-review    # Review multi-agente del PR actual
```

## Reglas del proyecto

### Flutter/Dart
- Material Design 3 en toda la app
- `AppState` como único source of truth — no estado local salvo UI efímera
- Assets de datos siempre en `assets/data/` como JSON
- Localización via `l10n.dart` — no hardcodear strings en español en widgets
- Banderas: `assets/flags/{código_país_3_letras}.png`

### Git
- Commits en Conventional Commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`
- Un commit por unidad de trabajo (ver skill `work-unit-commits`)
- Branches: `feat/nombre-feature`, `fix/descripcion-bug`
- Sin `Co-Authored-By` trailers en commits

### Testing
- Flutter test para widgets y lógica de negocio
- RED→GREEN→REFACTOR — nunca escribir código antes del test fallido
- `flutter test` debe pasar antes de cualquier PR

### Memoria (Engram)
- Engram guarda automáticamente decisiones de arquitectura, bugs resueltos, convenciones
- Al inicio de sesión busca contexto previo del proyecto
- Al final de sesión llama `mem_session_summary`

## Contexto técnico importante

- Backend en **Supabase**: PostgreSQL con RLS en todas las tablas, una Edge Function (`ingest-results`) que sincroniza resultados desde la API de ESPN con `service_role`, y vistas (`leaderboard`, `locked_predictions`). El cliente usa solo la `anon key` (pública por diseño); el `service_role` nunca se expone
- El **fixture y los equipos** sí son estáticos (`assets/data/*.json`, generados por `tools/build_data.py`); los **resultados en vivo, predicciones y leaderboard** vienen de Supabase
- **Auth** (`supabase_service.dart`): sesión anónima por defecto, con vinculación opcional a Google (OAuth) para recuperar picks entre dispositivos
- **Privacidad del Pick'em**: predicciones privadas hasta el kickoff (RLS); públicas después vía la vista `locked_predictions` (transparencia del ranking)
- **Actualizaciones in-app** (`update_service.dart`): chequea `version.json` en Supabase Storage y descarga/instala el APK split arm64
- `NotificationService` maneja notificaciones locales de partidos y el recordatorio de picks pendientes del día
- `logic.dart` contiene el motor de simulación del torneo; `stats.dart`, las estadísticas
- `players.dart` + `assets/data/players.json`: cartas de jugadores (atributos curados) con foto/bio de Wikipedia on-demand
- Arquitectura: ChangeNotifier → screens escuchan con Consumer/Provider pattern

## Privacidad / Seguridad

El security-guidance plugin revisa automáticamente cada edición y commit.
Archivos protegidos (nunca leer/editar): `.env`, `.env.*`, `.ssh/*`, `*.pem`, `*.key`, `secrets/*`
