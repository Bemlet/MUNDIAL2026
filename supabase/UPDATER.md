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

## ⚠️ Límite de 50 MB (plan free de Supabase)

El APK universal pesa ~52 MB y NO entra en el free tier (máx 50 MB/archivo).
Por eso se sube el APK **por arquitectura** (`--split-per-abi`): el de
`arm64-v8a` pesa ~20 MB (lo usan casi todos los celulares modernos). Para algún
cel viejo de 32 bits está el `armeabi-v7a` (~17 MB).

## Publicar una actualización (cada vez)

1. Subir `version` en `pubspec.yaml` (el número después del `+`, p. ej. `1.0.0+4`).
   Ese número es la `build`. **Tiene que subir siempre.**
2. `flutter build apk --release --split-per-abi`.
   - Sale en `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
3. En Supabase Storage, subir ese APK. **⚠️ El nombre del archivo en el bucket
   TIENE que coincidir EXACTO con el `apk_url` del `version.json`.** Dos opciones:
   - **Recomendado:** renombrá el APK a `golazo-latest.apk` antes de subirlo
     (o sobrescribí el existente con ese nombre). Así nunca tocás `version.json`.
   - Alternativa: subilo con cualquier nombre, pero entonces **el `apk_url` del
     `version.json` debe apuntar a ESE nombre exacto**.
4. Editar `version.json` (campo `build` = el nuevo número, y `notes` con las
   novedades) y **reemplazarlo** en el bucket.

Listo: a todos les aparece el aviso "Actualización disponible" al abrir la app.

## ⚠️ Error "No se pudo descargar la actualización"

Casi siempre es **un desajuste de nombre**: el `apk_url` del `version.json`
apunta a un archivo que en el bucket tiene OTRO nombre (404 al descargar).

- Revisá que el nombre del `.apk` en Storage sea **idéntico** al final del
  `apk_url` en `version.json`.
- Ej. del incidente del 26/jun/2026: el APK se subió como
  `app-arm64-v8a-release.apk` pero el `apk_url` decía `golazo-latest.apk`.
  Se arregló dejando el `apk_url` apuntando a `app-arm64-v8a-release.apk`.
- También verificá que el bucket `app` siga **público** (si es privado, da 400/403).

## Notas

- El campo que manda es **`build`** (entero). `version` es solo texto lindo.
- Android pide permitir "instalar apps de fuentes desconocidas" la primera vez
  (igual que cuando instalan el APK a mano).
- Si el bucket quedó privado, los links dan 400/403 y la app no detecta nada
  (falla en silencio, no rompe).
