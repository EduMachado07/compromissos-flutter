import 'package:compromissos_app/features/compromissos/models/periodo_consulta.dart';
import 'package:compromissos_app/features/compromissos/services/servico_calendario.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  late PluginFalso plugin;
  late ServicoCalendario servico;

  final periodo = PeriodoConsulta(
    inicio: DateTime(2026, 11, 3),
    fim: DateTime(2026, 11, 10),
  );

  setUp(() {
    plugin = PluginFalso();
    servico = ServicoCalendario(plugin: plugin);
  });

  group('verificarAcesso', () {
    test('já autorizado: não solicita novamente', () async {
      plugin.permitido = true;

      expect(await servico.verificarAcesso(), SituacaoAcesso.autorizado);
      expect(plugin.verificacoes, 1);
      expect(plugin.pedidos, 0);
    });

    test('não autorizado: solicita e usa a resposta do usuário', () async {
      plugin.permitido = false;
      plugin.permitidoAposPedido = true;

      expect(await servico.verificarAcesso(), SituacaoAcesso.autorizado);
      expect(plugin.pedidos, 1);
    });

    test(
      'não autorizado: informa acesso negado quando o usuário recusa',
      () async {
        plugin.permitido = false;
        plugin.permitidoAposPedido = false;

        expect(await servico.verificarAcesso(), SituacaoAcesso.negado);
        expect(plugin.pedidos, 1);
      },
    );

    test(
      'erro ao verificar a permissão vira falha, sem pedir acesso',
      () async {
        plugin.erroAoVerificar = true;

        await expectLater(
          servico.verificarAcesso(),
          throwsA(isA<FalhaCalendarioException>()),
        );
        expect(plugin.pedidos, 0);
      },
    );

    test('erro ao solicitar a permissão vira falha', () async {
      plugin.permitido = false;
      plugin.erroAoPedir = true;

      await expectLater(
        servico.verificarAcesso(),
        throwsA(isA<FalhaCalendarioException>()),
      );
    });

    test('exceção do plugin vira falha', () async {
      plugin.lancarAoVerificar = Exception('canal indisponível');

      await expectLater(
        servico.verificarAcesso(),
        throwsA(isA<FalhaCalendarioException>()),
      );
    });

    test('Error do plugin (que ele próprio não captura) vira falha', () async {
      plugin.lancarAoVerificar = TypeError();

      await expectLater(
        servico.verificarAcesso(),
        throwsA(isA<FalhaCalendarioException>()),
      );
    });
  });

  group('consultar', () {
    test('consulta todos os calendários e reúne os compromissos', () async {
      plugin.calendarios = [
        Calendar(id: 'a', name: 'Pessoal'),
        Calendar(id: 'b', name: 'Trabalho'),
      ];
      plugin.eventosPorCalendario['a'] = [
        eventoDeTeste(
          calendarioId: 'a',
          titulo: 'Dentista',
          inicio: DateTime.utc(2026, 11, 4, 12),
        ),
      ];
      plugin.eventosPorCalendario['b'] = [
        eventoDeTeste(
          calendarioId: 'b',
          titulo: 'Reunião',
          inicio: DateTime.utc(2026, 11, 5, 15),
        ),
      ];

      final compromissos = await servico.consultar(periodo);

      expect(compromissos.map((c) => (c.titulo, c.calendario)), [
        ('Dentista', 'Pessoal'),
        ('Reunião', 'Trabalho'),
      ]);
      expect(plugin.consultasDeEventos.map((c) => c.calendarioId), ['a', 'b']);
    });

    test('pede ao plugin exatamente o intervalo do período', () async {
      plugin.calendarios = [Calendar(id: 'a', name: 'Pessoal')];

      await servico.consultar(periodo);

      expect(plugin.consultasDeEventos, [
        (calendarioId: 'a', inicio: periodo.inicio, fim: periodo.fim),
      ]);
    });

    test('ordena em ordem cronológica entre calendários', () async {
      plugin.calendarios = [
        Calendar(id: 'a', name: 'Pessoal'),
        Calendar(id: 'b', name: 'Trabalho'),
      ];
      plugin.eventosPorCalendario['a'] = [
        eventoDeTeste(
          calendarioId: 'a',
          titulo: 'Terceiro',
          inicio: DateTime.utc(2026, 11, 6, 12),
        ),
        eventoDeTeste(
          calendarioId: 'a',
          titulo: 'Primeiro',
          inicio: DateTime.utc(2026, 11, 4, 12),
        ),
      ];
      plugin.eventosPorCalendario['b'] = [
        eventoDeTeste(
          calendarioId: 'b',
          titulo: 'Segundo',
          inicio: DateTime.utc(2026, 11, 5, 12),
        ),
      ];

      final compromissos = await servico.consultar(periodo);

      expect(compromissos.map((c) => c.titulo), [
        'Primeiro',
        'Segundo',
        'Terceiro',
      ]);
    });

    test('identifica eventos de dia inteiro e os mantém na ordem', () async {
      plugin.calendarios = [Calendar(id: 'a', name: 'Feriados')];
      plugin.eventosPorCalendario['a'] = [
        eventoDeTeste(
          calendarioId: 'a',
          titulo: 'Reunião',
          inicio: DateTime(2026, 11, 5, 9).toUtc(),
        ),
        eventoDiaInteiroDeTeste(
          calendarioId: 'a',
          titulo: 'Feriado',
          primeiroDia: DateTime(2026, 11, 5),
        ),
      ];

      final compromissos = await servico.consultar(periodo);

      expect(compromissos.map((c) => (c.titulo, c.diaInteiro)), [
        ('Feriado', true),
        ('Reunião', false),
      ]);
    });

    test('mantém cada ocorrência de um evento recorrente', () async {
      plugin.calendarios = [Calendar(id: 'a', name: 'Pessoal')];
      plugin.eventosPorCalendario['a'] = [
        eventoDeTeste(
          calendarioId: 'a',
          id: 'academia',
          titulo: 'Academia',
          inicio: DateTime.utc(2026, 11, 4, 20),
        ),
        eventoDeTeste(
          calendarioId: 'a',
          id: 'academia',
          titulo: 'Academia',
          inicio: DateTime.utc(2026, 11, 6, 20),
        ),
      ];

      expect(await servico.consultar(periodo), hasLength(2));
    });

    test('inclui calendários somente leitura', () async {
      plugin.calendarios = [
        Calendar(id: 'a', name: 'Feriados', isReadOnly: true),
      ];
      plugin.eventosPorCalendario['a'] = [
        eventoDiaInteiroDeTeste(
          calendarioId: 'a',
          titulo: 'Proclamação da República',
          primeiroDia: DateTime(2026, 11, 6),
        ),
      ];

      final compromissos = await servico.consultar(periodo);

      expect(compromissos.map((c) => c.titulo), ['Proclamação da República']);
    });

    group('nome do calendário', () {
      Future<String> nomeDoCalendario(Calendar calendario) async {
        plugin.calendarios = [calendario];
        plugin.eventosPorCalendario[calendario.id!] = [
          eventoDeTeste(inicio: DateTime.utc(2026, 11, 4, 12)),
        ];
        return (await servico.consultar(periodo)).single.calendario;
      }

      test('usa o nome', () async {
        expect(
          await nomeDoCalendario(
            Calendar(id: 'a', name: 'Pessoal', accountName: 'eu@exemplo.com'),
          ),
          'Pessoal',
        );
      });

      test('sem nome, usa a conta', () async {
        expect(
          await nomeDoCalendario(
            Calendar(id: 'a', name: '  ', accountName: 'eu@exemplo.com'),
          ),
          'eu@exemplo.com',
        );
      });

      test('sem nome e sem conta, usa um texto padrão', () async {
        expect(
          await nomeDoCalendario(Calendar(id: 'a')),
          ServicoCalendario.calendarioSemNome,
        );
      });
    });

    test('ignora calendários sem identificador', () async {
      plugin.calendarios = [Calendar(name: 'Sem id'), Calendar(id: 'a')];

      await servico.consultar(periodo);

      expect(plugin.consultasDeEventos.map((c) => c.calendarioId), ['a']);
    });

    test('ignora eventos sem data de início', () async {
      plugin.calendarios = [Calendar(id: 'a', name: 'Pessoal')];
      plugin.eventosPorCalendario['a'] = [
        eventoDeTeste(titulo: 'Válido', inicio: DateTime.utc(2026, 11, 4, 12)),
        Event('a', title: 'Sem data')..start = null,
      ];

      final compromissos = await servico.consultar(periodo);

      expect(compromissos.map((c) => c.titulo), ['Válido']);
    });

    test('descarta eventos que só tocam as bordas do período', () async {
      plugin.calendarios = [Calendar(id: 'a', name: 'Pessoal')];
      plugin.eventosPorCalendario['a'] = [
        eventoDeTeste(
          titulo: 'Terminou à meia-noite de hoje',
          inicio: DateTime(2026, 11, 2, 22).toUtc(),
          fim: DateTime(2026, 11, 3).toUtc(),
        ),
        eventoDeTeste(
          titulo: 'Dentro',
          inicio: DateTime(2026, 11, 3, 8).toUtc(),
        ),
        eventoDeTeste(
          titulo: 'Começa à meia-noite do oitavo dia',
          inicio: DateTime(2026, 11, 10).toUtc(),
        ),
      ];

      final compromissos = await servico.consultar(periodo);

      expect(compromissos.map((c) => c.titulo), ['Dentro']);
    });

    test(
      'sem calendários: lista vazia e nenhuma consulta de eventos',
      () async {
        plugin.calendarios = [];

        expect(await servico.consultar(periodo), isEmpty);
        expect(plugin.consultasDeEventos, isEmpty);
      },
    );

    test('calendário sem eventos: lista vazia', () async {
      plugin.calendarios = [Calendar(id: 'a', name: 'Pessoal')];

      expect(await servico.consultar(periodo), isEmpty);
    });

    test('devolve uma lista que pode ser usada livremente', () async {
      plugin.calendarios = [Calendar(id: 'a', name: 'Pessoal')];
      plugin.eventosPorCalendario['a'] = [
        eventoDeTeste(inicio: DateTime.utc(2026, 11, 4, 12)),
      ];

      final compromissos = await servico.consultar(periodo);

      expect(() => compromissos.add(compromissos.first), returnsNormally);
    });

    group('falhas', () {
      Future<void> esperarFalha() => expectLater(
        servico.consultar(periodo),
        throwsA(isA<FalhaCalendarioException>()),
      );

      test('erro ao listar os calendários', () async {
        plugin.erroAoListarCalendarios = true;

        await esperarFalha();
      });

      test('lista de calendários ausente na resposta', () async {
        plugin.listaDeCalendariosNula = true;

        await esperarFalha();
      });

      test('erro em um dos calendários cancela a consulta inteira', () async {
        plugin.calendarios = [
          Calendar(id: 'a', name: 'Pessoal'),
          Calendar(id: 'b', name: 'Trabalho'),
        ];
        plugin.eventosPorCalendario['a'] = [
          eventoDeTeste(inicio: DateTime.utc(2026, 11, 4, 12)),
        ];
        plugin.calendariosComErro.add('b');

        await esperarFalha();
      });

      test('exceção ao listar os calendários', () async {
        plugin.lancarAoListarCalendarios = Exception('canal indisponível');

        await esperarFalha();
      });

      test('Error ao consultar eventos', () async {
        plugin.calendarios = [Calendar(id: 'a', name: 'Pessoal')];
        plugin.lancarAoConsultarEventos = TypeError();

        await esperarFalha();
      });
    });
  });

  group('FalhaCalendarioException', () {
    test('expõe a mensagem', () {
      const falha = FalhaCalendarioException('algo deu errado');

      expect(falha.mensagem, 'algo deu errado');
      expect(falha.toString(), contains('algo deu errado'));
    });
  });
}
