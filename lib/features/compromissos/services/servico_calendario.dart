import 'dart:collection';

import 'package:device_calendar/device_calendar.dart';

import '../models/compromisso.dart';
import '../models/periodo_consulta.dart';

/// Resposta à verificação e à solicitação de acesso ao calendário.
enum SituacaoAcesso { autorizado, negado }

/// Falha técnica ao falar com o calendário do aparelho.
///
/// É diferente de [SituacaoAcesso.negado]: aqui a operação não pôde ser
/// concluída, e não que o usuário tenha recusado o acesso.
class FalhaCalendarioException implements Exception {
  const FalhaCalendarioException(this.mensagem);

  final String mensagem;

  @override
  String toString() => 'FalhaCalendarioException: $mensagem';
}

/// Verifica a permissão e consulta os compromissos do calendário do aparelho.
class ServicoCalendario {
  ServicoCalendario({DeviceCalendarPlugin? plugin})
    : _plugin = plugin ?? DeviceCalendarPlugin();

  /// Nome usado quando o calendário não informa nome nem conta.
  static const calendarioSemNome = 'Calendário sem nome';

  final DeviceCalendarPlugin _plugin;

  /// Verifica o acesso e, se ainda não houver, solicita ao usuário.
  ///
  /// O plugin trata leitura e escrita juntas: só informa acesso concedido
  /// quando as duas permissões foram concedidas.
  Future<SituacaoAcesso> verificarAcesso() async {
    final autorizado = await _chamar(
      'verificar a permissão de acesso ao calendário',
      _plugin.hasPermissions,
      (concedido) => concedido,
    );
    if (autorizado) return SituacaoAcesso.autorizado;

    final concedido = await _chamar(
      'solicitar a permissão de acesso ao calendário',
      _plugin.requestPermissions,
      (concedido) => concedido,
    );
    return concedido ? SituacaoAcesso.autorizado : SituacaoAcesso.negado;
  }

  /// Compromissos de todos os calendários que ocupam algum instante de
  /// [periodo], em ordem cronológica.
  ///
  /// Se qualquer calendário falhar a consulta inteira falha, para que nenhum
  /// compromisso deixe de aparecer sem que o usuário saiba. As consultas são
  /// feitas uma de cada vez porque o plugin atende um canal único.
  Future<List<Compromisso>> consultar(PeriodoConsulta periodo) async {
    final calendarios = await _chamarLista(
      'listar os calendários',
      _plugin.retrieveCalendars,
    );

    final compromissos = <Compromisso>[];
    for (final calendario in calendarios) {
      final id = calendario.id;
      if (id == null) continue;

      final nome = _nomeDo(calendario);
      final eventos = await _chamarLista(
        'consultar os compromissos do calendário "$nome"',
        () => _plugin.retrieveEvents(
          id,
          RetrieveEventsParams(startDate: periodo.inicio, endDate: periodo.fim),
        ),
      );

      for (final evento in eventos) {
        if (evento.start == null) continue;

        final compromisso = Compromisso.deEvento(evento, calendario: nome);
        // O Android devolve também eventos que apenas tocam as bordas do
        // intervalo; eles não pertencem aos sete dias consultados.
        if (compromisso.ocorreNoPeriodo(periodo)) compromissos.add(compromisso);
      }
    }

    compromissos.sort(Compromisso.comparar);
    return compromissos;
  }

  /// Como [_chamar], para chamadas que devolvem uma lista.
  ///
  /// O plugin só converte cada item (`Event.fromJson`, `Calendar.fromJson`)
  /// quando a lista é percorrida. Copiar aqui, dentro do tratamento de erros,
  /// evita que um dado inesperado estoure mais adiante como exceção qualquer.
  Future<List<E>> _chamarLista<E>(
    String operacao,
    Future<Result<UnmodifiableListView<E>>> Function() chamada,
  ) {
    return _chamar(operacao, chamada, (itens) => itens.toList());
  }

  /// Executa uma chamada ao plugin e aplica [converter] aos dados, ou lança
  /// [FalhaCalendarioException].
  ///
  /// O plugin guarda as exceções no [Result], mas um [Error] escapa dele; por
  /// isso qualquer objeto lançado, inclusive por [converter], também vira
  /// falha.
  Future<R> _chamar<T, R>(
    String operacao,
    Future<Result<T>> Function() chamada,
    R Function(T dados) converter,
  ) async {
    final falha = FalhaCalendarioException('Não foi possível $operacao.');

    try {
      final resposta = await chamada();
      final dados = resposta.data;
      if (resposta.hasErrors || dados == null) throw falha;
      return converter(dados);
    } on FalhaCalendarioException {
      rethrow;
    } catch (_) {
      throw falha;
    }
  }

  String _nomeDo(Calendar calendario) {
    for (final candidato in [calendario.name, calendario.accountName]) {
      final nome = candidato?.trim();
      if (nome != null && nome.isNotEmpty) return nome;
    }
    return calendarioSemNome;
  }
}
