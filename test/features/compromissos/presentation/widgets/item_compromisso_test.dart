import 'package:compromissos_app/features/compromissos/presentation/formatacao.dart';
import 'package:compromissos_app/features/compromissos/presentation/widgets/item_compromisso.dart';
import 'package:compromissos_app/features/compromissos/models/compromisso.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../support/fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting(localeDoApp));

  Future<void> mostrar(WidgetTester tester, Compromisso compromisso) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ItemCompromisso(compromisso: compromisso)),
      ),
    );
  }

  testWidgets(
    'apresenta título, calendário, data e horário, local e descrição',
    (tester) async {
      await mostrar(
        tester,
        compromissoDeTeste(
          titulo: 'Reunião de equipe',
          calendario: 'Trabalho',
          inicio: DateTime(2026, 11, 3, 14),
          fim: DateTime(2026, 11, 3, 15, 30),
          local: 'Sala 3',
          descricao: 'Revisar a sprint',
        ),
      );

      expect(find.text('Reunião de equipe'), findsOneWidget);
      expect(find.text('Trabalho'), findsOneWidget);
      expect(find.text('ter., 03/11/2026 · 14:00 às 15:30'), findsOneWidget);
      expect(find.text('Sala 3'), findsOneWidget);
      expect(find.text('Revisar a sprint'), findsOneWidget);
    },
  );

  testWidgets('sem local e sem descrição mostra textos de apoio', (
    tester,
  ) async {
    await mostrar(tester, compromissoDeTeste());

    expect(find.text('Local não informado'), findsOneWidget);
    expect(find.text('Sem descrição'), findsOneWidget);
  });

  testWidgets('evento com local e descrição não mostra os textos de apoio', (
    tester,
  ) async {
    await mostrar(
      tester,
      compromissoDeTeste(local: 'Sala 3', descricao: 'Notas'),
    );

    expect(find.text('Local não informado'), findsNothing);
    expect(find.text('Sem descrição'), findsNothing);
  });

  testWidgets('evento de dia inteiro é identificado', (tester) async {
    await mostrar(
      tester,
      compromissoDeTeste(
        titulo: 'Feriado',
        inicio: DateTime(2026, 11, 3),
        fim: DateTime(2026, 11, 4),
        diaInteiro: true,
      ),
    );

    expect(find.text('Dia inteiro'), findsOneWidget);
    expect(find.text('Dia inteiro · ter., 03/11/2026'), findsOneWidget);
  });

  testWidgets('evento com horário não tem a marca de dia inteiro', (
    tester,
  ) async {
    await mostrar(tester, compromissoDeTeste());

    expect(find.text('Dia inteiro'), findsNothing);
  });

  testWidgets('título longo não estoura o layout', (tester) async {
    await mostrar(
      tester,
      compromissoDeTeste(
        titulo:
            'Reunião de alinhamento do planejamento estratégico trimestral ' *
            3,
        diaInteiro: true,
        inicio: DateTime(2026, 11, 3),
        fim: DateTime(2026, 11, 4),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
