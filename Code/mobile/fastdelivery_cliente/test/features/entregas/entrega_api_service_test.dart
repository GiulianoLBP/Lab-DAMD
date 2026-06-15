import 'dart:convert';

import 'package:fastdelivery_cliente/core/http/api_exception.dart';
import 'package:fastdelivery_cliente/features/entregas/data/entrega_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  EntregaApiService comCliente(MockClient client) =>
      EntregaApiService(client: client, baseUrl: 'http://test');

  Map<String, dynamic> entregaJson({int id = 1, String status = 'pendente'}) =>
      <String, dynamic>{
        'id': id,
        'descricao': 'Pacote',
        'origem': 'Rua A',
        'destino': 'Rua B',
        'status': status,
        'cliente_id': 'cliente-demo-001',
      };

  group('EntregaApiService', () {
    test('FL03 listar retorna lista em HTTP 200', () async {
      final client = MockClient((req) async {
        expect(req.method, 'GET');
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            entregaJson(id: 1),
            entregaJson(id: 2, status: 'aceito'),
          ]),
          200,
        );
      });

      final entregas = await comCliente(client).listar();

      expect(entregas, hasLength(2));
      expect(entregas.first.id, 1);
      expect(entregas.last.status, 'aceito');
    });

    test(
      'FL04 resposta {"error": ...} vira ApiException com a mensagem',
      () async {
        final client = MockClient(
          (req) async => http.Response(
            jsonEncode({'error': 'Entrega não encontrada'}),
            404,
          ),
        );

        expect(
          () => comCliente(client).buscarPorId(999),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'Entrega não encontrada',
            ),
          ),
        );
      },
    );

    test(
      'criar envia cliente_id demo, omite status e devolve a entrega',
      () async {
        late String corpoEnviado;
        final client = MockClient((req) async {
          expect(req.method, 'POST');
          corpoEnviado = req.body;
          return http.Response(jsonEncode(entregaJson(id: 10)), 201);
        });

        final entrega = await comCliente(
          client,
        ).criar(descricao: 'Pacote', origem: 'Rua A', destino: 'Rua B');

        final enviado = jsonDecode(corpoEnviado) as Map<String, dynamic>;
        expect(enviado['cliente_id'], 'cliente-demo-001');
        expect(enviado.containsKey('status'), isFalse);
        expect(entrega.id, 10);
        expect(entrega.status, 'pendente');
      },
    );

    test('cancelar faz PATCH com status cancelado', () async {
      late String metodo;
      late String corpoEnviado;
      final client = MockClient((req) async {
        metodo = req.method;
        corpoEnviado = req.body;
        return http.Response(
          jsonEncode(entregaJson(id: 5, status: 'cancelado')),
          200,
        );
      });

      final entrega = await comCliente(client).cancelar(5);

      expect(metodo, 'PATCH');
      expect(jsonDecode(corpoEnviado), <String, String>{'status': 'cancelado'});
      expect(entrega.status, 'cancelado');
    });

    test('falha de rede vira ApiException amigável', () async {
      final client = MockClient(
        (req) async => throw http.ClientException('sem rede'),
      );

      expect(() => comCliente(client).listar(), throwsA(isA<ApiException>()));
    });
  });
}
