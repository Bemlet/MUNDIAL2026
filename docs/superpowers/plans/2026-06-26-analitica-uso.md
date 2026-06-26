# Analítica de uso — Plan de implementación (lado Flutter)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Registrar eventos de uso de la app (aperturas, pantallas, picks, vinculación de cuenta, errores) en la tabla `analytics_events` de Supabase, respetando un opt-out del usuario.

**Architecture:** Un `AnalyticsService` con métodos estáticos (mismo patrón que `NotificationService`/`UpdateService`): encola eventos en memoria, los envía por lotes (flush por timer y por tamaño), fire-and-forget. El INSERT real lo hace un método nuevo en `SupabaseService`. `AppState` instrumenta los momentos de negocio y guarda la preferencia de consentimiento (patrón `darkMode`). El `screen_view` se registra en el cambio de tab del `Shell` y en el `initState` de las pantallas de detalle (la navegación es por índice, no por rutas, así que NO se usa `RouteObserver`).

**Tech Stack:** Flutter/Dart, `supabase_flutter ^2.8.0`, `shared_preferences ^2.3.0`, `package_info_plus ^8.0.0`. Sin dependencias nuevas (el UUID v4 se genera a mano con `Random.secure()`).

## Global Constraints

- Material Design 3; `AppState` (ChangeNotifier) como único source of truth.
- Strings de UI vía `lib/l10n.dart` (clase manual `AppStrings`, getters `isEn ? 'EN' : 'ES'`). No hardcodear español en widgets.
- Commits Conventional Commits, sin `Co-Authored-By`.
- TDD: RED → GREEN → REFACTOR. `flutter test` debe pasar antes de cualquier PR.
- Backend ya creado: tabla `public.analytics_events (id uuid, user_id uuid, session_id uuid, event_name text, props jsonb, app_version text, platform text, created_at timestamptz)`, RLS solo-INSERT del propio `user_id`. `session_id` es de tipo `uuid` → el id de sesión DEBE ser un UUID válido.
- Eventos (taxonomía): `app_open`, `screen_view` (props `{screen}`), `prediction_created` (props `{match_no}`), `prediction_updated` (props `{match_no}`), `account_linked` (props `{provider}`), `app_error` (props `{context, message}`).
- Consentimiento: opt-out activado por defecto (`analyticsEnabled = true`). Sin PII en `props`.
- Fail-safe: ningún método de analítica puede lanzar excepción hacia la UI ni bloquearla.

---

### Task 1: `AnalyticsService` + sink en `SupabaseService`

**Files:**
- Create: `lib/analytics_service.dart`
- Modify: `lib/supabase_service.dart` (agregar `insertEvents`)
- Test: `test/analytics_service_test.dart`

**Interfaces:**
- Produces:
  - `AnalyticsService.initialize({required bool enabled})` → `Future<void>`
  - `AnalyticsService.setEnabled(bool value)` → `void`
  - `AnalyticsService.enabled` → `bool` (getter)
  - `AnalyticsService.logEvent(String name, {Map<String, dynamic>? props})` → `void`
  - `AnalyticsService.logScreen(String screen)` → `void`
  - `AnalyticsService.logError(String context, String message)` → `void`
  - `AnalyticsService.flush()` → `Future<void>`
  - `AnalyticsService.queueLength` → `int` (getter, solo para tests)
  - `AnalyticsService.resetForTest()` → `void` (limpia estado entre tests)
  - `SupabaseService.insertEvents(List<Map<String, dynamic>> rows)` → `Future<void>`
- Consumes: `SupabaseService.userId` (String?), `SupabaseService.insertEvents`.

- [ ] **Step 1: Escribir el test que falla**

