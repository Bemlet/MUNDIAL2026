---
title: Desarrollo
icon: lucide/terminal
---

# Desarrollo

Cómo correr el proyecto en tu máquina.

## Requisitos

- **Flutter SDK 3.x** (incluye Dart)
- Un dispositivo o emulador Android / iOS
- *(Opcional)* Python 3 para regenerar los datos del fixture

## Correr la app

```bash
flutter pub get
flutter run
```

## Compilar el APK de release

```bash
flutter build apk --release
```

!!! warning "Firma de release pendiente"
    Hoy la app se firma con la **clave debug** de Android. Para distribuirla
    públicamente o subirla a Google Play hay que configurar una clave de release
    propia. Compartir el APK debug con personas de confianza está OK; el riesgo
    es solo en distribución pública. (Ver el ticket de firma en el repo.)

## Regenerar los datos (opcional)

El fixture y los equipos viven en `assets/data/`. Para regenerarlos:

```bash
python3 tools/build_data.py
```

## Usar tu propio backend

Para apuntar la app a tu propio proyecto de Supabase:

1. Reemplazá `supabaseUrl` y `supabaseAnonKey` en `lib/supabase_config.dart`.
2. Corré `supabase/schema.sql` en tu proyecto de Supabase (crea las tablas, las
   políticas [RLS](seguridad.md) y la vista del leaderboard).

!!! info "Solo la anon key en el cliente"
    Nunca pongas el `service_role` en el cliente. La app funciona con la `anon key`,
    protegida por [Row Level Security](seguridad.md). El `service_role` vive solo
    en la Edge Function.

## Convenciones del proyecto

- **Commits** en formato Conventional Commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`.
- **Branches**: `feat/nombre-feature`, `fix/descripcion-bug`.
- **Tests**: `flutter test` debe pasar antes de cualquier PR.
- **Estado**: `AppState` como único *source of truth*; sin estado local salvo UI efímera.
