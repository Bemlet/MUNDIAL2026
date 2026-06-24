---
title: Características
icon: lucide/sparkles
---

# Características

Todo lo que hace la app, función por función.

| | Funcionalidad | Detalle |
|---|---|---|
| :material-calendar: | **Calendario completo** | Horarios reales (kickoff en tu zona horaria) y sedes de cada partido |
| :material-soccer: | **Resultados en vivo** | Sincronizados desde la API pública de ESPN |
| :material-table: | **Fase de grupos** | Tablas de posiciones calculadas automáticamente |
| :material-tournament: | **Bracket eliminatorio** | Desde los playoffs hasta la final |
| :material-target: | **Predicciones (Pick'em)** | Pronosticá los marcadores antes del kickoff y sumá puntos |
| :material-podium: | **Leaderboard global** | Ranking con apodos y países |
| :material-eye-check: | **Transparencia del ranking** | Cuando un partido empieza, podés ver qué pronosticó cada participante; los picks de partidos futuros siguen privados |
| :material-flag: | **Fichas de equipos** | Ranking FIFA, participaciones, títulos, figuras e historia |
| :material-card-account-details: | **Cartas de jugadores** | Carta tipo radar (6 atributos) con foto y bio de Wikipedia, cargadas on-demand |
| :material-soccer-field: | **Alineaciones** | Cancha dibujada según la formación, con perfiles y suplentes clicables |
| :material-google: | **Vincular cuenta (Google)** | Asociá tu sesión a Google para recuperar tus picks si reinstalás o cambiás de teléfono |
| :material-cloud-download: | **Actualizaciones in-app** | La app detecta nuevas versiones y descarga e instala el APK sin pasar por la tienda |
| :material-bell: | **Notificaciones** | Avisos de partidos y recordatorio de los picks pendientes del día |
| :material-compass: | **Onboarding** | Tour guiado para nuevos usuarios |

## Sistema de puntaje (Pick'em)

El juego de predicciones premia la precisión de cada pronóstico:

| Acierto | Puntos |
|---|---|
| **Marcador exacto** (ej. predijiste 2-1 y salió 2-1) | **6** |
| **Resultado correcto** (acertaste quién gana / empate, pero no el marcador) | **3** |
| Resultado incorrecto | **0** |

!!! info "Reglas del juego"
    Las predicciones se cierran en el **kickoff** de cada partido: una vez que el
    partido arranca, ya no se pueden cargar ni editar pronósticos. Esto se aplica
    a nivel de base de datos mediante [Row Level Security](seguridad.md).

## Transparencia del ranking

Antes del kickoff, los pronósticos de cada uno son **privados** — nadie puede
espiar lo que pusiste. Pero **una vez que el partido empieza**, los picks de ese
partido quedan visibles para todos: así se puede revisar qué pronosticó cada
participante y cuánto sumó, sin que nadie pueda copiar pronósticos de partidos por
venir. El detalle de cómo se garantiza esto está en [Seguridad](seguridad.md).

## Tu cuenta y tus picks

Al abrir la app jugás con una **sesión anónima**, sin pedirte nada. Si querés que
tus picks sobrevivan a una reinstalación o a un cambio de teléfono, podés
**vincular la cuenta con Google**: la vinculación es retroactiva, así que conservás
el mismo perfil y todos los pronósticos que ya cargaste. Para recuperarlos en otro
dispositivo, basta con iniciar sesión con la misma cuenta de Google.
