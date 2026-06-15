import 'package:fastdelivery_cliente/features/entregas/data/entrega_api_service.dart';
import 'package:fastdelivery_cliente/features/entregas/presentation/screens/entrega_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('FL08 lista sem entregas mostra estado vazio', (tester) async {
    final client = MockClient((req) async => http.Response('[]', 200));
    final service = EntregaApiService(client: client, baseUrl: 'http://test');

    await tester.pumpWidget(
      MaterialApp(home: EntregaListScreen(service: service)),
    );
    await tester.pump(); // build + initState carregar()
    await tester.pump(const Duration(milliseconds: 20)); // resolve listar()

    expect(find.text('Nenhuma entrega ainda'), findsOneWidget);

    // Desmonta a tela: dispose cancela o timer de polling (sem timers pendentes).
    await tester.pumpWidget(const SizedBox());
  });
}