`test/analytics_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mundial2026/analytics_service.dart';

void main() {
  setUp(() => AnalyticsService.resetForTest());

  test('opt-out por defecto encola; deshabilitado descarta', () async {
    await AnalyticsService.initialize(enabled: true);
    expect(AnalyticsService.enabled, isTrue);

    AnalyticsService.logScreen('groups');
    AnalyticsService.logEvent('app_open');
    expect(AnalyticsService.queueLength, 2);

    AnalyticsService.setEnabled(false);
    expect(AnalyticsService.enabled, isFalse);
    expect(AnalyticsService.queueLength, 0); // al deshabilitar se vacía la cola

    AnalyticsService.logScreen('matches'); // ignorado mientras está off
    expect(AnalyticsService.queueLength, 0);
  });

  test('logScreen arma el evento screen_view con props.screen', () async {
    await AnalyticsService.initialize(enabled: true);
    AnalyticsService.logScreen('bracket');
    expect(AnalyticsService.lastEventForTest?['event_name'], 'screen_view');
    expect(AnalyticsService.lastEventForTest?['props'], {'screen': 'bracket'});
  });

  test('session_id es un UUID v4 válido', () async {
    await AnalyticsService.initialize(enabled: true);
    AnalyticsService.logEvent('app_open');
    final sid = AnalyticsService.lastEventForTest?['session_id'] as String?;
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(sid ?? ''),
      isTrue,
    );
  });

  test('flush sin sesión (userId null) NO descarta los eventos', () async {
    await AnalyticsService.initialize(enabled: true);
    AnalyticsService.logEvent('app_open');
    await AnalyticsService.flush(); // SupabaseService no está ready → userId null
    expect(AnalyticsService.queueLength, 1); // se conservan para reintentar
  });
}
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/analytics_service_test.dart`
Expected: FAIL (no existe `analytics_service.dart`).

- [ ] **Step 3: Implementar `AnalyticsService`**

`lib/analytics_service.dart`:

```dart
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';

import 'supabase_service.dart';

/// Analítica de uso. Métodos estáticos, fire-and-forget: nunca bloquea la UI
/// ni propaga excepciones. Encola en memoria y envía por lotes a Supabase.
class AnalyticsService {
  static bool _enabled = true;
  static String? _sessionId;
  static String? _appVersion;
  static String? _platform;
  static final List<Map<String, dynamic>> _queue = [];
  static Timer? _flushTimer;

  static const Duration _flushInterval = Duration(seconds: 30);
  static const int _maxQueue = 200; // tope duro; al pasarse, se descarta lo más viejo
  static const int _flushAt = 20; // flush proactivo al acumular esta cantidad

  static bool get enabled => _enabled;
  static int get queueLength => _queue.length;

  // Solo para tests.
  static Map<String, dynamic>? get lastEventForTest =>
      _queue.isEmpty ? null : _queue.last;

  static Future<void> initialize({required bool enabled}) async {
    _enabled = enabled;
    _sessionId ??= _uuidV4();
    _platform ??= _detectPlatform();
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {
      // En tests o plataformas sin plugin: queda null.
    }
    _flushTimer ??= Timer.periodic(_flushInterval, (_) => flush());
  }

  static void setEnabled(bool value) {
    _enabled = value;
    if (!value) _queue.clear();
  }

  static void logEvent(String name, {Map<String, dynamic>? props}) {
    if (!_enabled) return;
    _queue.add({
      'session_id': _sessionId ?? _uuidV4(),
      'event_name': name,
      'props': props ?? const <String, dynamic>{},
      'app_version': _appVersion,
      'platform': _platform,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    if (_queue.length > _maxQueue) {
      _queue.removeRange(0, _queue.length - _maxQueue);
    }
    if (_queue.length >= _flushAt) unawaited(flush());
  }

  static void logScreen(String screen) =>
      logEvent('screen_view', props: {'screen': screen});

  static void logError(String context, String message) => logEvent(
        'app_error',
        props: {'context': context, 'message': message},
      );

  static Future<void> flush() async {
    if (_queue.isEmpty) return;
    final uid = SupabaseService.userId;
    if (uid == null) return; // sin sesión: se conservan para el próximo flush
    final batch = List<Map<String, dynamic>>.from(_queue);
    final rows = batch
        .map((e) => {...e, 'user_id': uid})
        .toList(growable: false);
    try {
      await SupabaseService.insertEvents(rows);
      _queue.removeRange(0, batch.length); // saca solo lo que se envió
    } catch (_) {
      // Falla silenciosa: se reintenta en el próximo flush.
    }
  }

  static String _detectPlatform() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  static String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // versión 4
    b[8] = (b[8] & 0x3f) | 0x80; // variante
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).toList();
    return '${h[0]}${h[1]}${h[2]}${h[3]}-${h[4]}${h[5]}-${h[6]}${h[7]}-'
        '${h[8]}${h[9]}-${h[10]}${h[11]}${h[12]}${h[13]}${h[14]}${h[15]}';
  }

  /// Limpia el estado estático entre tests.
  static void resetForTest() {
    _enabled = true;
    _sessionId = null;
    _appVersion = null;
    _platform = null;
    _queue.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}
```

