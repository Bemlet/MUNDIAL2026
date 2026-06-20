import 'package:flutter_test/flutter_test.dart';

import 'package:mundial2026/players.dart';

void main() {
  group('PlayerDb', () {
    final db = PlayerDb.fromJson({
      'players': {
        'Vinícius Júnior': {
          'team': 'BRA',
          'pos': 'FWD',
          'club': 'Real Madrid',
          'skills': {
            'pac': 95,
            'sho': 86,
            'pas': 80,
            'dri': 93,
            'def': 40,
            'phy': 74,
          },
        },
        'Virgil van Dijk': {
          'team': 'NED',
          'pos': 'DEF',
          'club': 'Liverpool',
          'skills': {
            'pac': 80,
            'sho': 60,
            'pas': 76,
            'dri': 72,
            'def': 90,
            'phy': 90,
          },
        },
      },
    });

    test('lookup exacto', () {
      expect(db.lookup('Vinícius Júnior')?.club, 'Real Madrid');
    });

    test('lookup tolerante a acentos y mayúsculas', () {
      expect(db.lookup('vinicius junior')?.teamId, 'BRA');
      expect(db.lookup('VINICIUS JUNIOR')?.pos, 'FWD');
    });

    test('lookup inexistente devuelve null', () {
      expect(db.lookup('Quien Sea'), isNull);
    });

    test('overall pondera por puesto', () {
      // Delantero: pesa tiro/regate/ritmo, no la defensa.
      final vini = db.lookup('Vinícius Júnior')!;
      expect(vini.overall, greaterThanOrEqualTo(85));
      // Defensor: defensa y físico altos lo sostienen.
      final vvd = db.lookup('Virgil van Dijk')!;
      expect(vvd.overall, greaterThanOrEqualTo(80));
    });

    test('normalize pliega acentos y signos', () {
      expect(PlayerDb.normalize('Hakan Çalhanoğlu'), 'hakan calhanoglu');
      expect(PlayerDb.normalize('  Son  Heung-min '), 'son heungmin');
    });

    test('empty db no encuentra nada', () {
      expect(PlayerDb.empty.lookup('x'), isNull);
    });
  });
}
