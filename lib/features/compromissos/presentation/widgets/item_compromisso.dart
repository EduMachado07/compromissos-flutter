import 'package:flutter/material.dart';

import '../../models/compromisso.dart';
import '../formatacao.dart';

/// Cartão com os dados de um compromisso.
class ItemCompromisso extends StatelessWidget {
  const ItemCompromisso({super.key, required this.compromisso});

  final Compromisso compromisso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final local = compromisso.local;
    final descricao = compromisso.descricao;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    compromisso.titulo,
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (compromisso.diaInteiro) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('Dia inteiro'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _Linha(icone: Icons.calendar_month, texto: compromisso.calendario),
            _Linha(icone: Icons.schedule, texto: formatarQuando(compromisso)),
            _Linha(
              icone: Icons.place_outlined,
              texto: local ?? 'Local não informado',
              esmaecido: local == null,
            ),
            _Linha(
              icone: Icons.notes,
              texto: descricao ?? 'Sem descrição',
              esmaecido: descricao == null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.icone,
    required this.texto,
    this.esmaecido = false,
  });

  final IconData icone;
  final String texto;
  final bool esmaecido;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final cor = esmaecido ? cores.onSurfaceVariant : null;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: cores.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: cor,
                fontStyle: esmaecido ? FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