- [ ] **Step 4: Agregar `insertEvents` a `SupabaseService`**

En `lib/supabase_service.dart`, junto a los demás métodos estáticos (seguir el patrón defensivo `final c = _client; if (c == null) return;`):

```dart
/// Inserta eventos de analítica. No-op si no hay cliente/sesión.
/// El RLS exige que cada fila tenga user_id == auth.uid().
static Future<void> insertEvents(List<Map<String, dynamic>> rows) async {
  final c = _client;
  if (c == null || rows.isEmpty) return;
  await c.from('analytics_events').insert(rows);
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/analytics_service_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/analytics_service.dart lib/supabase_service.dart test/analytics_service_test.dart
git commit -m "feat: AnalyticsService con cola y flush por lotes + sink en SupabaseService"
```

---

### Task 2: Integración en `AppState` (consentimiento + eventos de negocio)

**Files:**
- Modify: `lib/app_state.dart`
- Test: `test/app_state_test.dart` (agregar casos)

**Interfaces:**
- Consumes: `AnalyticsService.*` (Task 1).
- Produces:
  - `AppState.analyticsEnabled` → `bool` (campo, default `true`)
  - `AppState.setAnalyticsEnabled(bool value)` → `void`

- [ ] **Step 1: Escribir el test que falla**

Agregar a `test/app_state_test.dart`:

```dart
import 'package:mundial2026/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

test('analyticsEnabled: default true, persiste y propaga a AnalyticsService',
    () async {
  SharedPreferences.setMockInitialValues({});
  AnalyticsService.resetForTest();
  final s = AppState();
  await s.load(initialSync: false);

  expect(s.analyticsEnabled, isTrue);

  s.setAnalyticsEnabled(false);
  expect(s.analyticsEnabled, isFalse);
  expect(AnalyticsService.enabled, isFalse);

  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getBool('analyticsEnabled'), isFalse);
});
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/app_state_test.dart`
Expected: FAIL (`analyticsEnabled` no existe).

- [ ] **Step 3: Agregar el campo y el setter**

En `lib/app_state.dart`, junto a los demás flags públicos (cerca de `darkMode`):

```dart
bool analyticsEnabled = true; // opt-out: activado por defecto
```

Setter (patrón `toggleTheme`):

```dart
void setAnalyticsEnabled(bool value) {
  analyticsEnabled = value;
  _prefs?.setBool('analyticsEnabled', value);
  AnalyticsService.setEnabled(value);
  notifyListeners();
}
```

- [ ] **Step 4: Leer la preferencia en `_loadPrefs()`**

En `_loadPrefs()` (donde se leen `darkMode`, etc.), agregar:

```dart
analyticsEnabled = p.getBool('analyticsEnabled') ?? true;
```

- [ ] **Step 5: Inicializar analítica y registrar `app_open` en `load()`**

En `load()`, DESPUÉS de `_loadPrefs()` (para conocer `analyticsEnabled`):

```dart
await AnalyticsService.initialize(enabled: analyticsEnabled);
AnalyticsService.logEvent('app_open');
```

- [ ] **Step 6: Instrumentar picks en `setPred()`**

En `setPred()` (lib/app_state.dart:764), capturar si ya existía ANTES de mutar y emitir el evento al guardar uno nuevo/editado (solo cuando `pred != null`):

