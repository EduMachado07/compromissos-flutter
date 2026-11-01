import 'dart:convert';

import 'package:compromissos_app/features/compromissos/models/periodo_consulta.dart';
import 'package:compromissos_app/features/compromissos/services/servico_calendario.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Teste de contrato: usa o [DeviceCalendarPlugin] de verdade e simula apenas o
/// canal nativo, devolvendo o JSON no formato que o código Kotlin do plugin
/// produz. Assim a integração com a conversão real de `Event`/`Calendar` fica
/// coberta, o que o plugin falso dos outros testes não garante.
///
/// Eventos de dia inteiro não entram aqui: o ajuste que o plugin faz nesse caso
/// só é aplicado quando `Platform.isAndroid` é verdadeiro, o que não vale no
/// ambiente de teste.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('plugins.builttoroam.com/device_calendar');
  final periodo = PeriodoConsulta(
    inicio: DateTime(2026, 11, 3),
    fim: DateTime(2026, 11, 10),
  );

  late List<MethodCall> chamadas;
  late Future<Object?> Function(MethodCall) nativo;
  late ServicoCalendario servico;

  Map<String, Object?> calendario(String id, String nome) => {
    'id': id,
    'name': nome,
    'isReadOnly': false,
    'isDefault': false,
    'color': -16776961,
    'accountName': 'eu@exemplo.com',
    'accountType': 'com.google',
  };

  Map<String, Object?> evento({
    required String calendarioId,
    required DateTime inicio,
    required DateTime fim,
    String? titulo,
    String? local,
    String? descricao,
  }) => {
    'eventId': '${inicio.millisecondsSinceEpoch}',
    'calendarId': calendarioId,
    'eventTitle': titulo,
    'eventDescription': descricao,
    'eventStartDate': inicio.millisecondsSinceEpoch,
    'eventStartTimeZone': 'America/Sao_Paulo',
    'eventEndDate': fim.millisecondsSinceEpoch,
    'eventEndTimeZone': null,
    'eventAllDay': false,
    'eventLocation': local,
    'eventURL': null,
    'availability': 'BUSY',
    'eventStatus': 'CONFIRMED',
  };

  setUp(() {
    chamadas = [];
    nativo = (_) async => null;
    servico = ServicoCalendario();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (chamada) async {
          chamadas.add(chamada);
          return nativo(chamada);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  List<String> metodos() => chamadas.map((c) => c.method).toList();

  group('verificarAcesso', () {
    test('já autorizado: só consulta o estado da permissão', () async {
      nativo = (_) async => true;

      expect(await servico.verificarAcesso(), SituacaoAcesso.autorizado);
      expect(metodos(), ['hasPermissions']);
    });

    test('não autorizado e o usuário aceita: solicita e autoriza', () async {
      nativo = (c) async => c.method == 'requestPermissions';

      expect(await servico.verificarAcesso(), SituacaoAcesso.autorizado);
      expect(metodos(), ['hasPermissions', 'requestPermissions']);
    });

    test('não autorizado e o usuário recusa: acesso negado', () async {
      nativo = (_) async => false;

      expect(await servico.verificarAcesso(), SituacaoAcesso.negado);
      expect(metodos(), ['hasPermissions', 'requestPermissions']);
    });

    test('erro da plataforma vira falha', () async {
      nativo = (_) async => throw PlatformException(code: 'ERRO');

      await expectLater(
        servico.verificarAcesso(),
        throwsA(isA<FalhaCalendarioException>()),
      );
    });
  });

  group('consultar', () {
    test('lê os calendários e os eventos de cada um, em ordem', () async {
      final pessoal = evento(
        calendarioId: '1',
        titulo: 'Dentista',
        local: 'Clínica Sorriso',
        descricao: 'Levar exames',
        inicio: DateTime.utc(2026, 11, 6, 12),
        fim: DateTime.utc(2026, 11, 6, 13),
      );
      final trabalho = evento(
        calendarioId: '2',
        titulo: 'Reunião',
        inicio: DateTime.utc(2026, 11, 4, 17),
        fim: DateTime.utc(2026, 11, 4, 18, 30),
      );
      nativo = (c) async => switch (c.method) {
        'retrieveCalendars' => jsonEncode([
          calendario('1', 'Pessoal'),
          calendario('2', 'Trabalho'),
        ]),
        'retrieveEvents' => jsonEncode([
          if ((c.arguments as Map)['calendarId'] == '1') pessoal else trabalho,
        ]),
        _ => null,
      };

      final compromissos = await servico.consultar(periodo);

      expect(compromissos.map((c) => (c.titulo, c.calendario)), [
        ('Reunião', 'Trabalho'),
        ('Dentista', 'Pessoal'),
      ]);
      final dentista = compromissos.last;
      expect(dentista.local, 'Clínica Sorriso');
      expect(dentista.descricao, 'Levar exames');
      expect(
        dentista.inicio.isAtSameMomentAs(DateTime.utc(2026, 11, 6, 12)),
        isTrue,
      );
      expect(
        dentista.fim.isAtSameMomentAs(DateTime.utc(2026, 11, 6, 13)),
        isTrue,
      );
      expect(dentista.diaInteiro, isFalse);
    });

    test('envia ao canal o calendário e o intervalo do período', () async {
      nativo = (c) async => switch (c.method) {
        'retrieveCalendars' => jsonEncode([calendario('7', 'Pessoal')]),
        'retrieveEvents' => jsonEncode([]),
        _ => null,
      };

      await servico.consultar(periodo);

      expect(metodos(), ['retrieveCalendars', 'retrieveEvents']);
      final argumentos = chamadas.last.arguments as Map;
      expect(argumentos['calendarId'], '7');
      expect(argumentos['startDate'], periodo.inicio.millisecondsSinceEpoch);
      expect(argumentos['endDate'], periodo.fim.millisecondsSinceEpoch);
    });

    test('campos opcionais nulos viram os textos padrão', () async {
      nativo = (c) async => switch (c.method) {
        'retrieveCalendars' => jsonEncode([calendario('1', 'Pessoal')]),
        'retrieveEvents' => jsonEncode([
          evento(
            calendarioId: '1',
            inicio: DateTime.utc(2026, 11, 4, 12),
            fim: DateTime.utc(2026, 11, 4, 13),
          ),
        ]),
        _ => null,
      };

      final compromisso = (await servico.consultar(periodo)).single;

      expect(compromisso.titulo, 'Sem título');
      expect(compromisso.local, isNull);
      expect(compromisso.descricao, isNull);
    });

    test('sem calendários cadastrados: lista vazia', () async {
      nativo = (c) async => c.method == 'retrieveCalendars' ? '[]' : null;

      expect(await servico.consultar(periodo), isEmpty);
      expect(metodos(), ['retrieveCalendars']);
    });

    test('erro da plataforma ao listar calendários vira falha', () async {
      nativo = (_) async => throw PlatformException(code: 'ERRO');

      await expectLater(
        servico.consultar(periodo),
        throwsA(isA<FalhaCalendarioException>()),
      );
    });

    test('resposta que não é JSON vira falha', () async {
      nativo = (c) async =>
          c.method == 'retrieveCalendars' ? 'isto não é json' : null;

      await expectLater(
        servico.consultar(periodo),
        throwsA(isA<FalhaCalendarioException>()),
      );
    });

    test('calendário com dado de tipo inesperado vira falha', () async {
      // O plugin converte cada item só quando a lista é percorrida.
      nativo = (c) async => c.method == 'retrieveCalendars'
          ? jsonEncode([
              {...calendario('1', 'Pessoal'), 'id': 123},
            ])
          : null;

      await expectLater(
        servico.consultar(periodo),
        throwsA(isA<FalhaCalendarioException>()),
      );
    });

    test(
      'dado de tipo inesperado (um Error que o plugin não captura) vira falha',
      () async {
        nativo = (c) async => switch (c.method) {
          'retrieveCalendars' => jsonEncode([calendario('1', 'Pessoal')]),
          'retrieveEvents' => jsonEncode([
            {
              ...evento(
                calendarioId: '1',
                inicio: DateTime.utc(2026, 11, 4, 12),
                fim: DateTime.utc(2026, 11, 4, 13),
              ),
              'eventStartDate': 'não é número',
            },
          ]),
          _ => null,
        };

        await expectLater(
          servico.consultar(periodo),
          throwsA(isA<FalhaCalendarioException>()),
        );
      },
    );
  });
}
