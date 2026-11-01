import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Declarar uma permissão não equivale a obtê-la, mas sem a declaração o
/// Android nega o pedido automaticamente. O `device_calendar` só considera o
/// acesso concedido quando leitura e escrita estão concedidas, por isso as duas
/// precisam constar no manifesto.
void main() {
  late String manifesto;
  late int inicioDoApplication;

  setUpAll(() {
    manifesto = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    inicioDoApplication = manifesto.indexOf('<application');
  });

  for (final permissao in ['READ_CALENDAR', 'WRITE_CALENDAR']) {
    test('declara $permissao dentro de <manifest> e fora de <application>', () {
      final declaracao = RegExp(
        '<uses-permission\\s+android:name="android\\.permission\\.$permissao"\\s*/>',
      ).firstMatch(manifesto);

      expect(declaracao, isNotNull, reason: 'falta <uses-permission>');
      expect(declaracao!.start, lessThan(inicioDoApplication));
    });
  }

  test('o manifesto continua com o elemento <application>', () {
    expect(inicioDoApplication, isNonNegative);
  });

  test('o aplicativo tem um nome legível para o usuário', () {
    expect(manifesto, contains('android:label="Compromissos"'));
  });
}
