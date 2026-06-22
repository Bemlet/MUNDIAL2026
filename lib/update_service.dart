/// Actualización in-app (sin tienda): chequea un `version.json` público en
/// Supabase Storage y, si hay una build más nueva que la instalada, avisa.
/// Descargar/instalar el APK se hace abriendo la URL en el navegador.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'supabase_config.dart';

/// Datos de la última versión publicada (de version.json).
class AppUpdate {
  final int build; // versionCode (debe subir en cada release)
  final String version; // nombre legible, p. ej. "1.1.0"
  final String url; // link directo al APK
  final String? notes; // novedades (opcional)

  const AppUpdate({
    required this.build,
    required this.version,
    required this.url,
    this.notes,
  });
}

class UpdateService {
  // Bucket público "app" con version.json (subido por vos en Supabase Storage).
  static const _versionUrl =
      '$supabaseUrl/storage/v1/object/public/app/version.json';

  /// Devuelve la actualización disponible si la build remota es mayor que la
  /// instalada; `null` si está al día o si falla (no molesta ante errores).
  static Future<AppUpdate?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final res = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;

      final remoteBuild = (j['build'] as num?)?.toInt() ?? 0;
      final url = '${j['apk_url'] ?? j['url'] ?? ''}';
      if (remoteBuild <= currentBuild || url.isEmpty) return null;

      return AppUpdate(
        build: remoteBuild,
        version: '${j['version'] ?? ''}',
        url: url,
        notes: (j['notes'] as String?)?.trim().isEmpty ?? true
            ? null
            : '${j['notes']}',
      );
    } catch (_) {
      return null;
    }
  }

  /// Descarga el APK DENTRO de la app emitiendo el progreso (0..1) y, al
  /// terminar, abre el instalador del sistema. Lanza si falla la descarga.
  static Stream<double> downloadAndInstall(String url) async* {
    final dir =
        await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final file = File('${dir.path}/golazo-update.apk');

    final res = await http.Client().send(http.Request('GET', Uri.parse(url)));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final total = res.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) yield received / total;
      }
    } finally {
      await sink.close();
    }
    yield 1.0;
    await OpenFilex.open(file.path);
  }
}
