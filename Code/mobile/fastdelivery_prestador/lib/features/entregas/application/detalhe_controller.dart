import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/http/api_exception.dart';
import '../data/entrega_api_service.dart';
import '../data/eventos_realtime_service.dart';
import '../domain/entrega.dart';

/// Controlador da tela de detalhe de uma solicitação.
///
/// Carrega a entrega via REST e a mantém atualizada AO VIVO: eventos do MOM
/// referentes a este `entregaId` re-sincronizam a tela. Expõe as ações do
/// prestador (aceitar, recusar, avançar status), cada uma um
/// `PATCH /entregas/<id>/status`.
class DetalheController extends ChangeNotifier {
  DetalheController(
    this._service,
    this._realtime, {
    required this.entregaId,
  });

  final EntregaApiService _service;
  final EventosRealtimeService _realtime;
  final int entregaId;

  Entrega? _entrega;
  Entrega? get entrega => _entrega;

  bool _carregando = false;
  bool get carregando => _carregando;

  String? _erro;
  String? get erro => _erro;

  bool _executandoAcao = false;
  bool get executandoAcao => _executandoAcao;

  StreamSubscription<Map<String, dynamic>>? _evSub;
  bool _emRequisicao = false;
  bool _descartado = false;

  void iniciar() {
    carregar();
    _evSub = _realtime.eventos.listen(_aoEvento);
  }

  Future<void> carregar() async {
    if (_descartado) {
      return;
    }
    _carregando = true;
    _erro = null;
    _notificar();
    await _buscar();
  }

  Future<void> _buscar() async {
    if (_emRequisicao || _descartado) {
      return;
    }
    _emRequisicao = true;
    try {
      _entrega = await _service.buscarPorId(entregaId);
      _erro = null;
    } on ApiException catch (e) {
      if (_entrega == null) {
        _erro = e.message;
      }
    } finally {
      _emRequisicao = false;
      _carregando = false;
      _notificar();
    }
  }

  void _aoEvento(Map<String, dynamic> evento) {
    final dados = (evento['dados'] as Map?) ?? const <dynamic, dynamic>{};
    if (dados['id'] == entregaId) {
      _buscar();
    }
  }

  /// Aceitar a solicitação (`pendente → aceito`). Retorna `true` em sucesso.
  Future<bool> aceitar() => _executar(() => _service.aceitar(entregaId));

  /// Recusar a solicitação (mapeada para `cancelado` — ver docs/Sprint4).
  Future<bool> recusar() => _executar(() => _service.recusar(entregaId));

  /// Avança para o próximo status do fluxo (`aceito → em_transito → concluido`).
  Future<bool> avancar() {
    final proximo = _entrega?.statusEnum?.proximoStatus;
    if (proximo == null) {
      return Future<bool>.value(false);
    }
    return _executar(() => _service.atualizarStatus(entregaId, proximo));
  }

  Future<bool> _executar(Future<Entrega> Function() acao) async {
    if (_executandoAcao || _descartado) {
      return false;
    }
    _executandoAcao = true;
    _notificar();
    try {
      _entrega = await acao();
      _erro = null;
      return true;
    } on ApiException catch (e) {
      _erro = e.message;
      return false;
    } finally {
      _executandoAcao = false;
      _notificar();
    }
  }

  void _notificar() {
    if (!_descartado) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _descartado = true;
    _evSub?.cancel();
    super.dispose();
  }
}
