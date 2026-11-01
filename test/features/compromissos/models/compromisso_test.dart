import 'package:compromissos_app/features/compromissos/models/compromisso.dart';
import 'package:compromissos_app/features/compromissos/models/periodo_consulta.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

Compromisso criar({
  String titulo = 'Reunião',
  String calendario = 'Pessoal',
  DateTime? inicio,
  DateTime? fim,
  bool diaInteiro = false,
}) {
  final comeco = inicio ?? DateTime(2026, 11, 3, 9);
  return Compromisso(
    titulo: titulo,
    calendario: calendario,
    inicio: comeco,
    fim: fim ?? comeco.add(const Duration(hours: 1)),
    diaInteiro: diaInteiro,
  );
}

void main() {
  setUpAll(tz.initializeTimeZones);

  group('deEvento', () {
    test('copia título, calendário, local e descrição', () {
      final evento = Event(
        'cal-1',
        eventId: 'e1',
        title: 'Reunião de equipe',
        description: 'Revisar a sprint',
        location: 'Sala 3',
        start: tz.TZDateTime.utc(2026, 11, 3, 12),
        end: tz.TZDateTime.utc(2026, 11, 3, 13),
      );

      final compromisso = Compromisso.deEvento(evento, calendario: 'Trabalho');

      expect(compromisso.titulo, 'Reunião de equipe');
      expect(compromisso.calendario, 'Trabalho');
      expect(compromisso.local, 'Sala 3');
      expect(compromisso.descricao, 'Revisar a sprint');
      expect(compromisso.diaInteiro, isFalse);
    });

    test('título nulo ou em branco vira "Sem título"', () {
      for (final titulo in [null, '', '   ']) {
        final evento = Event(
          'cal-1',
          title: titulo,
          start: tz.TZDateTime.utc(2026, 11, 3, 12),
          end: tz.TZDateTime.utc(2026, 11, 3, 13),
        );

        expect(
          Compromisso.deEvento(evento, calendario: 'Pessoal').titulo,
          'Sem título',
          reason: 'título: "$titulo"',
        );
      }
    });

    test('local e descrição nulos ou em branco ficam nulos', () {
      for (final texto in [null, '', '  \n ']) {
        final evento = Event(
          'cal-1',
          title: 'X',
          location: texto,
          description: texto,
          start: tz.TZDateTime.utc(2026, 11, 3, 12),
          end: tz.TZDateTime.utc(2026, 11, 3, 13),
        );

        final compromisso = Compromisso.deEvento(evento, calendario: 'P');

        expect(compromisso.local, isNull, reason: 'texto: "$texto"');
        expect(compromisso.descricao, isNull, reason: 'texto: "$texto"');
      }
    });

    test('remove espaços sobrando do título, do local e da descrição', () {
      final evento = Event(
        'cal-1',
        title: '  Dentista ',
        location: ' Clínica Sorriso\n',
        description: '\tLevar exames ',
        start: tz.TZDateTime.utc(2026, 11, 3, 12),
        end: tz.TZDateTime.utc(2026, 11, 3, 13),
      );

      final compromisso = Compromisso.deEvento(evento, calendario: 'P');

      expect(compromisso.titulo, 'Dentista');
      expect(compromisso.local, 'Clínica Sorriso');
      expect(compromisso.descricao, 'Levar exames');
    });

    group('evento com horário', () {
      test('mantém o instante e entrega a hora no fuso do aparelho', () {
        final saoPaulo = tz.getLocation('America/Sao_Paulo');
        final evento = Event(
          'cal-1',
          title: 'Aula',
          start: tz.TZDateTime(saoPaulo, 2026, 11, 3, 9),
          end: tz.TZDateTime(saoPaulo, 2026, 11, 3, 10, 30),
        );

        final compromisso = Compromisso.deEvento(evento, calendario: 'P');

        // São Paulo está em UTC-3 (sem horário de verão desde 2019).
        expect(
          compromisso.inicio.isAtSameMomentAs(DateTime.utc(2026, 11, 3, 12)),
          isTrue,
        );
        expect(
          compromisso.fim.isAtSameMomentAs(DateTime.utc(2026, 11, 3, 13, 30)),
          isTrue,
        );
        expect(compromisso.inicio.isUtc, isFalse);
        expect(compromisso.fim.isUtc, isFalse);
      });

      test('fim nulo equivale a um evento instantâneo', () {
        final evento = Event(
          'cal-1',
          title: 'Lembrete',
          start: tz.TZDateTime.utc(2026, 11, 3, 12),
        )..end = null;

        final compromisso = Compromisso.deEvento(evento, calendario: 'P');

        expect(compromisso.fim, compromisso.inicio);
      });

      test('fim anterior ao início é corrigido para o início', () {
        final evento = Event(
          'cal-1',
          title: 'Inválido',
          start: tz.TZDateTime.utc(2026, 11, 3, 12),
          end: tz.TZDateTime.utc(2026, 11, 3, 8),
        );

        final compromisso = Compromisso.deEvento(evento, calendario: 'P');

        expect(compromisso.fim, compromisso.inicio);
      });

      test('allDay nulo é tratado como evento com horário', () {
        final evento = Event(
          'cal-1',
          title: 'X',
          start: tz.TZDateTime.utc(2026, 11, 3, 12),
          end: tz.TZDateTime.utc(2026, 11, 3, 13),
        )..allDay = null;

        expect(
          Compromisso.deEvento(evento, calendario: 'P').diaInteiro,
          isFalse,
        );
      });
    });

    group('evento de dia inteiro', () {
      // O plugin entrega início e fim à meia-noite; no Android o fim já vem
      // ajustado para o último dia ocupado.
      test('um dia ocupa de 00:00 até 00:00 do dia seguinte', () {
        final evento = Event(
          'cal-1',
          title: 'Feriado',
          allDay: true,
          start: tz.TZDateTime.utc(2026, 11, 3),
          end: tz.TZDateTime.utc(2026, 11, 3),
        );

        final compromisso = Compromisso.deEvento(evento, calendario: 'P');

        expect(compromisso.diaInteiro, isTrue);
        expect(compromisso.inicio, DateTime(2026, 11, 3));
        expect(compromisso.fim, DateTime(2026, 11, 4));
        expect(compromisso.ultimoDia, DateTime(2026, 11, 3));
      });

      test('vários dias incluem o último dia', () {
        final evento = Event(
          'cal-1',
          title: 'Viagem',
          allDay: true,
          start: tz.TZDateTime.utc(2026, 11, 3),
          end: tz.TZDateTime.utc(2026, 11, 5),
        );

        final compromisso = Compromisso.deEvento(evento, calendario: 'P');

        expect(compromisso.inicio, DateTime(2026, 11, 3));
        expect(compromisso.fim, DateTime(2026, 11, 6));
        expect(compromisso.ultimoDia, DateTime(2026, 11, 5));
      });

      test('usa o dia do calendário, sem deslocar pelo fuso', () {
        final saoPaulo = tz.getLocation('America/Sao_Paulo');
        final evento = Event(
          'cal-1',
          title: 'Aniversário',
          allDay: true,
          start: tz.TZDateTime(saoPaulo, 2026, 11, 3),
          end: tz.TZDateTime(saoPaulo, 2026, 11, 3),
        );

        final compromisso = Compromisso.deEvento(evento, calendario: 'P');

        expect(compromisso.inicio, DateTime(2026, 11, 3));
        expect(compromisso.fim, DateTime(2026, 11, 4));
      });

      test('no último dia do mês termina no primeiro do mês seguinte', () {
        final evento = Event(
          'cal-1',
          title: 'Fim do mês',
          allDay: true,
          start: tz.TZDateTime.utc(2026, 11, 30),
          end: tz.TZDateTime.utc(2026, 11, 30),
        );

        expect(
          Compromisso.deEvento(evento, calendario: 'P').fim,
          DateTime(2026, 12, 1),
        );
      });

      test('fim anterior ao início ocupa apenas o dia de início', () {
        final evento = Event(
          'cal-1',
          title: 'Inválido',
          allDay: true,
          start: tz.TZDateTime.utc(2026, 11, 5),
          end: tz.TZDateTime.utc(2026, 11, 3),
        );

        final compromisso = Compromisso.deEvento(evento, calendario: 'P');

        expect(compromisso.inicio, DateTime(2026, 11, 5));
        expect(compromisso.fim, DateTime(2026, 11, 6));
      });
    });

    test('evento sem início não pode ser convertido', () {
      final evento = Event('cal-1', title: 'Sem data')..start = null;

      expect(
        () => Compromisso.deEvento(evento, calendario: 'P'),
        throwsArgumentError,
      );
    });
  });

  group('ultimoDia', () {
    test('evento que termina à meia-noite pertence ao dia anterior', () {
      final compromisso = criar(
        inicio: DateTime(2026, 11, 3, 22),
        fim: DateTime(2026, 11, 4),
      );

      expect(compromisso.ultimoDia, DateTime(2026, 11, 3));
    });

    test('evento que atravessa a meia-noite termina no dia seguinte', () {
      final compromisso = criar(
        inicio: DateTime(2026, 11, 3, 22),
        fim: DateTime(2026, 11, 4, 2),
      );

      expect(compromisso.ultimoDia, DateTime(2026, 11, 4));
    });

    test('evento instantâneo pertence ao dia do início', () {
      final compromisso = criar(
        inicio: DateTime(2026, 11, 3, 10),
        fim: DateTime(2026, 11, 3, 10),
      );

      expect(compromisso.ultimoDia, DateTime(2026, 11, 3));
    });
  });

  group('ocorreNoPeriodo', () {
    final periodo = PeriodoConsulta(
      inicio: DateTime(2026, 11, 3),
      fim: DateTime(2026, 11, 10),
    );

    bool ocorre(DateTime inicio, DateTime fim, {bool diaInteiro = false}) {
      return criar(
        inicio: inicio,
        fim: fim,
        diaInteiro: diaInteiro,
      ).ocorreNoPeriodo(periodo);
    }

    test('evento totalmente dentro do período', () {
      expect(
        ocorre(DateTime(2026, 11, 5, 9), DateTime(2026, 11, 5, 10)),
        isTrue,
      );
    });

    test('evento que começa antes e termina dentro do período', () {
      expect(
        ocorre(DateTime(2026, 11, 2, 23), DateTime(2026, 11, 3, 1)),
        isTrue,
      );
    });

    test('evento que começa dentro e termina depois do período', () {
      expect(
        ocorre(DateTime(2026, 11, 9, 23), DateTime(2026, 11, 10, 2)),
        isTrue,
      );
    });

    test('evento que termina exatamente no início do período fica de fora', () {
      expect(ocorre(DateTime(2026, 11, 2, 22), DateTime(2026, 11, 3)), isFalse);
    });

    test('evento que começa exatamente no fim do período fica de fora', () {
      expect(
        ocorre(DateTime(2026, 11, 10), DateTime(2026, 11, 10, 1)),
        isFalse,
      );
    });

    test('evento instantâneo no início do período entra', () {
      expect(ocorre(DateTime(2026, 11, 3), DateTime(2026, 11, 3)), isTrue);
    });

    test('evento instantâneo no fim do período fica de fora', () {
      expect(ocorre(DateTime(2026, 11, 10), DateTime(2026, 11, 10)), isFalse);
    });

    test('dia inteiro no último dia do período entra', () {
      expect(
        ocorre(DateTime(2026, 11, 9), DateTime(2026, 11, 10), diaInteiro: true),
        isTrue,
      );
    });

    test('dia inteiro logo depois do período fica de fora', () {
      expect(
        ocorre(
          DateTime(2026, 11, 10),
          DateTime(2026, 11, 11),
          diaInteiro: true,
        ),
        isFalse,
      );
    });

    test('dia inteiro na véspera do período fica de fora', () {
      expect(
        ocorre(DateTime(2026, 11, 2), DateTime(2026, 11, 3), diaInteiro: true),
        isFalse,
      );
    });
  });

  group('comparar', () {
    test('ordena pelo início', () {
      final tarde = criar(titulo: 'A', inicio: DateTime(2026, 11, 3, 15));
      final cedo = criar(titulo: 'B', inicio: DateTime(2026, 11, 3, 8));

      final ordenados = [tarde, cedo]..sort(Compromisso.comparar);

      expect(ordenados, [cedo, tarde]);
    });

    test('dia inteiro vem antes dos eventos com horário do mesmo dia', () {
      final reuniao = criar(
        titulo: 'Reunião',
        inicio: DateTime(2026, 11, 3, 9),
      );
      final feriado = criar(
        titulo: 'Feriado',
        inicio: DateTime(2026, 11, 3),
        fim: DateTime(2026, 11, 4),
        diaInteiro: true,
      );

      final ordenados = [reuniao, feriado]..sort(Compromisso.comparar);

      expect(ordenados, [feriado, reuniao]);
    });

    test('mesmo início: termina primeiro o que acaba antes', () {
      final curto = criar(
        titulo: 'Z',
        inicio: DateTime(2026, 11, 3, 9),
        fim: DateTime(2026, 11, 3, 10),
      );
      final longo = criar(
        titulo: 'A',
        inicio: DateTime(2026, 11, 3, 9),
        fim: DateTime(2026, 11, 3, 12),
      );

      final ordenados = [longo, curto]..sort(Compromisso.comparar);

      expect(ordenados, [curto, longo]);
    });

    test('empate de horário: título sem diferenciar maiúsculas', () {
      final b = criar(titulo: 'bravo');
      final a = criar(titulo: 'Alfa');

      final ordenados = [b, a]..sort(Compromisso.comparar);

      expect(ordenados, [a, b]);
    });

    test('empate total: nome do calendário', () {
      final trabalho = criar(calendario: 'Trabalho');
      final pessoal = criar(calendario: 'Pessoal');

      final ordenados = [trabalho, pessoal]..sort(Compromisso.comparar);

      expect(ordenados, [pessoal, trabalho]);
    });
  });

  group('igualdade', () {
    test('compromissos com os mesmos dados são iguais', () {
      expect(criar(), criar());
      expect(criar().hashCode, criar().hashCode);
    });

    test('qualquer campo diferente torna os compromissos diferentes', () {
      final base = criar();

      expect(base, isNot(criar(titulo: 'Outro')));
      expect(base, isNot(criar(calendario: 'Outro')));
      expect(base, isNot(criar(inicio: DateTime(2026, 11, 4, 9))));
      expect(base, isNot(criar(fim: DateTime(2026, 11, 3, 23))));
      expect(base, isNot(criar(diaInteiro: true)));
      expect(
        base,
        isNot(
          Compromisso(
            titulo: base.titulo,
            calendario: base.calendario,
            inicio: base.inicio,
            fim: base.fim,
            diaInteiro: base.diaInteiro,
            local: 'Sala 1',
          ),
        ),
      );
      expect(
        base,
        isNot(
          Compromisso(
            titulo: base.titulo,
            calendario: base.calendario,
            inicio: base.inicio,
            fim: base.fim,
            diaInteiro: base.diaInteiro,
            descricao: 'Notas',
          ),
        ),
      );
    });
  });
}
