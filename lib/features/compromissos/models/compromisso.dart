import 'package:device_calendar/device_calendar.dart';

import 'periodo_consulta.dart';

/// Compromisso do calendário já preparado para ser apresentado.
///
/// Todas as datas são [DateTime] no fuso do aparelho. Em eventos de dia inteiro
/// [inicio] é a meia-noite do primeiro dia e [fim] é a meia-noite do dia
/// seguinte ao último, de modo que a sobreposição com um período segue a mesma
/// regra dos eventos com horário.
class Compromisso {
  const Compromisso({
    required this.titulo,
    required this.calendario,
    required this.inicio,
    required this.fim,
    required this.diaInteiro,
    this.local,
    this.descricao,
  });

  /// Converte um [Event] do plugin. O evento precisa ter [Event.start].
  factory Compromisso.deEvento(Event evento, {required String calendario}) {
    final comeco = evento.start;
    if (comeco == null) {
      throw ArgumentError.value(evento, 'evento', 'o evento não tem início');
    }

    final diaInteiro = evento.allDay ?? false;
    final DateTime inicio;
    final DateTime fim;

    if (diaInteiro) {
      // O dia do calendário vale como está; converter para outro fuso poderia
      // deslocar o evento para o dia anterior ou seguinte.
      inicio = DateTime(comeco.year, comeco.month, comeco.day);
      final ultimo = evento.end ?? comeco;
      final dataFim = DateTime(ultimo.year, ultimo.month, ultimo.day + 1);
      fim = dataFim.isAfter(inicio)
          ? dataFim
          : DateTime(inicio.year, inicio.month, inicio.day + 1);
    } else {
      inicio = DateTime.fromMillisecondsSinceEpoch(
        comeco.millisecondsSinceEpoch,
      );
      final termino = evento.end;
      final candidato = termino == null
          ? inicio
          : DateTime.fromMillisecondsSinceEpoch(termino.millisecondsSinceEpoch);
      fim = candidato.isBefore(inicio) ? inicio : candidato;
    }

    return Compromisso(
      titulo: _textoOu(evento.title) ?? semTitulo,
      calendario: calendario,
      inicio: inicio,
      fim: fim,
      diaInteiro: diaInteiro,
      local: _textoOu(evento.location),
      descricao: _textoOu(evento.description),
    );
  }

  /// Título exibido quando o evento não tem nome.
  static const semTitulo = 'Sem título';

  final String titulo;
  final String calendario;
  final DateTime inicio;
  final DateTime fim;
  final bool diaInteiro;
  final String? local;
  final String? descricao;

  /// Último dia de calendário ocupado pelo compromisso.
  ///
  /// Um evento que termina exatamente à meia-noite pertence ao dia anterior.
  DateTime get ultimoDia {
    final ultimoInstante = fim.isAfter(inicio)
        ? fim.subtract(const Duration(microseconds: 1))
        : inicio;
    return DateTime(
      ultimoInstante.year,
      ultimoInstante.month,
      ultimoInstante.day,
    );
  }

  /// Indica se o compromisso ocupa algum instante de [periodo].
  ///
  /// Eventos que terminam exatamente no início, ou começam exatamente no fim,
  /// do período não contam. O plugin pode devolvê-los porque o Android inclui
  /// as bordas ao consultar.
  bool ocorreNoPeriodo(PeriodoConsulta periodo) {
    if (!inicio.isBefore(periodo.fim)) return false;
    if (fim.isAfter(periodo.inicio)) return true;
    // Evento instantâneo: só entra se estiver dentro do período.
    return !inicio.isBefore(periodo.inicio);
  }

  /// Ordem cronológica: início, fim, título (sem diferenciar maiúsculas) e,
  /// por fim, calendário, para que o resultado seja sempre o mesmo.
  static int comparar(Compromisso a, Compromisso b) {
    final porInicio = a.inicio.compareTo(b.inicio);
    if (porInicio != 0) return porInicio;

    final porFim = a.fim.compareTo(b.fim);
    if (porFim != 0) return porFim;

    final porTitulo = a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    if (porTitulo != 0) return porTitulo;

    return a.calendario.compareTo(b.calendario);
  }

  static String? _textoOu(String? texto) {
    final limpo = texto?.trim();
    return limpo == null || limpo.isEmpty ? null : limpo;
  }

  @override
  bool operator ==(Object other) =>
      other is Compromisso &&
      other.titulo == titulo &&
      other.calendario == calendario &&
      other.inicio == inicio &&
      other.fim == fim &&
      other.diaInteiro == diaInteiro &&
      other.local == local &&
      other.descricao == descricao;

  @override
  int get hashCode => Object.hash(
    titulo,
    calendario,
    inicio,
    fim,
    diaInteiro,
    local,
    descricao,
  );

  @override
  String toString() => 'Compromisso($titulo, $calendario, $inicio → $fim)';
}
