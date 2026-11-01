import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// O Flutter ativa o R8 nos builds de release. Sem esta regra ele renomeia as
/// classes do `device_calendar`, que o plugin serializa por reflexão, e
/// `retrieveCalendars()` deixa de funcionar (veja o README do plugin).
/// O Flutter inclui `android/app/proguard-rules.pro` automaticamente quando o
/// arquivo existe.
void main() {
  test('mantém as classes do device_calendar no build de release', () {
    final arquivo = File('android/app/proguard-rules.pro');

    expect(arquivo.existsSync(), isTrue, reason: 'falta ${arquivo.path}');
    expect(
      arquivo.readAsStringSync(),
      contains('-keep class com.builttoroam.devicecalendar.** { *; }'),
    );
  });
}