```dart
void setPred(int matchNo, Pred? pred, {DateTime? now}) {
  final match = byNo[matchNo];
  if (match == null || !canEditPickem(match, now)) return;
  final existed = preds.containsKey(matchNo);
  if (pred == null) {
    preds.remove(matchNo);
  } else {
    preds[matchNo] = pred;
  }
  _prunePenWinners();
  _savePreds();
  notifyListeners();
  if (pred == null) {
    unawaited(SupabaseService.deletePrediction(matchNo));
  } else {
    AnalyticsService.logEvent(
      existed ? 'prediction_updated' : 'prediction_created',
      props: {'match_no': matchNo},
    );
    unawaited(
      SupabaseService.upsertPrediction(matchNo, pred.home, pred.away),
    );
  }
}
```

- [ ] **Step 7: Instrumentar `account_linked` en `linkGoogle()`**

`linkGoogle()` (lib/app_state.dart:248) hoy es `Future<String?> linkGoogle() => SupabaseService.linkGoogle();`. `SupabaseService.linkGoogle()` devuelve `null` en éxito o un mensaje de error. Reescribir para registrar el evento en éxito:

```dart
Future<String?> linkGoogle() async {
  final err = await SupabaseService.linkGoogle();
  if (err == null) {
    AnalyticsService.logEvent('account_linked', props: {'provider': 'google'});
  }
  return err;
}
```

- [ ] **Step 8: Instrumentar `app_error` en `sync()`**

En `sync()` (lib/app_state.dart:523), en el bloque donde se marca `syncFailed = true` (catch), agregar:

```dart
AnalyticsService.logError('sync', e.toString());
```

(usar la variable de excepción real del `catch`; si el catch no captura la excepción, cambiar `catch (_)` por `catch (e)`.)

- [ ] **Step 9: Correr los tests y verificar que pasan**

Run: `flutter test test/app_state_test.dart`
Expected: PASS (incluido el caso nuevo). Si `flush` intenta correr por timer, no afecta: `SupabaseService` no está ready en tests.

- [ ] **Step 10: Commit**

```bash
git add lib/app_state.dart test/app_state_test.dart
git commit -m "feat: integrar analítica en AppState (consentimiento, app_open, picks, link, errores)"
```

---

### Task 3: Pantalla de Ajustes con el toggle de consentimiento

**Files:**
- Create: `lib/screens/settings_screen.dart`
- Modify: `lib/l10n.dart` (strings nuevos)
- Modify: `lib/screens/matches_screen.dart` (entrada a Ajustes en el AppBar)

**Interfaces:**
- Consumes: `AppState.analyticsEnabled`, `AppState.setAnalyticsEnabled`, `AppScope.of(context)`, `AppStrings`.

- [ ] **Step 1: Agregar strings a `l10n.dart`**

En `class AppStrings`, junto a los demás getters:

```dart
String get settingsTitle => isEn ? 'Settings' : 'Ajustes';
String get settingsPrivacySection => isEn ? 'Privacy' : 'Privacidad';
String get analyticsToggleTitle =>
    isEn ? 'Share anonymous usage data' : 'Compartir datos de uso anónimos';
String get analyticsToggleSubtitle => isEn
    ? 'Helps improve the app. No personal data is collected; you can turn this off anytime.'
    : 'Ayuda a mejorar la app. No se recopilan datos personales; podés desactivarlo cuando quieras.';
```

- [ ] **Step 2: Crear la pantalla de Ajustes**

`lib/screens/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../main.dart' show AppScope;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l.settingsPrivacySection,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          SwitchListTile(
            title: Text(l.analyticsToggleTitle),
            subtitle: Text(l.analyticsToggleSubtitle),
            value: state.analyticsEnabled,
            onChanged: state.setAnalyticsEnabled,
          ),
        ],
      ),
    );
  }
}
```

> Nota: si `AppScope` no es exportable desde `main.dart` (es privado o causa ciclo), mover `AppScope` a su propio archivo `lib/app_scope.dart` e importarlo desde ahí en ambos lados. Verificar cómo lo importan las demás pantallas en `lib/screens/` y seguir ese mismo import.

- [ ] **Step 3: Agregar la entrada en el AppBar de `MatchesScreen`**

