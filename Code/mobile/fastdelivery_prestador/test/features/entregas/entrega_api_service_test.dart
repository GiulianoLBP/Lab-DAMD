import 'dart:convert';

import 'package:fastdelivery_prestador/core/http/api_exception.dart';
import 'package:fastdelivery_prestador/features/entregas/data/entrega_api_service.dart';
import 'package:fastdelivery_prestador/features/entregas/domain/status_entrega.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _headers = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

Map<String, dynamic> _entrega({int id = 1, String status = 'pendente'}) => {
  'id': id,
  'descricao': 'Pacote',
  'origem': 'A',
  'destino': 'B',
  'status': status,
  'cliente_id': 'cliente-1',
  'criado_em': 't1',
  'atualizado_em': 't2',
};

void main() {
  test('listar faz GET /entregas com filtro de status e parseia a lista', () async {
    late http.Request capturada;
    final mock = MockClient((req) async {
      capturada = req;
      return http.Response(
        jsonEncode([_entrega(id: 1), _entrega(id: 2)]),
        200,
        headers: _headers,
      );
    });
    final service = EntregaApiService(client: mock, baseUrl: 'http://x');

    final lista = await service.listar(status: 'pendente');

    expect(capturada.method, 'GET');
    expect(capturada.url.path, '/entregas');
    expect(capturada.url.queryParameters['status'], 'pendente');
    expect(lista, hasLength(2));
    expect(lista.first.id, 1);
  });

  test('aceitar envia PATCH status=aceito para o id certo', () async {
    late http.Request capturada;
    final mock = MockClient((req) async {
      capturada = req;
      return http.Response(jsonEncode(_entrega(id: 7, status: 'aceito')), 200,
          headers: _headers);
    });
    final service = EntregaApiService(client: mock, baseUrl: 'http://x');

    final entrega = await service.aceitar(7);

    expect(capturada.method, 'PATCH');
    expect(capturada.url.path, '/entregas/7/status');
    expect(jsonDecode(capturada.body)['status'], 'aceito');
    expect(entrega.status, 'aceito');
  });

  test('recusar mapeia para o status cancelado', () async {
    late http.Request capturada;
    final mock = MockClient((req) async {
      capturada = req;
      return http.Response(jsonEncode(_entrega(id: 3, status: 'cancelado')),
          200, headers: _headers);
    });
    final service = EntregaApiService(client: mock, baseUrl: 'http://x');

    await service.recusar(3);

    expect(jsonDecode(capturada.body)['status'], StatusEntrega.cancelado.valor);
  });

  test('erro {"error": ...} do backend vira ApiException com a mensagem', () async {
    final mock = MockClient(
      (req) async => http.Response(
        jsonEncode({'error': 'Entrega não encontrada'}),
        404,
        headers: _headers,
      ),
    );
    final service = EntregaApiService(client: mock, baseUrl: 'http://x');

    expect(
      () => service.buscarPorId(999),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Entrega não encontrada',
        ),
      ),
    );
  });

  test('falha de rede vira ApiException amigável', () async {
    final mock = MockClient((req) async => throw Exception('sem rede'));
    final service = EntregaApiService(client: mock, baseUrl: 'http://x');

    expect(() => service.listar(), throwsA(isA<ApiException>()));
  });
}
