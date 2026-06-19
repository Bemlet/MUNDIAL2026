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
| :material-flag: | **Fichas de equipos** | Ranking FIFA, participaciones, títulos, figuras e historia |
| :material-bell: | **Notificaciones** | Avisos de partidos |
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
