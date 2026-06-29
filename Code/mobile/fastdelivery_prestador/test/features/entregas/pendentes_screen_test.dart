import 'dart:convert';

import 'package:fastdelivery_prestador/features/entregas/data/entrega_api_service.dart';
import 'package:fastdelivery_prestador/features/entregas/data/eventos_realtime_service.dart';
import 'package:fastdelivery_prestador/features/entregas/presentation/screens/pendentes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _entrega(int id, String descricao) => {
  'id': id,
  'descricao': descricao,
  'origem': 'A',
  'destino': 'B',
  'status': 'pendente',
  'cliente_id': 'cliente-1',
  'criado_em': 't1',
  'atualizado_em': 't2',
};

void main() {
  testWidgets('PendentesScreen renderiza as solicitações pendentes carregadas',
      (tester) async {
    final mock = MockClient(
      (req) async => http.Response(
        jsonEncode([_entrega(1, 'Pacote A'), _entrega(2, 'Pacote B')]),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final service = EntregaApiService(client: mock, baseUrl: 'http://x');
    // Sem chamar conectar(): o serviço de tempo real não abre conexão nem timers
    // — o teste valida apenas a carga REST inicial e a renderização da lista.
    final realtime = EventosRealtimeService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PendentesScreen(service: service, realtime: realtime),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pacote A'), findsOneWidget);
    expect(find.text('Pacote B'), findsOneWidget);

    await realtime.dispose();
  });
}
