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

Esto regenera los datos estáticos que la app empaqueta. Es un paso **opcional**:
solo hace falta cuando cambian los datos de base (equipos, calendario, sedes).

## Resumen de fuentes

| Dato | Fuente | Frecuencia |
|---|---|---|
| Equipos, fixture, sedes | `tools/build_data.py` → `assets/data/*.json` | Una vez / al actualizar |
| Resultados en vivo | Edge Function ← API ESPN | Continuo durante el torneo |
| Predicciones y leaderboard | Supabase (PostgreSQL + RLS) | En tiempo real |