En `lib/screens/matches_screen.dart`, dentro de `actions:` del `AppBar` (junto a los `IconButton`/`PopupMenuButton` existentes, ~línea 113), agregar:

```dart
IconButton(
  icon: const Icon(Icons.settings_outlined),
  tooltip: state.l10n.settingsTitle,
  onPressed: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  ),
),
```

Agregar el import: `import 'settings_screen.dart';`

- [ ] **Step 4: Verificación manual / análisis estático**

Run: `flutter analyze`
Expected: sin errores nuevos. (Si hay golden tests del AppBar de `MatchesScreen`, regenerarlos: `flutter test --update-goldens test/screens_golden_test.dart` y revisar el diff visual.)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart lib/l10n.dart lib/screens/matches_screen.dart
git commit -m "feat: pantalla de Ajustes con toggle de consentimiento de analítica"
```

---

### Task 4: Registro de `screen_view` (tabs + pantallas de detalle)

**Files:**
- Modify: `lib/main.dart` (cambio de tab del `Shell`)
- Modify: `lib/screens/match_detail.dart`, `lib/screens/team_detail.dart`, `lib/screens/player_detail.dart`

**Interfaces:**
- Consumes: `AnalyticsService.logScreen(String)`.

- [ ] **Step 1: Registrar la tab inicial y los cambios de tab en `main.dart`**

En `_ShellState`, mapear índice → nombre y registrar. Definir un helper constante de nombres (alineado con el orden del NavigationBar: 0=matches, 1=groups, 2=bracket, 3=stats, 4=pickem, 5=teams):

```dart
static const _tabScreens = [
  'matches', 'groups', 'bracket', 'stats', 'pickem', 'teams',
];
```

En `onDestinationSelected` (~línea 504):

```dart
onDestinationSelected: (i) {
  AnalyticsService.logScreen(_tabScreens[i]);
  setState(() => index = i);
},
```

Y registrar la tab inicial una sola vez (en `initState` del `_ShellState`, después de `state.load()`):

```dart
AnalyticsService.logScreen(_tabScreens[index]);
```

Agregar `import 'analytics_service.dart';` en `main.dart`.

- [ ] **Step 2: Registrar las pantallas de detalle**

En el `initState` de cada pantalla de detalle (o, si son `StatelessWidget`, en el `build` con un `addPostFrameCallback`), agregar el log correspondiente. Verificar primero si cada una es `StatefulWidget`:

- `match_detail.dart` → `AnalyticsService.logScreen('match_detail');`
- `team_detail.dart` → `AnalyticsService.logScreen('team_detail');`
- `player_detail.dart` → `AnalyticsService.logScreen('player_detail');`

Patrón para `StatefulWidget`:

```dart
@override
void initState() {
  super.initState();
  AnalyticsService.logScreen('match_detail');
}
```

Patrón para `StatelessWidget` (sin convertir a Stateful), al inicio del `build`:

```dart
WidgetsBinding.instance.addPostFrameCallback(
  (_) => AnalyticsService.logScreen('team_detail'),
);
```

Agregar el import `import '../analytics_service.dart';` en cada archivo.

- [ ] **Step 3: Análisis estático y tests**

Run: `flutter analyze && flutter test`
Expected: sin errores; todos los tests pasan.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/screens/match_detail.dart lib/screens/team_detail.dart lib/screens/player_detail.dart
git commit -m "feat: registrar screen_view en tabs y pantallas de detalle"
```

---

## Verificación final

- [ ] `flutter analyze` sin errores nuevos.
- [ ] `flutter test` todo verde.
- [ ] Revisar que ningún `logEvent` se llame en un `build` sin `addPostFrameCallback` (evitar setState durante build).
- [ ] Confirmar a mano (opcional, con sesión real) que aparecen filas en `analytics_events` y que las vistas `analytics.*` devuelven datos.

## Pendiente fuera de este plan

- Rol de DB read-only + conexión de Metabase (requiere elegir contraseña).
- Crash reporting nativo (Sentry/Crashlytics) si se necesita más adelante.
