# 🎫 TICKET — Configurar firma de release (Android)

**Estado:** 📌 Pendiente
**Prioridad:** Media (necesario solo si se quiere distribuir el APK públicamente o subir a Google Play)
**Creado:** 2026-06-19

---

## Problema

Hoy la app se firma con la **clave debug** de Android. En `android/app/build.gradle`:

```gradle
release {
    // Signing with the debug keys for now, so `flutter run --release` works.
    signingConfig = signingConfigs.getByName("debug")
}
```

La clave debug es **pública y compartida** por todas las máquinas (password `android`), por lo tanto:

- ❌ No se puede subir a Google Play.
- ❌ No conviene distribuir el APK públicamente: cualquiera podría firmar una "actualización" maliciosa con la misma clave.
- ❌ El build no está optimizado como un release real.

> Mientras tanto: compartir el APK debug con personas de confianza está OK. El riesgo es solo en distribución pública.

---

## Solución — pasos

### 1. Generar el keystore de release (una sola vez)

```bash
keytool -genkey -v -keystore ~/omnifit-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

> Guardá la contraseña en un lugar seguro. **Si perdés el keystore, no podés volver a actualizar la app en Play Store.** Hacé backup del `.jks`.

### 2. Crear `android/key.properties` (NO se commitea)

```properties
storePassword=TU_PASSWORD
keyPassword=TU_PASSWORD
keyAlias=upload
storeFile=/home/ever/omnifit-upload-keystore.jks
```

### 3. Configurar `android/app/build.gradle`

Cargar las propiedades antes de `android { ... }`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Definir el `signingConfig` de release:

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

### 4. Asegurar que NADA sensible se commitee

Agregar a `.gitignore`:

```
android/key.properties
*.jks
*.keystore
```

### 5. Buildear y verificar

```bash
flutter build apk --release
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

El `Owner` debe mostrar **tus datos**, NO `CN=Android Debug`.

---

## ⚠️ Recordatorios de seguridad

- **Nunca** commitear el `.jks` ni `key.properties`.
- **Backup** del keystore en un lugar seguro (perderlo = no poder actualizar la app nunca más en Play).
- El APK firmado lleva solo el **certificado público**; la clave privada se queda en el keystore.

---

## Referencias

- https://docs.flutter.dev/deployment/android#signing-the-app
