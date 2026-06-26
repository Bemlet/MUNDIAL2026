# Diseño: Analítica de uso (Supabase propio)

**Fecha:** 2026-06-26
**Estado:** Aprobado para planificación
**Autor:** ever

## Objetivo

Entender cómo se usa la app Mundial 2026 para guiar decisiones de producto. Cuatro
preguntas a responder:

1. **Cuánta gente usa la app** — usuarios activos diarios/mensuales (DAU/MAU),
   sesiones, retención (cuántos vuelven).
2. **Qué pantallas/funciones usan** — popularidad de secciones, qué se ignora.
3. **Engagement del Pick'em** — cuántos predicen, cuántos picks por usuario,
   en qué partidos participan más.
4. **Errores** — errores manejados por versión/pantalla (ver "Fuera de alcance"
   para crashes nativos).

## Decisiones tomadas

| Decisión | Elección | Motivo |
|---|---|---|
| Herramienta | Supabase propio (tabla + vistas SQL) | Sin dependencias nuevas, datos 100% propios, alineado con la privacidad del proyecto |
| Identidad | Ligada al `user_id` de Supabase | Permite retención real y cruzar comportamiento con picks; los datos ya viven bajo RLS |
| Visualización | Vistas SQL + dashboard externo Metabase | Metabase es gratis (open source) y el más fácil para analítica de producto sobre Postgres |
| Consentimiento | Opt-out activado por defecto | Maximiza datos útiles sin exponer identidad; toggle de transparencia en Ajustes |

## Arquitectura

```
Acción en la app
   → AnalyticsService.logEvent / logScreen   (fire-and-forget, no bloquea UI)
   → cola en memoria + flush por lotes
   → INSERT en analytics_events (anon key, RLS: solo user_id = auth.uid())
   → vistas SQL agregan
   → Metabase (rol DB read-only) lee solo las vistas
```

## 1. Modelo de datos

Tabla `analytics_events`:

| columna | tipo | descripción |
|---|---|---|
| `id` | uuid (PK, default gen_random_uuid()) | identificador del evento |
| `user_id` | uuid (FK auth.users) | quién (anónimo o vinculado a Google) |
| `session_id` | uuid | agrupa eventos de una misma apertura de app |
| `event_name` | text (not null) | nombre del evento (ver taxonomía) |
| `props` | jsonb (default '{}') | datos extra del evento |
| `app_version` | text | versión de la app (cruce con releases) |
| `platform` | text | `android` / `ios` |
| `created_at` | timestamptz (default now()) | momento del evento |

Índices: `(created_at)`, `(event_name, created_at)`, `(user_id, created_at)`.

### RLS
- **INSERT**: permitido para el rol autenticado solo cuando `user_id = auth.uid()`.
- **SELECT**: denegado al cliente (anon key). Nadie ve eventos de otros desde la app.
- Lectura analítica únicamente vía vistas, expuestas a un rol de DB read-only para Metabase.

## 2. Recolección en la app

`AnalyticsService` (mismo patrón que `notification_service` / `update_service`):

- `logEvent(String name, {Map<String, dynamic>? props})` y `logScreen(String name)`.
- **Fire-and-forget**: nunca bloquea la UI ni lanza excepción hacia arriba si falla la red.
- **Cola en memoria + flush por lotes** (intervalo configurable y flush al ir a background)
  para no spamear la red. Tope de tamaño de `props`. Si falla el flush, se descarta sin reintento agresivo.
- `session_id` generado por apertura de app.
- `screen_view` automático vía `RouteObserver` enganchado al navigator — no hay que
  instrumentar pantalla por pantalla.
- Eventos manuales en momentos clave del negocio.

### Taxonomía inicial de eventos
Chica y clara; se amplía después.

| evento | props | cuándo |
|---|---|---|
| `app_open` | — | al abrir la app / nueva sesión |
| `screen_view` | `{screen}` | navegación a una pantalla (automático) |
| `prediction_created` | `{match_no}` | usuario crea un pick |
| `prediction_updated` | `{match_no}` | usuario edita un pick |
| `account_linked` | `{provider}` | vincula cuenta (Google) |
| `app_error` | `{context, message}` | error manejado en Dart |

**Regla de privacidad de datos:** `props` nunca contiene datos personales (sin nombre,
sin email). Solo identificadores de dominio (match_no, screen, etc.).

## 3. Privacidad / consentimiento

- **Opt-out activado por defecto**: toggle en Ajustes ("Compartir datos de uso anónimos")
  más una línea de transparencia.
- Eventos ligados al `user_id` existente, pero sin PII en `props`.
- Si el usuario desactiva la analítica, `AnalyticsService` deja de encolar/enviar eventos.

## 4. Consulta / visualización

Vistas SQL que responden los 4 objetivos:

- `v_daily_active_users` — DAU/MAU por día.
- `v_screen_popularity` — conteo de `screen_view` por pantalla y período.
- `v_pickem_engagement` — usuarios que predicen, picks por usuario, partidos top.
- `v_retention` — cohortes: cuántos vuelven al día N.
- `v_errors` — errores agrupados por versión/pantalla.

**Dashboard externo (Metabase)** conectado al Postgres con un **rol de DB read-only
dedicado** que solo accede a las vistas. Cero UI nueva en la app.

## Fuera de alcance

- **Crash reporting nativo** (Sentry/Crashlytics): Supabase-only solo captura errores
  manejados en Dart, no crashes nativos. Add-on aparte si se necesita más adelante.
- **Pantalla admin in-app**: descartada a favor de Metabase. Reconsiderable después.

## Notas de implementación

- Migración SQL para la tabla, RLS, índices y vistas (carpeta de migraciones de Supabase).
- Rol de DB read-only para Metabase documentado, sin exponer `service_role`.
- Tests Flutter para `AnalyticsService` (cola, flush, respeto del opt-out, no propaga errores).
- Localización de los strings del toggle de Ajustes vía `l10n.dart`.
