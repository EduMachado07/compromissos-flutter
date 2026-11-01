import 'package:compromissos_app/features/compromissos/models/periodo_consulta.dart';
import 'package:compromissos_app/features/compromissos/presentation/formatacao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../support/fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting(localeDoApp));

  group('formatarData', () {
    test('dia da semana abreviado, dia, mês e ano', () {
      expect(formatarData(DateTime(2026, 11, 3)), 'ter., 03/11/2026');
      expect(formatarData(DateTime(2026, 11, 9)), 'seg., 09/11/2026');
    });

    test('completa dia e mês com zero à esquerda', () {
      expect(formatarData(DateTime(2027, 1, 5)), 'ter., 05/01/2027');
    });
  });

  group('formatarHora', () {
    test('usa 24 horas com dois dígitos', () {
      expect(formatarHora(DateTime(2026, 11, 3, 9, 5)), '09:05');
      expect(formatarHora(DateTime(2026, 11, 3, 0, 0)), '00:00');
      expect(formatarHora(DateTime(2026, 11, 3, 23, 59)), '23:59');
    });
  });

  group('formatarPeriodo', () {
    test('mostra o primeiro e o último dia incluídos', () {
      final periodo = PeriodoConsulta.proximosSeteDias(DateTime(2026, 11, 3));

      expect(formatarPeriodo(periodo), '03/11/2026 a 09/11/2026');
    });

    test('atravessa a virada de ano', () {
      final periodo = PeriodoConsulta.proximosSeteDias(DateTime(2026, 12, 29));

      expect(formatarPeriodo(periodo), '29/12/2026 a 04/01/2027');
    });
  });

  group('formatarQuando', () {
    test('evento com horário no mesmo dia', () {
      final compromisso = compromissoDeTeste(
        inicio: DateTime(2026, 11, 3, 14),
        fim: DateTime(2026, 11, 3, 15, 30),
      );

      expect(formatarQuando(compromisso), 'ter., 03/11/2026 · 14:00 às 15:30');
    });

    test('evento que termina à meia-noite continua no mesmo dia', () {
      final compromisso = compromissoDeTeste(
        inicio: DateTime(2026, 11, 3, 22),
        fim: DateTime(2026, 11, 4),
      );

      expect(formatarQuando(compromisso), 'ter., 03/11/2026 · 22:00 às 00:00');
    });

    test('evento que atravessa a meia-noite mostra as duas datas', () {
      final compromisso = compromissoDeTeste(
        inicio: DateTime(2026, 11, 3, 22),
        fim: DateTime(2026, 11, 4, 2),
      );

      expect(
        formatarQuando(compromisso),
        'ter., 03/11/2026 22:00 a qua., 04/11/2026 02:00',
      );
    });

    test('evento instantâneo mostra apenas o horário de início', () {
      final compromisso = compromissoDeTeste(
        inicio: DateTime(2026, 11, 3, 14),
        fim: DateTime(2026, 11, 3, 14),
      );

      expect(formatarQuando(compromisso), 'ter., 03/11/2026 · 14:00');
    });

    test('dia inteiro em um único dia', () {
      final compromisso = compromissoDeTeste(
        inicio: DateTime(2026, 11, 3),
        fim: DateTime(2026, 11, 4),
        diaInteiro: true,
      );

      expect(formatarQuando(compromisso), 'Dia inteiro · ter., 03/11/2026');
    });

    test('dia inteiro em vários dias mostra o primeiro e o último', () {
      final compromisso = compromissoDeTeste(
        inicio: DateTime(2026, 11, 3),
        fim: DateTime(2026, 11, 6),
        diaInteiro: true,
      );

      expect(
        formatarQuando(compromisso),
        'Dia inteiro · ter., 03/11/2026 a qui., 05/11/2026',
      );
    });
  });
}
