import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/http/api_exception.dart';
import '../domain/entrega.dart';
import '../domain/status_entrega.dart';

/// Cliente REST do backend FastDelivery, na perspectiva do PRESTADOR.
///
/// Reutiliza exatamente os mesmos endpoints do app cliente (sem inventar rotas):
/// consulta entregas e atualiza status. As transições do prestador (aceitar,
/// recusar, iniciar trânsito, concluir) são todas `PATCH /entregas/<id>/status`.
/// O [http.Client] é injetável para testes (MockClient).
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

  /// `PATCH /entregas/<id>/status` — base de todas as ações do prestador.
  Future<Entrega> atualizarStatus(int id, StatusEntrega novo) async {
    final resp = await _enviar(
      () => _client.patch(
        Uri.parse('$_baseUrl/entregas/$id/status'),
        headers: _jsonHeaders,
        body: jsonEncode(<String, String>{'status': novo.valor}),
      ),
    );
    _garantirSucesso(resp);
    return Entrega.fromJson(_decodificarObjeto(resp.body));
  }

  /// Aceitar a solicitação: `pendente → aceito`.
  Future<Entrega> aceitar(int id) =>
      atualizarStatus(id, StatusEntrega.aceito);

  /// Recusar a solicitação. Reutiliza o status `cancelado` — o contrato não tem
  /// um status "recusado" e a Sprint 4 evita inventar um novo (ver docs/Sprint4).
  Future<Entrega> recusar(int id) =>
      atualizarStatus(id, StatusEntrega.cancelado);

  /// Iniciar o trânsito: `aceito → em_transito`.
  Future<Entrega> iniciarTransito(int id) =>
      atualizarStatus(id, StatusEntrega.emTransito);

  /// Concluir a entrega: `em_transito → concluido`.
  Future<Entrega> concluir(int id) =>
      atualizarStatus(id, StatusEntrega.concluido);

  /// Libera o cliente HTTP subjacente.
  void dispose() => _client.close();

  // ─── infraestrutura interna (idêntica à do app cliente) ─────────────

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
