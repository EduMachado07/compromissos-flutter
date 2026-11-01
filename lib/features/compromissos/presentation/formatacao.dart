import 'package:intl/intl.dart';

import '../models/compromisso.dart';
import '../models/periodo_consulta.dart';

/// Idioma das datas. É preciso chamar `initializeDateFormatting` com ele antes
/// de usar as funções deste arquivo.
const localeDoApp = 'pt_BR';

/// Ex.: `ter., 03/11/2026`.
String formatarData(DateTime data) =>
    DateFormat('EEE, dd/MM/yyyy', localeDoApp).format(data);

/// Ex.: `14:05`.
String formatarHora(DateTime data) =>
    DateFormat('HH:mm', localeDoApp).format(data);

/// Ex.: `03/11/2026 a 09/11/2026`, do primeiro ao último dia incluídos.
String formatarPeriodo(PeriodoConsulta periodo) {
  final formato = DateFormat('dd/MM/yyyy', localeDoApp);
  return '${formato.format(periodo.inicio)} a ${formato.format(periodo.ultimoDia)}';
}

/// Descreve quando o compromisso acontece, com data e horário de início e fim.
String formatarQuando(Compromisso compromisso) {
  final inicio = compromisso.inicio;
  final ultimoDia = compromisso.ultimoDia;
  final mesmoDia = ultimoDia == DateTime(inicio.year, inicio.month, inicio.day);

  if (compromisso.diaInteiro) {
    final primeiro = formatarData(inicio);
    return mesmoDia
        ? 'Dia inteiro · $primeiro'
        : 'Dia inteiro · $primeiro a ${formatarData(ultimoDia)}';
  }

  final fim = compromisso.fim;
  if (!mesmoDia) {
    return '${formatarData(inicio)} ${formatarHora(inicio)} a '
        '${formatarData(fim)} ${formatarHora(fim)}';
  }

  if (fim == inicio) return '${formatarData(inicio)} · ${formatarHora(inicio)}';
  return '${formatarData(inicio)} · ${formatarHora(inicio)} às ${formatarHora(fim)}';
}
