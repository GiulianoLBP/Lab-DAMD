import 'dart:async';
import 'dart:convert';

import 'package:fastdelivery_cliente/features/entregas/data/entrega_api_service.dart';
import 'package:fastdelivery_cliente/features/entregas/domain/entrega.dart';
import 'package:fastdelivery_cliente/features/entregas/presentation/screens/entrega_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('FL05 formulário vazio mostra validação e não envia', (
    tester,
  ) async {
    var chamouApi = false;
    final client = MockClient((req) async {
      chamouApi = true;
      return http.Response('{}', 201);
    });
    final service = EntregaApiService(client: client, baseUrl: 'http://test');

    await tester.pumpWidget(
      MaterialApp(home: EntregaFormScreen(service: service)),
    );
    await tester.tap(find.byKey(const Key('btn_enviar')));
    await tester.pump();

    expect(find.text('Informe a descrição'), findsOneWidget);
    expect(find.text('Informe a origem'), findsOneWidget);
    expect(find.text('Informe o destino'), findsOneWidget);
    expect(chamouApi, isFalse);
  });

  testWidgets('FL06 formulário válido chama criação e mostra carregando', (
    tester,
  ) async {
    final completer = Completer<http.Response>();
    final client = MockClient((req) => completer.future);
    final service = EntregaApiService(client: client, baseUrl: 'http://test');
    Entrega? criada;

    await tester.pumpWidget(
      MaterialApp(
        home: EntregaFormScreen(service: service, onCreated: (e) => criada = e),
      ),
    );

    await tester.enterText(find.byKey(const Key('campo_descricao')), 'Pacote');
    await tester.enterText(find.byKey(const Key('campo_origem')), 'Rua A');
    await tester.enterText(find.byKey(const Key('campo_destino')), 'Rua B');
    await tester.tap(find.byKey(const Key('btn_enviar')));
    await tester.pump(); // dispara o envio (estado de carregamento)

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Enviando...'), findsOneWidget);

    completer.complete(
      http.Response(
        jsonEncode(<String, dynamic>{
          'id': 99,
          'descricao': 'Pacote',
          'origem': 'Rua A',
          'destino': 'Rua B',
          'status': 'pendente',
          'cliente_id': 'cliente-demo-001',
        }),
        201,
      ),
    );
    await tester.pump(); // processa a resposta de sucesso

    expect(criada, isNotNull);
    expect(criada!.id, 99);

    // Desmonta a tela para dispensar o indicador animado antes do teardown.
    await tester.pumpWidget(const SizedBox());
  });
}
