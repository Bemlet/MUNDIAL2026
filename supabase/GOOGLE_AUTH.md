# Vincular cuenta con Google (OAuth)

Permite que un usuario anónimo ate su cuenta a Google y la recupere en otro
celular / tras reinstalar, sin perder apodo ni pronósticos.

La app usa el **flujo OAuth web** de Supabase (abre una pestaña, vuelve por el
deep link `com.ever.mundial2026://login-callback`). No requiere huellas SHA.

## A) Google Cloud Console (una vez)

1. https://console.cloud.google.com → crear/seleccionar un proyecto.
2. **APIs y servicios → Pantalla de consentimiento de OAuth**:
   - Tipo: **External** → Crear.
   - Completar: nombre de app (p. ej. "Golazo"), email de soporte, email del dev.
   - En "Usuarios de prueba" agregá los emails de tus amigos (mientras la app
     esté en modo testing). O publicá la app de consentimiento para que entre
     cualquiera.
3. **APIs y servicios → Credenciales → Crear credenciales → ID de cliente OAuth**:
   - Tipo de aplicación: **Aplicación web**.
   - **URI de redirección autorizado** (importante):
     `https://vbpvhcawzztcngvotsjt.supabase.co/auth/v1/callback`
   - Crear → copiar **Client ID** y **Client Secret**.

## B) Supabase Dashboard (una vez)

1. **Authentication → Providers → Google**: Enable → pegar **Client ID** y
   **Client Secret** → Save.
2. **Authentication → URL Configuration → Redirect URLs**: agregar
   `com.ever.mundial2026://login-callback` → Save.
3. **Authentication → Providers**: confirmar que **Anonymous sign-ins** está ON.
4. **Authentication → (Settings/Sign In)**: activar **Allow manual linking**
   (lo usa `linkIdentity` para vincular el usuario anónimo con Google).

## C) Probar

1. (Tras configurar) se publica una build nueva por el updater.
2. En Pick'em (anónimo) → tarjeta "Protegé tu cuenta" → **Vincular con Google**
   → elegir cuenta → vuelve a la app vinculada.
3. Desinstalar/reinstalar → Pick'em → **Ya tengo cuenta — Recuperar** → Google →
   vuelven apodo y picks.

## Notas

- **Retroactivo**: sirve para todos los que TODAVÍA tienen la app instalada
  (vinculan ahora y conservan su id). Las sesiones ya perdidas no se pueden
  recuperar automáticamente (no hay forma de probar la pertenencia).
- El envío de mails no aplica (Google no manda OTP). Sí depende de que el email
  del amigo esté como "usuario de prueba" si la consent screen sigue en testing.
