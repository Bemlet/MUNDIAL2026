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

-   :material-account-lock: __Predicciones privadas hasta el kickoff__

    Vía RLS, cada usuario solo puede ver y editar **sus propias** predicciones
    mientras el partido no haya empezado. Nadie puede espiar lo que pusiste para
    un partido futuro.

-   :material-clock-alert: __Cierre por kickoff__

    Una predicción solo se puede crear o modificar **antes** del inicio del partido.

-   :material-eye-check: __Transparencia post-kickoff__

    Una vez que el partido **arranca**, los picks de ese partido pasan a ser
    visibles para todos (transparencia del ranking) — pero los de partidos por
    venir siguen ocultos.

-   :material-server-security: __Resultados protegidos__

    Los resultados se escriben **únicamente** desde la Edge Function, con el
    `service_role` (nunca expuesto al cliente).

-   :material-podium-gold: __Leaderboard agregado__

    El ranking se expone vía una **vista** que suma puntajes; las predicciones
    individuales solo se revelan a través de la vista de transparencia, y solo
    para partidos ya empezados.

</div>

## Privacidad y transparencia de las predicciones

El modelo combina dos garantías que parecen opuestas pero se respetan a nivel de
base de datos:

| Momento | Quién ve tus picks de ese partido |
|---|---|
| **Antes del kickoff** | Solo vos (política RLS `pred_select_own`) |
| **Después del kickoff** | Todos los participantes (vista `locked_predictions`) |

La tabla `predictions` mantiene RLS estricto: el cliente, con la `anon key`, solo
puede leer las filas propias. La transparencia se expone mediante una **vista
aparte** (`locked_predictions`) que corre con privilegios del owner y, por lo
tanto, saltea esa RLS — pero su `WHERE kickoff <= now()` garantiza que **nunca**
devuelve pronósticos de partidos que todavía no empezaron. Así, copiar el pick de
otro para un partido futuro es imposible: a esa altura, esos datos no salen de la
base.

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
    DB-->>App: ranking sin exponer predicciones futuras
    App->>DB: leer picks de partidos ya jugados (vista locked_predictions)
    DB-->>App: solo filas con kickoff <= ahora
```

## Identidad de los usuarios

La autenticación se apoya en **Supabase Auth**:

- Al abrir la app se crea una **sesión anónima** — sin pedir datos, ya podés jugar.
- Opcionalmente, esa sesión se puede **vincular a Google** (OAuth). La vinculación
  es retroactiva: conserva el mismo `user_id`, así que no se pierden los picks ni
  el puesto en el ranking.
- En otro dispositivo, iniciar sesión con la misma cuenta de Google **recupera**
  ese perfil y sus predicciones.

El flujo OAuth vuelve a la app mediante un *deep link* declarado en el
`AndroidManifest`. La app nunca maneja contraseñas: el intercambio de credenciales
ocurre del lado de Google y Supabase.

!!! note "Resumen"
    El frontend nunca tiene permisos para escribir resultados ni para leer
    predicciones futuras de otros. La transparencia post-kickoff y el leaderboard
    se exponen mediante vistas acotadas. Toda la confianza vive en la base de
    datos, no en el cliente.
