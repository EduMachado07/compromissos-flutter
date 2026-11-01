import 'package:flutter/material.dart';

import '../../models/periodo_consulta.dart';
import '../../services/servico_calendario.dart';
import '../controllers/controlador_compromissos.dart';
import '../formatacao.dart';
import '../widgets/item_compromisso.dart';

/// Tela única do aplicativo: consulta e lista os compromissos dos próximos
/// sete dias, informando acesso negado, lista vazia e falhas.
class TelaCompromissos extends StatefulWidget {
  const TelaCompromissos({super.key, required this.servico, this.relogio});

  final ServicoCalendario servico;

  /// Fornece "agora"; os testes usam um relógio fixo.
  final DateTime Function()? relogio;

  @override
  State<TelaCompromissos> createState() => _TelaCompromissosState();
}

class _TelaCompromissosState extends State<TelaCompromissos> {
  late final ControladorCompromissos _controlador = ControladorCompromissos(
    servico: widget.servico,
    relogio: widget.relogio,
  );

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  String _mensagem() {
    final periodo = _controlador.periodo;
    final texto = periodo == null ? '' : formatarPeriodo(periodo);

    return switch (_controlador.estado) {
      EstadoConsulta.inicial =>
        'Pressione o botão para consultar os compromissos dos próximos '
            '${PeriodoConsulta.dias} dias.',
      EstadoConsulta.carregando => 'Consultando o calendário...',
      EstadoConsulta.comCompromissos =>
        '${_controlador.compromissos.length} compromisso(s) de $texto.',
      EstadoConsulta.semCompromissos => 'Nenhum compromisso de $texto.',
      EstadoConsulta.acessoNegado =>
        'O acesso ao calendário não foi autorizado. Autorize o acesso nas '
            'configurações do aplicativo para consultar os compromissos.',
      EstadoConsulta.falha =>
        'Não foi possível consultar os compromissos. Tente novamente.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controlador,
      builder: (context, _) {
        final carregando = _controlador.carregando;
        final compromissos = _controlador.compromissos;

        return Scaffold(
          appBar: AppBar(title: const Text('Compromissos do calendário')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: carregando ? null : _controlador.consultar,
                  child: const Text('Consultar compromissos'),
                ),
                const SizedBox(height: 12),
                Text(_mensagem()),
                const SizedBox(height: 16),
                Expanded(
                  child: carregando
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: compromissos.length,
                          itemBuilder: (context, indice) => ItemCompromisso(
                            compromisso: compromissos[indice],
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
