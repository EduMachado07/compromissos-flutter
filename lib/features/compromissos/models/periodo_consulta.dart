/// Intervalo de datas consultado: [inicio] é inclusivo e [fim] é exclusivo.
class PeriodoConsulta {
  const PeriodoConsulta({required this.inicio, required this.fim});

  /// Hoje e os próximos seis dias, totalizando sete dias de calendário.
  ///
  /// A soma é feita nos campos do calendário (e não com `Duration`) para que o
  /// período continue começando e terminando à meia-noite mesmo quando o fuso
  /// do aparelho muda o horário de verão.
  factory PeriodoConsulta.proximosSeteDias(DateTime agora) {
    return PeriodoConsulta(
      inicio: DateTime(agora.year, agora.month, agora.day),
      fim: DateTime(agora.year, agora.month, agora.day + dias),
    );
  }

  /// Quantidade de dias de calendário do período padrão.
  static const dias = 7;

  /// Meia-noite do primeiro dia (inclusivo).
  final DateTime inicio;

  /// Meia-noite do dia seguinte ao último (exclusivo).
  final DateTime fim;

  /// Último dia de calendário incluído no período.
  DateTime get ultimoDia => DateTime(fim.year, fim.month, fim.day - 1);

  @override
  bool operator ==(Object other) =>
      other is PeriodoConsulta && other.inicio == inicio && other.fim == fim;

  @override
  int get hashCode => Object.hash(inicio, fim);

  @override
  String toString() => 'PeriodoConsulta($inicio até $fim)';
}
