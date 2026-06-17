/// Configuración de Supabase.
///
/// La `anonKey` es PÚBLICA por diseño (va embebida en el cliente); la seguridad
/// la dan las políticas RLS del backend. NUNCA poner acá la service_role/secret.
library;

const supabaseUrl = 'https://vbpvhcawzztcngvotsjt.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZicHZoY2F3enp0Y25ndm90c2p0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MjQ5NjAsImV4cCI6MjA5NzIwMDk2MH0.lul2_PF3LIpBMaIwRyieQmys68UyTubSyOsYjntqby0';
