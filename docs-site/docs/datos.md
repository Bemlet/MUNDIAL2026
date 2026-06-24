---
title: Datos en vivo
icon: lucide/database
---

# Datos en vivo

La app combina **dos fuentes de datos**: un fixture estático que se genera una vez
y se versiona, y los resultados en vivo que se ingieren continuamente desde ESPN.

## Pipeline de resultados (ESPN → Supabase)

Una **Edge Function** (`supabase/functions/ingest-results/`) consulta la API
pública de ESPN y escribe los resultados en la tabla `match_results`. Corre en el
backend con el `service_role`, de modo que el cliente nunca necesita permisos de
escritura.

``` mermaid
graph LR
    ESPN[API pública ESPN] --> EF[Edge Function<br/>ingest-results]
    EF -->|service_role| DB[(match_results)]
    DB --> APP[App Flutter<br/>anon key, solo lectura]
```

!!! tip "¿Por qué una Edge Function?"
    Mantener la ingesta en el backend permite usar el `service_role` sin exponerlo,
    aplicar validaciones antes de escribir y centralizar la lógica de
    sincronización fuera del cliente.

## Generador de fixture (`build_data.py`)

El fixture y los equipos viven en `assets/data/` como JSON. Un script de Python
combina la API de ESPN con el fixture oficial para generar `teams.json` y
`matches.json`.

```bash
python3 tools/build_data.py
```

Esto regenera los datos estáticos que la app empaqueta (`teams.json`,
`matches.json` y `players.json`). Es un paso **opcional**: solo hace falta cuando
cambian los datos de base (equipos, calendario, sedes, plantel).

## Jugadores (cartas con Wikipedia)

El plantel destacado vive en `assets/data/players.json`: por cada jugador, un
perfil curado con puesto, club y seis atributos (ritmo, tiro, pase, regate,
defensa, físico) que alimentan la carta tipo radar. La **foto (Wikimedia)** y la
**bio (Wikipedia, ES/EN)** se traen **on-demand** cuando abrís la ficha, así no
se empaquetan en la app ni pesan en cada arranque.

!!! note "Datos aproximados"
    Los atributos de los jugadores son curados/estimados, no oficiales.

## Actualizaciones de la app (`version.json`)

Las nuevas builds se publican en un **bucket público de Supabase Storage**: un
`version.json` con el número de build, la versión legible, las novedades y el link
al APK. La app compara su build con la remota y, si hay una más nueva, ofrece
descargarla e instalarla. Se distribuye el **APK split arm64** para entrar en el
límite de tamaño del plan gratuito de Storage.

## Resumen de fuentes

| Dato | Fuente | Frecuencia |
|---|---|---|
| Equipos, fixture, sedes, plantel | `tools/build_data.py` → `assets/data/*.json` | Una vez / al actualizar |
| Fotos y bios de jugadores | Wikipedia / Wikimedia (on-demand) | Al abrir la ficha |
| Resultados en vivo | Edge Function ← API ESPN | Continuo durante el torneo |
| Predicciones, leaderboard y transparencia | Supabase (PostgreSQL + RLS + vistas) | En tiempo real |
| Actualizaciones de la app | Supabase Storage (`version.json` + APK) | Al publicar una release |
