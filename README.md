# Compromissos do calendário

Atividade da Aula 7 (Permissões e acesso a recursos do dispositivo): o app
solicita acesso ao calendário do aparelho e lista os compromissos de **hoje e
dos próximos seis dias** (sete dias), de todos os calendários, em ordem
cronológica.

Cada compromisso mostra título, calendário, data e horário de início e fim,
local e descrição, com a marca "Dia inteiro" quando for o caso. O app informa
carregamento, lista vazia, acesso negado e falha na consulta.

## Como executar

```bash
flutter pub get
flutter test      # testes unitários e de widget
flutter analyze
flutter run       # dispositivo ou emulador Android, com calendário configurado
```

## Estrutura

```
lib/features/compromissos/
  models/         Compromisso (a partir de Event) e PeriodoConsulta (7 dias)
  services/       ServicoCalendario: permissão + consulta ao device_calendar
  presentation/   ControladorCompromissos (estados), formatação, tela e item
test/             espelha lib/ e usa um DeviceCalendarPlugin falso
```

## Decisões

- **Permissões no Android:** o `AndroidManifest.xml` declara `READ_CALENDAR` e
  `WRITE_CALENDAR`. O `device_calendar` só considera o acesso concedido quando
  as duas estão concedidas, então declarar apenas a leitura impediria a
  autorização. Um teste confere o manifesto.
- **Período:** `[hoje 00:00, hoje + 7 dias 00:00)`. Eventos que apenas tocam as
  bordas (o Android os devolve) são descartados pelo serviço.
- **Dia inteiro:** o plugin os entrega à meia-noite em UTC; o dia do calendário
  é usado como veio, sem converter de fuso, para não cair no dia errado.
- **Falhas:** erro em qualquer calendário falha a consulta inteira, para nunca
  omitir compromissos sem avisar. Falha técnica e acesso negado são tratados
  como situações diferentes.
- **Fuso horário:** `timezone` fica em `^0.9.4` porque o `device_calendar`
  4.x exige essa faixa.
- **Build de release (R8):** o Flutter minifica o release, e o `device_calendar`
  serializa as classes dele por reflexão. Sem a regra de
  `android/app/proguard-rules.pro` o R8 renomeia as classes do plugin e
  descarta campos, e o app listaria zero calendários (o `id` se perde). Medido
  no APK de release deste projeto: sem a regra o modelo `Calendar` passa de 8
  campos (`id`, `name`, ...) para 2 campos renomeados (`a`, `b`); com a regra
  mantém os 8. Um teste confere que a regra existe.
- **Compilação Android:** `flutter build apk --debug` funciona com Flutter
  3.47.9 (AGP 9.1, Gradle 9.3, JDK 17). O build avisa que o `device_calendar`
  ainda aplica o Kotlin Gradle Plugin; isso funciona hoje por causa de
  `android.builtInKotlin=false` no `android/gradle.properties`, mas versões
  futuras do Flutter vão recusar o plugin até ele migrar para o Kotlin
  embutido. Não remova essa propriedade.
