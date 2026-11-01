import 'package:compromissos_app/features/compromissos/models/periodo_consulta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('proximosSeteDias', () {
    test('começa à meia-noite de hoje, ignorando o horário atual', () {
      final periodo = PeriodoConsulta.proximosSeteDias(
        DateTime(2026, 11, 3, 15, 42, 10, 500),
      );

      expect(periodo.inicio, DateTime(2026, 11, 3));
    });

    test('termina à meia-noite do oitavo dia (hoje + 6 dias inclusive)', () {
      final periodo = PeriodoConsulta.proximosSeteDias(DateTime(2026, 11, 3));

      expect(periodo.fim, DateTime(2026, 11, 10));
    });

    test('o último dia incluído é hoje + 6', () {
      final periodo = PeriodoConsulta.proximosSeteDias(DateTime(2026, 11, 3));

      expect(periodo.ultimoDia, DateTime(2026, 11, 9));
    });

    test('atravessa a virada de mês', () {
      final periodo = PeriodoConsulta.proximosSeteDias(DateTime(2026, 11, 28));

      expect(periodo.fim, DateTime(2026, 12, 5));
      expect(periodo.ultimoDia, DateTime(2026, 12, 4));
    });

    test('atravessa a virada de ano', () {
      final periodo = PeriodoConsulta.proximosSeteDias(DateTime(2026, 12, 29));

      expect(periodo.fim, DateTime(2027, 1, 5));
      expect(periodo.ultimoDia, DateTime(2027, 1, 4));
    });

    test('considera o dia 29 de fevereiro de ano bissexto', () {
      final periodo = PeriodoConsulta.proximosSeteDias(DateTime(2028, 2, 25));

      expect(periodo.fim, DateTime(2028, 3, 3));
      expect(periodo.ultimoDia, DateTime(2028, 3, 2));
    });

    test('cobre exatamente sete dias de calendário', () {
      final periodo = PeriodoConsulta.proximosSeteDias(DateTime(2026, 3, 1));

      expect(PeriodoConsulta.dias, 7);
      expect(periodo.fim, DateTime(2026, 3, 8));
    });
  });

  group('igualdade', () {
    test('períodos com os mesmos limites são iguais', () {
      final a = PeriodoConsulta(
        inicio: DateTime(2026, 11, 3),
        fim: DateTime(2026, 11, 10),
      );
      final b = PeriodoConsulta.proximosSeteDias(DateTime(2026, 11, 3, 8));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('períodos com limites diferentes não são iguais', () {
      final a = PeriodoConsulta.proximosSeteDias(DateTime(2026, 11, 3));
      final b = PeriodoConsulta.proximosSeteDias(DateTime(2026, 11, 4));

      expect(a, isNot(b));
    });
  });
}
