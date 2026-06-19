---
title: Seguridad (RLS)
icon: lucide/shield-check
---

# Seguridad — Row Level Security

La base de datos usa **Row Level Security (RLS)** en **todas** las tablas. RLS es
un mecanismo de PostgreSQL que filtra las filas a nivel de motor: aunque dos
usuarios hagan la misma consulta, cada uno solo ve lo que las políticas le permiten.

!!! success "Por qué importa"
    El cliente de la app usa la **`anon key`** de Supabase, que es **pública por
    diseño**. La seguridad real no depende de ocultar esa clave, sino de las
    políticas RLS: aunque alguien tenga la `anon key`, no puede leer ni escribir
    datos de otros usuarios.

## Reglas aplicadas

<div class="grid cards" markdown>

-   :material-account-lock: __Predicciones privadas__

    Cada usuario solo puede ver y editar **sus propias** predicciones.

-   :material-clock-alert: __Cierre por kickoff__

    Una predicción solo se puede crear o modificar **antes** del inicio del partido.

-   :material-server-security: __Resultados protegidos__

    Los resultados se escriben **únicamente** desde la Edge Function, con el
    `service_role` (nunca expuesto al cliente).

-   :material-podium-gold: __Leaderboard agregado__

    El ranking se expone vía una **vista** que suma puntajes sin filtrar las
    predicciones individuales de cada persona.

</div>

## Modelo de claves

| Clave | Dónde vive | Visibilidad |
|---|---|---|
| **`anon key`** | En el cliente (la app) | Pública — protegida por RLS |
| **`service_role`** | Solo en la Edge Function (backend) | **Secreta** — nunca llega al cliente |

``` mermaid
sequenceDiagram
    participant App as App (anon key)
    participant DB as Supabase + RLS
    participant EF as Edge Function (service_role)
    participant ESPN as API ESPN

    App->>DB: leer/escribir MIS predicciones
    DB-->>App: solo filas permitidas por RLS
    ESPN->>EF: resultados en vivo
    EF->>DB: escribir resultados (service_role)
    App->>DB: leer leaderboard (vista agregada)
    DB-->>App: ranking sin exponer predicciones ajenas
```

!!! note "Resumen"
    El frontend nunca tiene permisos para escribir resultados ni para leer las
    predicciones de otros. Toda la confianza vive en la base de datos, no en el cliente.
