# Diseño: Pick'em "Fase Final" (Borrón y cuenta nueva)

**Fecha:** 2026-06-27
**Estado:** Aprobado para planificación
**Autor:** ever

## Objetivo

Reenganchar a los usuarios cuando termina la fase de grupos del Mundial,
dándoles un **arranque limpio** para la fase de eliminatorias. Hoy, quien quedó
último en el Pick'em de grupos siente que "ya perdió" y se desconecta justo
cuando empieza lo mejor del torneo.

Se crean **dos competencias de pronósticos con dos campeones**:
- **Campeón de Grupos** — el ranking actual, que solo cuenta los partidos de la
  fase de grupos. Se "congela" naturalmente al terminar los grupos (deja de
  sumar) y queda como palmarés.
- **Campeón de Fase Final** — un ranking **nuevo desde 0**, que cuenta solo desde
  16vos de final en adelante.

Inspiración: el Pick'em de Worlds (LoL), que separa fase de grupos y bracket en
competencias distintas y escala los puntos por ronda.

## Decisiones tomadas

| Decisión | Elección |
|---|---|
| Cantidad de rankings | **Dos**: Grupos (congelado) + Fase Final (desde 16vos). Sin "General" acumulado. |
| Inicio de la Fase Final | Desde **16vos** (Round of 32, `stage == r32`). |
| Sistema de puntaje | El **6/3 actual se duplica por ronda** (ver tabla). |
| Partido por el 3er puesto | Puntaje **base 6/3** (no escala; es de consolación). |
| Reenganche | Push al iniciar los 16vos. |

## Puntaje de la Fase Final

El sistema actual (6 por marcador exacto / 3 por acertar el resultado / 0) se
**multiplica ×2 cada ronda**:

| Ronda | `stage` | Exacto | Resultado |
|---|---|---|---|
| 16vos (Round of 32) | r32 | 6 | 3 |
| 8vos (Round of 16) | r16 | 12 | 6 |
| 4tos (Quarterfinals) | qf | 24 | 12 |
| Semifinal | sf | 48 | 24 |
| **Final** | final | **96** | **48** |
| 3er puesto | third | 6 | 3 |

**Por qué doblar:** como la cantidad de partidos se reduce a la mitad cada ronda
(16→8→4→2→1), el ×2 hace que **cada ronda tenga el mismo peso total** (~96 puntos
disponibles por ronda). Da máxima tensión hasta la final manteniendo el balance
entre rondas. Es una decisión consciente de que un acierto en la final pese
mucho por partido (drama / comebacks), alineado con el objetivo de "borrón y
cuenta nueva".

> Nota: los `stage` exactos (r32/r16/qf/sf/final/third) deben confirmarse contra
> el enum/modelo real (`models.dart`) en la fase de plan. El partido por el 3er
> puesto debe identificarse correctamente para no aplicarle el multiplicador de
> la final.

## Alcance / componentes

### 1. Lógica de puntaje (app + backend)
- Hoy el puntaje del Pick'em es plano (6/3/0) y se calcula tanto en la app (para
  mostrar) como en la vista `leaderboard` de Supabase (para el ranking).
- Hay que introducir un **multiplicador por ronda** y separar el cómputo en dos
  fases: **grupos** (sin multiplicador, solo partidos de grupo) y **fase final**
  (con multiplicador, solo knockout).

### 2. Backend (Supabase)
- La vista/cálculo del leaderboard debe producir **dos rankings**: puntos de
  grupos y puntos de fase final (con el multiplicador por ronda aplicado).
- Mantener la privacidad/transparencia ya existente (predicciones privadas hasta
  el kickoff, públicas después).

### 3. UI
- En la pantalla de Pick'em / leaderboard, mostrar **dos pestañas/rankings**:
  **"Grupos"** y **"Fase Final"** (nombre a confirmar; alternativa
  "Eliminatorias").
- Mostrar claramente el **campeón** (o líder) de cada uno.
- El puntaje por ronda debe reflejarse en la lógica local de la app (para los
  puntos que se muestran junto a cada pick).

### 4. Notificación de reenganche
- Push al iniciar los 16vos (vía `NotificationService`), una sola vez.
- Copy propuesto (a confirmar): *"⚽ Borrón y cuenta nueva — todos arrancan en 0.
  Hacé tus pronósticos de la fase final."*

## Privacidad / consideraciones

- Sin dinero real ni apuestas: es puro "bragging rights" (coherente con la
  decisión de no incorporar apuestas — ver `docs/ESTRATEGIA-evergreen.local.md`).
- Reusa el motor de Pick'em existente; no cambia el modelo de privacidad.

## Fuera de alcance

- "Bola de cristal" (predecir campeón/finalistas por adelantado) — idea futura.
- Bracket completo estilo LoL (predecir quién avanza cada ronda) — el puntaje
  acá sigue siendo por marcador de partido, solo que escalado por ronda.
- Ligas privadas / multi-competición (ver estrategia evergreen, otra iteración).

## Notas de implementación (para la fase de plan)

- Confirmar el enum de `stage` en `models.dart` y cómo se distingue el partido
  por el 3er puesto.
- Localizar dónde se calcula el puntaje hoy: lógica local (¿`logic.dart` /
  `app_state.dart`?) y la vista `leaderboard` en Supabase.
- Tests: el puntaje por ronda (incluyendo el caso 3er puesto = base) y la
  separación grupos vs fase final.
- Localización de los strings nuevos (pestañas, push) vía `l10n.dart`.
