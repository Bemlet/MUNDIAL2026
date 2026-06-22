# Actualizaciones in-app (Supabase Storage)

La app revisa al abrir un `version.json` público en Supabase Storage. Si la
`build` publicada es mayor que la instalada, muestra el diálogo de actualización
y abre el APK para instalar.

## Setup (una sola vez)

1. Supabase → **Storage** → **New bucket**.
   - Name: `app`
   - **Public bucket: ON** (importante: si es privado, los links no abren).
2. Subir dos archivos a ese bucket:
   - `golazo-latest.apk` — el APK de la versión nueva.
   - `version.json` — el de este repo (`supabase/version.json`).

Las URLs públicas quedan así (ya cableadas en la app):
- `https://vbpvhcawzztcngvotsjt.supabase.co/storage/v1/object/public/app/version.json`
- `https://vbpvhcawzztcngvotsjt.supabase.co/storage/v1/object/public/app/golazo-latest.apk`

## Publicar una actualización (cada vez)

1. Subir `version` en `pubspec.yaml` (el número después del `+`, p. ej. `1.0.0+4`).
   Ese número es la `build`. **Tiene que subir siempre.**
2. `flutter build apk --release`.
3. En Supabase Storage, **reemplazar** `golazo-latest.apk` por el nuevo
   (Upload → sobrescribir).
4. Editar `version.json` (campo `build` = el nuevo número, y `notes` con las
   novedades) y **reemplazarlo** en el bucket.

Listo: a todos les aparece el aviso "Actualización disponible" al abrir la app.

## Notas

- El campo que manda es **`build`** (entero). `version` es solo texto lindo.
- Android pide permitir "instalar apps de fuentes desconocidas" la primera vez
  (igual que cuando instalan el APK a mano).
- Si el bucket quedó privado, los links dan 400/403 y la app no detecta nada
  (falla en silencio, no rompe).
