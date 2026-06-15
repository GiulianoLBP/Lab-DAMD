import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/http/api_exception.dart';
import '../domain/entrega.dart';
import '../domain/status_entrega.dart';

/// Cliente REST do backend FastDelivery.
///
/// Encapsula as quatro rotas usadas pelo app e traduz respostas
/// `{"error": "..."}` e falhas de rede em [ApiException], para a UI só precisar
/// exibir a mensagem. O [http.Client] é injetável para testes (MockClient).
class EntregaApiService {
  EntregaApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Map<String, String> _jsonHeaders = <String, String>{
    'Content-Type': 'application/json',
  };

  /// `GET /entregas` (filtro opcional por status).
  Future<List<Entrega>> listar({String? status}) async {
    final uri = Uri.parse('$_baseUrl/entregas').replace(
      queryParameters: status == null
          ? null
          : <String, String>{'status': status},
    );
    final resp = await _enviar(() => _client.get(uri));
    _garantirSucesso(resp);
    final dynamic corpo = _decodificar(resp.body);
    if (corpo is! List) {
      throw const ApiException(
        'Resposta inesperada do servidor ao listar entregas',
      );
    }
    return corpo
        .whereType<Map<String, dynamic>>()
        .map(Entrega.fromJson)
        .toList(growable: false);
  }

  /// `GET /entregas/<id>`.
  Future<Entrega> buscarPorId(int id) async {
    final resp = await _enviar(
      () => _client.get(Uri.parse('$_baseUrl/entregas/$id')),
    );
    _garantirSucesso(resp);
    return Entrega.fromJson(_decodificarObjeto(resp.body));
  }

  /// `POST /entregas`. O backend define `status = pendente`; o app não o envia.
  Future<Entrega> criar({
    required String descricao,
    required String origem,
    required String destino,
    String clienteId = ApiConfig.clienteIdDemo,
  }) async {
    final resp = await _enviar(
      () => _client.post(
        Uri.parse('$_baseUrl/entregas'),
        headers: _jsonHeaders,
        body: jsonEncode(<String, String>{
          'descricao': descricao,
          'origem': origem,
          'destino': destino,
          'cliente_id': clienteId,
        }),
      ),
    );
    _garantirSucesso(resp);
    return Entrega.fromJson(_decodificarObjeto(resp.body));
  }

  /// `PATCH /entregas/<id>/status` com `cancelado`.
  ///
  /// É o único status que o cliente define na Sprint 3 (aceitar/transitar/
  /// concluir pertencem ao prestador).
  Future<Entrega> cancelar(int id) async {
    final resp = await _enviar(
      () => _client.patch(
        Uri.parse('$_baseUrl/entregas/$id/status'),
        headers: _jsonHeaders,
        body: jsonEncode(<String, String>{
          'status': StatusEntrega.cancelado.valor,
        }),
      ),
    );
    _garantirSucesso(resp);
    return Entrega.fromJson(_decodificarObjeto(resp.body));
  }

  /// Libera o cliente HTTP subjacente.
  void dispose() => _client.close();

  // ─── infraestrutura interna ────────────────────────────────────────

  Future<http.Response> _enviar(
    Future<http.Response> Function() requisicao,
  ) async {
    try {
      return await requisicao();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar ao servidor. '
        'Verifique se o backend está em execução.',
      );
    }
  }

  void _garantirSucesso(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }
    throw ApiException(_mensagemErro(resp), statusCode: resp.statusCode);
  }

  String _mensagemErro(http.Response resp) {
    try {
      final dynamic corpo = _decodificar(resp.body);
      if (corpo is Map && corpo['error'] is String) {
        return corpo['error'] as String;
      }
    } catch (_) {
      // Corpo não-JSON: cai no texto genérico abaixo.
    }
    return 'Falha na comunicação com o servidor (HTTP ${resp.statusCode}).';
  }

  dynamic _decodificar(String corpo) {
    if (corpo.isEmpty) {
      return null;
    }
    return jsonDecode(corpo);
  }

  Map<String, dynamic> _decodificarObjeto(String corpo) {
    final dynamic decodificado = _decodificar(corpo);
    if (decodificado is Map<String, dynamic>) {
      return decodificado;
    }
    throw const ApiException('Resposta inesperada do servidor');
  }
}
