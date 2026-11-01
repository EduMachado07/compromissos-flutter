import 'dart:async';

import 'package:compromissos_app/features/compromissos/presentation/formatacao.dart';
import 'package:compromissos_app/features/compromissos/presentation/screens/tela_compromissos.dart';
import 'package:compromissos_app/features/compromissos/services/servico_calendario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../support/fakes.dart';

void main() {
  late ServicoFalso servico;

  // Terça-feira: o período vai de 03/11/2026 a 09/11/2026.
  final agora = DateTime(2026, 11, 3, 15, 42);

  setUpAll(() => initializeDateFormatting(localeDoApp));

  setUp(() => servico = ServicoFalso());

  Future<void> abrir(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: TelaCompromissos(servico: servico, relogio: () => agora),
      ),
    );
  }

  Future<void> consultar(WidgetTester tester) async {
    await tester.tap(find.text('Consultar compromissos'));
    await tester.pump();
    await tester.pump();
  }

  ElevatedButton botaoConsultar(WidgetTester tester) => tester.widget(
    find.ancestor(
      of: find.text('Consultar compromissos'),
      matching: find.byType(ElevatedButton),
    ),
  );

  void telaAlta(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('estado inicial', () {
    testWidgets('mostra o título, o botão habilitado e a orientação', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Compromissos do calendário'), findsOneWidget);
      expect(find.text('Consultar compromissos'), findsOneWidget);
      expect(botaoConsultar(tester).onPressed, isNotNull);
      expect(
        find.text(
          'Pressione o botão para consultar os compromissos dos próximos 7 dias.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('não consulta o calendário antes de o usuário pedir', (
      tester,
    ) async {
      await abrir(tester);

      expect(servico.verificacoes, 0);
    });
  });

  group('durante a consulta', () {
    testWidgets('mostra o indicador, orienta e desabilita o botão', (
      tester,
    ) async {
      servico.bloqueioConsulta = Completer<void>();
      await abrir(tester);

      await consultar(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Consultando o calendário...'), findsOneWidget);
      expect(botaoConsultar(tester).onPressed, isNull);

      servico.bloqueioConsulta!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('o indicador some e o botão volta ao terminar', (tester) async {
      servico.bloqueioConsulta = Completer<void>();
      await abrir(tester);
      await consultar(tester);

      servico.bloqueioConsulta!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(botaoConsultar(tester).onPressed, isNotNull);
    });

    testWidgets('toques repetidos não iniciam outra consulta', (tester) async {
      servico.bloqueioVerificacao = Completer<void>();
      await abrir(tester);
      await consultar(tester);

      await tester.tap(find.text('Consultar compromissos'));
      await tester.pump();

      expect(servico.verificacoes, 1);

      servico.bloqueioVerificacao!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('com compromissos', () {
    testWidgets('lista em ordem, com a quantidade e o período consultado', (
      tester,
    ) async {
      telaAlta(tester);
      servico.compromissos = [
        compromissoDeTeste(
          titulo: 'Primeiro',
          inicio: DateTime(2026, 11, 3, 18),
        ),
        compromissoDeTeste(titulo: 'Segundo', inicio: DateTime(2026, 11, 4, 9)),
        compromissoDeTeste(
          titulo: 'Terceiro',
          inicio: DateTime(2026, 11, 8, 20),
        ),
      ];
      await abrir(tester);

      await consultar(tester);

      expect(
        find.text('3 compromisso(s) de 03/11/2026 a 09/11/2026.'),
        findsOneWidget,
      );
      final posicoes = [
        'Primeiro',
        'Segundo',
        'Terceiro',
      ].map((titulo) => tester.getTopLeft(find.text(titulo)).dy).toList();
      expect(posicoes, [...posicoes]..sort());
      expect(servico.periodosConsultados.single.inicio, DateTime(2026, 11, 3));
    });

    testWidgets('cada item traz calendário, horário, local e descrição', (
      tester,
    ) async {
      servico.compromissos = [
        compromissoDeTeste(
          titulo: 'Dentista',
          calendario: 'Pessoal',
          inicio: DateTime(2026, 11, 4, 9),
          fim: DateTime(2026, 11, 4, 10),
          local: 'Clínica Sorriso',
          descricao: 'Levar exames',
        ),
      ];
      await abrir(tester);

      await consultar(tester);

      expect(find.text('Dentista'), findsOneWidget);
      expect(find.text('Pessoal'), findsOneWidget);
      expect(find.text('qua., 04/11/2026 · 09:00 às 10:00'), findsOneWidget);
      expect(find.text('Clínica Sorriso'), findsOneWidget);
      expect(find.text('Levar exames'), findsOneWidget);
    });

    testWidgets('identifica o compromisso de dia inteiro', (tester) async {
      servico.compromissos = [
        compromissoDeTeste(
          titulo: 'Feriado',
          inicio: DateTime(2026, 11, 15),
          fim: DateTime(2026, 11, 16),
          diaInteiro: true,
        ),
      ];
      await abrir(tester);

      await consultar(tester);

      expect(find.text('Dia inteiro'), findsOneWidget);
    });

    testWidgets('uma nova consulta atualiza a lista', (tester) async {
      servico.compromissos = [compromissoDeTeste(titulo: 'Antigo')];
      await abrir(tester);
      await consultar(tester);

      servico.compromissos = [compromissoDeTeste(titulo: 'Novo')];
      await consultar(tester);

      expect(find.text('Antigo'), findsNothing);
      expect(find.text('Novo'), findsOneWidget);
    });
  });

  group('sem compromissos, sem acesso e com falha', () {
    testWidgets('informa que não há compromissos no período', (tester) async {
      servico.compromissos = [];
      await abrir(tester);

      await consultar(tester);

      expect(
        find.text('Nenhum compromisso de 03/11/2026 a 09/11/2026.'),
        findsOneWidget,
      );
    });

    testWidgets('informa que o acesso foi negado', (tester) async {
      servico.acesso = SituacaoAcesso.negado;
      await abrir(tester);

      await consultar(tester);

      expect(
        find.text(
          'O acesso ao calendário não foi autorizado. Autorize o acesso nas '
          'configurações do aplicativo para consultar os compromissos.',
        ),
        findsOneWidget,
      );
      expect(servico.periodosConsultados, isEmpty);
    });

    testWidgets('informa a falha e permite tentar de novo', (tester) async {
      servico.lancarAoConsultar = const FalhaCalendarioException('x');
      await abrir(tester);

      await consultar(tester);

      expect(
        find.text(
          'Não foi possível consultar os compromissos. Tente novamente.',
        ),
        findsOneWidget,
      );
      expect(botaoConsultar(tester).onPressed, isNotNull);

      servico.lancarAoConsultar = null;
      servico.compromissos = [compromissoDeTeste(titulo: 'Recuperado')];
      await consultar(tester);

      expect(find.text('Recuperado'), findsOneWidget);
    });

    testWidgets(
      'a mensagem de acesso negado some quando o acesso é concedido',
      (tester) async {
        servico.acesso = SituacaoAcesso.negado;
        await abrir(tester);
        await consultar(tester);

        servico.acesso = SituacaoAcesso.autorizado;
        servico.compromissos = [compromissoDeTeste()];
        await consultar(tester);

        expect(find.textContaining('não foi autorizado'), findsNothing);
        expect(find.text('Reunião de equipe'), findsOneWidget);
      },
    );
  });

  testWidgets('sair da tela durante a consulta não gera erro', (tester) async {
    servico.bloqueioConsulta = Completer<void>();
    await abrir(tester);
    await consultar(tester);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    servico.bloqueioConsulta!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
