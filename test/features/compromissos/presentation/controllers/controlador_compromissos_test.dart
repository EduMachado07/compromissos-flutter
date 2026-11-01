import 'dart:async';

import 'package:compromissos_app/features/compromissos/models/periodo_consulta.dart';
import 'package:compromissos_app/features/compromissos/presentation/controllers/controlador_compromissos.dart';
import 'package:compromissos_app/features/compromissos/services/servico_calendario.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fakes.dart';

void main() {
  late ServicoFalso servico;
  late ControladorCompromissos controlador;
  late List<EstadoConsulta> estados;

  final agora = DateTime(2026, 11, 3, 15, 42);

  setUp(() {
    servico = ServicoFalso();
    controlador = ControladorCompromissos(
      servico: servico,
      relogio: () => agora,
    );
    estados = [];
    controlador.addListener(() => estados.add(controlador.estado));
  });

  tearDown(() => controlador.dispose());

  test('começa sem consulta, sem compromissos e sem período', () {
    expect(controlador.estado, EstadoConsulta.inicial);
    expect(controlador.carregando, isFalse);
    expect(controlador.compromissos, isEmpty);
    expect(controlador.periodo, isNull);
  });

  group('consultar', () {
    test(
      'com acesso e compromissos: carrega e depois apresenta a lista',
      () async {
        servico.compromissos = [
          compromissoDeTeste(titulo: 'A'),
          compromissoDeTeste(titulo: 'B'),
        ];

        await controlador.consultar();

        expect(estados, [
          EstadoConsulta.carregando,
          EstadoConsulta.comCompromissos,
        ]);
        expect(controlador.compromissos.map((c) => c.titulo), ['A', 'B']);
        expect(controlador.carregando, isFalse);
      },
    );

    test('consulta os sete dias a partir do dia de hoje', () async {
      await controlador.consultar();

      final esperado = PeriodoConsulta.proximosSeteDias(agora);
      expect(servico.periodosConsultados, [esperado]);
      expect(controlador.periodo, esperado);
    });

    test('sem compromissos no período: informa lista vazia', () async {
      servico.compromissos = [];

      await controlador.consultar();

      expect(estados, [
        EstadoConsulta.carregando,
        EstadoConsulta.semCompromissos,
      ]);
      expect(controlador.compromissos, isEmpty);
    });

    test('acesso negado: informa e não consulta os compromissos', () async {
      servico.acesso = SituacaoAcesso.negado;

      await controlador.consultar();

      expect(estados, [EstadoConsulta.carregando, EstadoConsulta.acessoNegado]);
      expect(servico.periodosConsultados, isEmpty);
      expect(controlador.compromissos, isEmpty);
    });

    test('falha ao verificar o acesso', () async {
      servico.lancarAoVerificar = const FalhaCalendarioException('x');

      await controlador.consultar();

      expect(estados, [EstadoConsulta.carregando, EstadoConsulta.falha]);
      expect(servico.periodosConsultados, isEmpty);
    });

    test('falha ao consultar os compromissos', () async {
      servico.compromissos = [compromissoDeTeste()];
      servico.lancarAoConsultar = const FalhaCalendarioException('x');

      await controlador.consultar();

      expect(estados, [EstadoConsulta.carregando, EstadoConsulta.falha]);
      expect(controlador.compromissos, isEmpty);
    });

    test('erro inesperado também vira falha', () async {
      servico.lancarAoConsultar = StateError('bug');

      await controlador.consultar();

      expect(controlador.estado, EstadoConsulta.falha);
    });

    test(
      'ignora novo pedido enquanto uma consulta está em andamento',
      () async {
        servico.bloqueioVerificacao = Completer<void>();

        final primeira = controlador.consultar();
        await controlador.consultar();
        servico.bloqueioVerificacao!.complete();
        await primeira;

        expect(servico.verificacoes, 1);
        expect(estados, [
          EstadoConsulta.carregando,
          EstadoConsulta.semCompromissos,
        ]);
      },
    );

    test(
      'mantém o estado de carregamento enquanto aguarda a consulta',
      () async {
        servico.bloqueioConsulta = Completer<void>();

        final consulta = controlador.consultar();
        await Future<void>.delayed(Duration.zero);

        expect(controlador.estado, EstadoConsulta.carregando);
        expect(controlador.carregando, isTrue);

        servico.bloqueioConsulta!.complete();
        await consulta;
        expect(controlador.carregando, isFalse);
      },
    );

    test(
      'uma nova consulta descarta o resultado anterior ao começar',
      () async {
        servico.compromissos = [compromissoDeTeste(titulo: 'Antigo')];
        await controlador.consultar();
        expect(controlador.compromissos, hasLength(1));

        servico.bloqueioConsulta = Completer<void>();
        final nova = controlador.consultar();
        await Future<void>.delayed(Duration.zero);

        expect(controlador.compromissos, isEmpty);

        servico.bloqueioConsulta!.complete();
        await nova;
      },
    );

    test('depois de uma falha é possível tentar novamente', () async {
      servico.lancarAoConsultar = const FalhaCalendarioException('x');
      await controlador.consultar();
      expect(controlador.estado, EstadoConsulta.falha);

      servico.lancarAoConsultar = null;
      servico.compromissos = [compromissoDeTeste()];
      await controlador.consultar();

      expect(controlador.estado, EstadoConsulta.comCompromissos);
    });

    test(
      'depois de negado, consultar de novo verifica o acesso outra vez',
      () async {
        servico.acesso = SituacaoAcesso.negado;
        await controlador.consultar();

        servico.acesso = SituacaoAcesso.autorizado;
        servico.compromissos = [compromissoDeTeste()];
        await controlador.consultar();

        expect(servico.verificacoes, 2);
        expect(controlador.estado, EstadoConsulta.comCompromissos);
      },
    );

    test('a lista exposta não pode ser alterada por quem a consulta', () async {
      servico.compromissos = [compromissoDeTeste()];
      await controlador.consultar();

      expect(
        () => controlador.compromissos.add(compromissoDeTeste()),
        throwsUnsupportedError,
      );
    });
  });

  group('descarte', () {
    test(
      'terminar uma consulta depois do dispose não notifica nem falha',
      () async {
        final descartavel = ControladorCompromissos(
          servico: servico,
          relogio: () => agora,
        );
        servico.bloqueioConsulta = Completer<void>();

        final consulta = descartavel.consultar();
        await Future<void>.delayed(Duration.zero);
        descartavel.dispose();
        servico.bloqueioConsulta!.complete();

        await expectLater(consulta, completes);
      },
    );

    test('falha depois do dispose também é ignorada', () async {
      final descartavel = ControladorCompromissos(
        servico: servico,
        relogio: () => agora,
      );
      servico.bloqueioVerificacao = Completer<void>();
      servico.lancarAoVerificar = const FalhaCalendarioException('x');

      final consulta = descartavel.consultar();
      await Future<void>.delayed(Duration.zero);
      descartavel.dispose();
      servico.bloqueioVerificacao!.complete();

      await expectLater(consulta, completes);
    });
  });
}
