import 'package:flutter/foundation.dart';

import '../../models/compromisso.dart';
import '../../models/periodo_consulta.dart';
import '../../services/servico_calendario.dart';

/// Situação da tela de compromissos.
enum EstadoConsulta {
  /// Nenhuma consulta foi feita ainda.
  inicial,

  /// Verificando o acesso ou aguardando o calendário.
  carregando,

  /// A consulta terminou e há compromissos a apresentar.
  comCompromissos,

  /// A consulta terminou e não há compromissos no período.
  semCompromissos,

  /// O usuário não autorizou o acesso ao calendário.
  acessoNegado,

  /// Não foi possível concluir a consulta.
  falha,
}

/// Coordena o fluxo: verificar o acesso, consultar e informar o resultado.
class ControladorCompromissos extends ChangeNotifier {
  ControladorCompromissos({
    required this._servico,
    DateTime Function()? relogio,
  }) : _relogio = relogio ?? DateTime.now;

  final ServicoCalendario _servico;
  final DateTime Function() _relogio;

  EstadoConsulta _estado = EstadoConsulta.inicial;
  List<Compromisso> _compromissos = const [];
  PeriodoConsulta? _periodo;
  bool _descartado = false;

  EstadoConsulta get estado => _estado;

  bool get carregando => _estado == EstadoConsulta.carregando;

  /// Compromissos da última consulta concluída, em ordem cronológica.
  List<Compromisso> get compromissos => List.unmodifiable(_compromissos);

  /// Período da consulta mais recente; nulo antes da primeira consulta.
  PeriodoConsulta? get periodo => _periodo;

  /// Verifica o acesso e consulta os compromissos dos próximos sete dias.
  ///
  /// Enquanto uma consulta estiver em andamento novos pedidos são ignorados.
  Future<void> consultar() async {
    if (carregando) return;

    final periodo = PeriodoConsulta.proximosSeteDias(_relogio());
    _periodo = periodo;
    _compromissos = const [];
    _mudarPara(EstadoConsulta.carregando);

    try {
      final acesso = await _servico.verificarAcesso();
      if (_descartado) return;

      if (acesso == SituacaoAcesso.negado) {
        _mudarPara(EstadoConsulta.acessoNegado);
        return;
      }

      final compromissos = await _servico.consultar(periodo);
      if (_descartado) return;

      _compromissos = compromissos;
      _mudarPara(
        compromissos.isEmpty
            ? EstadoConsulta.semCompromissos
            : EstadoConsulta.comCompromissos,
      );
    } catch (_) {
      if (_descartado) return;
      _mudarPara(EstadoConsulta.falha);
    }
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }

  void _mudarPara(EstadoConsulta estado) {
    _estado = estado;
    notifyListeners();
  }
}
