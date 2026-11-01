import 'package:flutter/material.dart';

import 'features/compromissos/presentation/screens/tela_compromissos.dart';
import 'features/compromissos/services/servico_calendario.dart';

/// Configura o [MaterialApp] e define a tela inicial.
class App extends StatelessWidget {
  App({super.key, ServicoCalendario? servico})
    : servico = servico ?? ServicoCalendario();

  final ServicoCalendario servico;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Compromissos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: TelaCompromissos(servico: servico),
    );
  }
}
