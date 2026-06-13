# 🧭 Guía rápida de skills y comandos — Mundial 2026

Cheat sheet de cómo pedirme las cosas para aprovechar **gentle-ai (SDD)**, **Superpowers** y los **plugins oficiales** instalados en esta máquina.

> **Dos formas de disparar una skill**
> 1. **Slash command** — lo tipeás vos directo (ej. `/sdd-new`, `/code-review`).
> 2. **Lenguaje natural** — me lo describís y yo elijo la skill (ej. *"hacé un brainstorming de…"*, *"seguí con TDD"*). Funciona en español.

---

## 1) ⚡ Decisión rápida: ¿qué uso según la tarea?

| Tu tarea | Qué pedir | Cómo se dispara |
|---|---|---|
| Fix chico, ajuste visual, texto | Pedímelo directo | Lenguaje natural |
| Bug con causa no obvia | *"debuggeá esto sistemáticamente"* | skill `systematic-debugging` |
| Feature nueva (componente/pantalla/lógica) | `/feature-dev` o *"diseñemos antes de codear"* | comando o `brainstorming` |
| Feature **grande** (sección, arquitectura, integración de datos) | `/sdd-new` | comando SDD |
| Quiero solo planificar | *"escribime un plan paso a paso"* | skill `writing-plans` |
| Revisar código antes de PR | `/code-review` | comando |
| Revisar seguridad | `/security-review` | comando (además corre solo en cada edit/commit) |
| Limpiar/simplificar el diff | `/simplify` | comando |
| Verificar que algo funciona de verdad | *"verificá que esto anda"* | skill `verify` |

---

## 2) 🏗️ Gentle-AI — SDD (para features grandes)

Spec-Driven Development: divide el trabajo en fases con artefactos (propuesta → spec → diseño → tareas → implementación → verificación → archivo).

| Comando | Para qué sirve |
|---|---|
| `/sdd-init` | Inicializa SDD en el proyecto (detecta stack, testing). Se corre **una vez**. |
| `/sdd-new <nombre>` | Arranca una feature nueva con SDD (explora + propone). |
| `/sdd-ff <nombre>` | *Fast-forward*: propuesta → spec → diseño → tareas de una. |
| `/sdd-continue` | Retoma la siguiente fase pendiente. |
| `/sdd-status` | Estado actual (qué fase sigue, qué falta). |
| `/sdd-explore <tema>` | Solo investiga una idea, sin crear archivos. |
| `/sdd-apply` | Implementa las tareas en lotes. |
| `/sdd-verify` | Valida lo hecho contra la spec (CRITICAL / WARNING / SUGGESTION). |
| `/sdd-archive` | Cierra y archiva la feature. |
| `/sdd-onboard` | Tutorial guiado de SDD con tu código real. |

**Al iniciar un SDD te voy a preguntar dos cosas** (y las recuerdo en la sesión):
- **Modo**: `Interactivo` (paro y te muestro cada fase) o `Automático` (corro todo de corrido).
- **Dónde guardar artefactos**: `engram` (memoria, sin archivos), `openspec` (archivos versionables) o `hybrid`.

**Ejemplo de prompt:**
> `/sdd-new tabla-de-posiciones-historica` — *"Quiero una sección que muestre el historial de mundiales por país, con datos de `assets/data/`. Modo interactivo, artefactos en engram."*

---

## 3) 🦸 Superpowers — metodología (features medianas / calidad)

Estas se disparan **por lenguaje natural** (o yo las activo cuando corresponde):

| Skill | Cuándo / cómo pedirla |
|---|---|
| `brainstorming` | *"hagamos brainstorming de X antes de codear"* — **siempre conviene antes de una feature** |
| `writing-plans` | *"escribime un plan de implementación"* |
| `executing-plans` | *"ejecutá el plan con subagentes"* |
| `test-driven-development` | *"andá con TDD estricto"* (RED→GREEN→REFACTOR) |
| `systematic-debugging` | *"debuggeá esto sin adivinar"* |
| `verification-before-completion` | *"verificá antes de dar por terminado"* |
| `using-git-worktrees` | *"trabajá en un worktree aislado"* |
| `finishing-a-development-branch` | *"cerremos la branch correctamente"* |
| `requesting-code-review` / `receiving-code-review` | protocolo de review entre agentes |

**Ejemplo de prompt:**
> *"Quiero agregar notificaciones de gol configurables. Hacé primero un brainstorming, después un plan, y recién ahí implementá con TDD."*

---

## 4) 🔍 Calidad, review y seguridad (plugins oficiales)

| Comando | Qué hace |
|---|---|
| `/code-review` | Revisa el diff actual buscando bugs y mejoras. Agregá `--fix` para que aplique, `--comment` para comentar el PR. |
| `/code-review ultra` | Review profundo **multi-agente en la nube** de la branch (o `/code-review ultra <PR#>`). Lo lanzás **vos** (es facturado). |
| `/simplify` | Limpia el código cambiado (reuso, simplicidad, eficiencia). No busca bugs. |
| `/security-review` | Revisión de seguridad de los cambios pendientes. |
| `/verify` o *"verificá…"* | Corre la app/feature y observa que el comportamiento sea el esperado. |
| `/review <PR>` | Revisa un Pull Request. |

> 🔒 **Seguridad automática**: hay un hook que revisa cada `Edit`/`Write`/`commit`/`push` sin que pidas nada. Si encuentra algo, te aviso.

---

## 5) 🧠 Memoria (Engram) — funciona sola, no hace falta comando

- Guardo automáticamente **decisiones de arquitectura, bugs resueltos, convenciones y descubrimientos**.
- Al inicio de sesión busco contexto previo del proyecto.
- Para recuperar algo, pedímelo en lenguaje natural: *"¿qué decidimos sobre la pantalla de stats?"*, *"acordate de cómo resolvimos X"*.
- Si querés que recuerde algo puntual: *"guardá esto en memoria"*.

---

## 6) 📋 Plantillas de prompt listas para copiar

```text
# Feature grande con SDD
/sdd-new <nombre-feature>
Contexto: <qué querés>. Datos: <de dónde salen>. Modo interactivo, artefactos en engram.

# Feature mediana, guiada
Quiero <feature>. Primero brainstorming, después plan, después TDD. No codees antes del test.

# Fix puntual
Arreglá <bug/ajuste>. Es chico, andá directo.

# Antes de cerrar / hacer PR
/code-review
…y si está limpio: /simplify y después dejamos listo el commit.

# Revisión pesada en la nube (la lanzás vos)
/code-review ultra
```

---

## 7) ⚙️ Notas del entorno (importante)

- **Lo instalado**: gentle-ai v1.40.2, Superpowers, plugins oficiales (`code-review`, `frontend-design`, `security-guidance`, `feature-dev`…), y **Engram** como memoria.
- **No instalado** (a propósito, para no contradecir): `claude-mem` (chocaba con Engram), `gstack` (se solapaba con roles de gentle-ai), y el repo standalone `claude-code-security-review` (redundante con `security-guidance`).
- **Si un slash command no responde** como esperás, decímelo en lenguaje natural y yo enruto a la skill equivalente. En esta carpeta probamos que el flujo manual (brainstorming → plan → TDD → verify) funciona de punta a punta.

---

*Reglas del proyecto que siempre aplico: Material 3, `AppState` como única fuente de verdad, datos en `assets/data/`, strings vía `l10n.dart`, Conventional Commits sin trailers, y `flutter test` en verde antes de cualquier PR.*
