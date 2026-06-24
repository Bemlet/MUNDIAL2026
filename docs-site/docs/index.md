---
title: Inicio
icon: lucide/house
---

# ⚽ Mundial 2026 — Fixture & Pick'em

Aplicación móvil del Mundial 2026: **calendario real**, **resultados en vivo**,
fase de grupos, **bracket** eliminatorio, fichas de equipos y un juego de
**predicciones (Pick'em)** con leaderboard global.

<p>
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase">
  <img src="https://img.shields.io/badge/Material%203-757575?style=for-the-badge&logo=materialdesign&logoColor=white" alt="Material 3">
</p>

!!! tip "Proyecto open source"
    El código está disponible en GitHub: [**Bemlet/MUNDIAL2026**](https://github.com/Bemlet/MUNDIAL2026).
    Esta documentación cubre la arquitectura, el modelo de seguridad y cómo correr el proyecto.

## ¿Qué es?

Un proyecto personal construido con **Flutter + Supabase** que combina el fixture
oficial del Mundial con datos en vivo de la **API pública de ESPN**. Pensado tanto
para seguir el torneo como para competir con amigos prediciendo los resultados.

<div class="grid cards" markdown>

-   :material-calendar-clock: __Calendario real__

    Horarios en tu zona horaria, sedes y estado de cada partido.

-   :material-soccer: __Resultados en vivo__

    Sincronizados desde la API de ESPN vía una Edge Function.

-   :material-target: __Pick'em__

    Pronosticá marcadores antes del kickoff y sumá puntos.

-   :material-eye-check: __Ranking transparente__

    Cuando el partido empieza, ves los picks de todos; los futuros siguen privados.

-   :material-google: __Tus picks, a salvo__

    Vinculá la cuenta con Google y recuperalos en cualquier dispositivo.

-   :material-shield-lock: __Seguro por diseño__

    Row Level Security en Supabase en todas las tablas.

</div>

## Mapa de la documentación

| Sección | Qué encontrás |
|---|---|
| [Características](caracteristicas.md) | Todo lo que hace la app, función por función |
| [Arquitectura](arquitectura.md) | Estructura del código y cómo se conectan las piezas |
| [Seguridad (RLS)](seguridad.md) | El modelo de Row Level Security explicado |
| [Datos en vivo](datos.md) | El pipeline ESPN → Supabase y el generador de datos |
| [Desarrollo](desarrollo.md) | Requisitos y cómo correr el proyecto |
| [Capturas](capturas.md) | Galería de pantallas |
