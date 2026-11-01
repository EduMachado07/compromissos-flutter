import 'dart:async';
import 'dart:collection';

import 'package:compromissos_app/features/compromissos/models/compromisso.dart';
import 'package:compromissos_app/features/compromissos/models/periodo_consulta.dart';
import 'package:compromissos_app/features/compromissos/services/servico_calendario.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

/// Compromisso pronto para os testes de apresentação.
Compromisso compromissoDeTeste({
  String titulo = 'Reunião de equipe',
  String calendario = 'Trabalho',
  DateTime? inicio,
  DateTime? fim,
  bool diaInteiro = false,
  String? local,
  String? descricao,
}) {
  final comeco = inicio ?? DateTime(2026, 11, 3, 9);
  return Compromisso(
    titulo: titulo,
    calendario: calendario,
    inicio: comeco,
    fim: fim ?? comeco.add(const Duration(hours: 1)),
    diaInteiro: diaInteiro,
    local: local,
    descricao: descricao,
  );
}

/// [ServicoCalendario] controlado pelo teste.
class ServicoFalso extends ServicoCalendario {
  ServicoFalso() : super(plugin: PluginFalso());

  SituacaoAcesso acesso = SituacaoAcesso.autorizado;
  List<Compromisso> compromissos = [];

  /// Quando definido, a chamada correspondente lança este objeto.
  Object? lancarAoVerificar;
  Object? lancarAoConsultar;

  /// Quando definido, a chamada só termina quando ele for completado.
  Completer<void>? bloqueioVerificacao;
  Completer<void>? bloqueioConsulta;

  int verificacoes = 0;
  final periodosConsultados = <PeriodoConsulta>[];

  @override
  Future<SituacaoAcesso> verificarAcesso() async {
    verificacoes++;
    await bloqueioVerificacao?.future;
    final erro = lancarAoVerificar;
    if (erro != null) throw erro;
    return acesso;
  }

  @override
  Future<List<Compromisso>> consultar(PeriodoConsulta periodo) async {
    periodosConsultados.add(periodo);
    await bloqueioConsulta?.future;
    final erro = lancarAoConsultar;
    if (erro != null) throw erro;
    return [...compromissos];
  }
}

/// Resultado de sucesso do plugin.
Result<T> resultado<T>(T dados) => Result<T>()..data = dados;

/// Resultado com erro, como o plugin devolve ao capturar uma exceção.
Result<T> resultadoComErro<T>([String mensagem = 'falha simulada']) =>
    Result<T>()..errors.add(ResultError(500, mensagem));

/// Evento com horário em UTC. Os valores são em UTC para que os testes não
/// dependam do fuso da máquina.
Event eventoDeTeste({
  String calendarioId = 'cal-1',
  String? id,
  String? titulo = 'Reunião',
  required DateTime inicio,
  DateTime? fim,
  String? local,
  String? descricao,
}) {
  return Event(
    calendarioId,
    eventId: id,
    title: titulo,
    location: local,
    description: descricao,
    start: tz.TZDateTime.from(inicio, tz.UTC),
    end: tz.TZDateTime.from(
      fim ?? inicio.add(const Duration(hours: 1)),
      tz.UTC,
    ),
  );
}

/// Evento de dia inteiro, no formato que o plugin entrega no Android: início e
/// fim à meia-noite, com o fim apontando para o último dia ocupado.
Event eventoDiaInteiroDeTeste({
  String calendarioId = 'cal-1',
  String? titulo = 'Feriado',
  required DateTime primeiroDia,
  DateTime? ultimoDia,
}) {
  final ultimo = ultimoDia ?? primeiroDia;
  return Event(
    calendarioId,
    title: titulo,
    allDay: true,
    start: tz.TZDateTime.utc(
      primeiroDia.year,
      primeiroDia.month,
      primeiroDia.day,
    ),
    end: tz.TZDateTime.utc(ultimo.year, ultimo.month, ultimo.day),
  );
}

/// Parâmetros recebidos por uma consulta de eventos.
typedef ConsultaDeEventos = ({
  String? calendarioId,
  DateTime? inicio,
  DateTime? fim,
});

/// [DeviceCalendarPlugin] controlado pelo teste, sem canal de plataforma.
///
/// A consulta de eventos devolve tudo o que foi cadastrado para o calendário,
/// sem filtrar por data. Assim os testes verificam o filtro do serviço, já que
/// o Android pode devolver eventos que apenas tocam as bordas do intervalo.
class PluginFalso extends DeviceCalendarPlugin {
  PluginFalso() : super.private();

  /// Estado atual da permissão (leitura e escrita).
  bool permitido = true;

  /// Estado da permissão depois que o usuário responde ao pedido.
  bool permitidoAposPedido = true;

  bool erroAoVerificar = false;
  bool erroAoPedir = false;
  bool erroAoListarCalendarios = false;
  bool listaDeCalendariosNula = false;

  /// Quando definido, a chamada correspondente lança este objeto em vez de
  /// devolver um [Result]. Um `Error` escapa do tratamento do plugin real.
  Object? lancarAoVerificar;
  Object? lancarAoListarCalendarios;
  Object? lancarAoConsultarEventos;

  List<Calendar> calendarios = [];
  final Map<String, List<Event>> eventosPorCalendario = {};
  final Set<String> calendariosComErro = {};

  int verificacoes = 0;
  int pedidos = 0;
  final consultasDeEventos = <ConsultaDeEventos>[];

  @override
  Future<Result<bool>> hasPermissions() async {
    verificacoes++;
    final erro = lancarAoVerificar;
    if (erro != null) throw erro;
    if (erroAoVerificar) return resultadoComErro<bool>();
    return resultado(permitido);
  }

  @override
  Future<Result<bool>> requestPermissions() async {
    pedidos++;
    if (erroAoPedir) return resultadoComErro<bool>();
    permitido = permitidoAposPedido;
    return resultado(permitido);
  }

  @override
  Future<Result<UnmodifiableListView<Calendar>>> retrieveCalendars() async {
    final erro = lancarAoListarCalendarios;
    if (erro != null) throw erro;
    if (erroAoListarCalendarios) {
      return resultadoComErro<UnmodifiableListView<Calendar>>();
    }
    if (listaDeCalendariosNula) return Result<UnmodifiableListView<Calendar>>();
    return resultado(UnmodifiableListView(calendarios));
  }

  @override
  Future<Result<UnmodifiableListView<Event>>> retrieveEvents(
    String? calendarId,
    RetrieveEventsParams? retrieveEventsParams,
  ) async {
    consultasDeEventos.add((
      calendarioId: calendarId,
      inicio: retrieveEventsParams?.startDate,
      fim: retrieveEventsParams?.endDate,
    ));
    final erro = lancarAoConsultarEventos;
    if (erro != null) throw erro;
    if (calendariosComErro.contains(calendarId)) {
      return resultadoComErro<UnmodifiableListView<Event>>();
    }
    return resultado(
      UnmodifiableListView(eventosPorCalendario[calendarId] ?? const []),
    );
  }
}
