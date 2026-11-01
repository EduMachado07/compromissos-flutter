import 'package:compromissos_app/app.dart';
import 'package:compromissos_app/features/compromissos/presentation/formatacao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting(localeDoApp));

  testWidgets('abre direto na tela de compromissos', (tester) async {
    await tester.pumpWidget(App(servico: ServicoFalso()));

    expect(find.text('Compromissos do calendário'), findsOneWidget);
    expect(find.text('Consultar compromissos'), findsOneWidget);
  });
}
