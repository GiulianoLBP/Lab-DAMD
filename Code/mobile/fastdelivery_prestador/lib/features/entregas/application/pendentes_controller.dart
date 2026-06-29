import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/http/api_exception.dart';
import '../data/entrega_api_service.dart';
import '../data/eventos_realtime_service.dart';
import '../domain/entrega.dart';
import '../domain/status_entrega.dart';

/// Controlador da lista de solicitações PENDENTES.
///
/// Carga inicial via REST (`GET /entregas?status=pendente`) e atualizações AO
/// VIVO pelos eventos do MOM (WebSocket): em `entrega.criada` re-sincroniza e
/// emite uma [notificacoes] (snackbar) — é a prova de "notificado sem atualizar
/// a tela"; em `entrega.status_atualizado` que tira a entrega de pendente,
/// re-sincroniza. A volta da conexão também dispara re-sync.
class PendentesController extends ChangeNotifier {
  PendentesController(this._service, this._realtime);

  final EntregaApiService _service;
  final EventosRealtimeService _realtime;

  List<Entrega> _itens = const <Entrega>[];
  List<Entrega> get itens => _itens;

  bool _carregando = false;
  bool get carregando => _carregando;

  String? _erro;
  String? get erro => _erro;

  final StreamController<String> _notificacoes =
      StreamController<String>.broadcast();

  /// Emite uma mensagem quando chega uma NOVA solicitação (para aviso na tela).
  Stream<String> get notificacoes => _notificacoes.stream;

  StreamSubscription<Map<String, dynamic>>? _evSub;
  StreamSubscription<RealtimeStatus>? _stSub;
  bool _emRequisicao = false;
  bool _descartado = false;

  void iniciar() {
    carregar();
    _evSub = _realtime.eventos.listen(_aoEvento);
    // Reconexão → re-sincroniza para não perder mudanças ocorridas offline.
    _stSub = _realtime.status.listen((s) {
      if (s == RealtimeStatus.conectado) {
        _buscar();
      }
    });
  }

  /// Primeira carga (ou retry): mostra spinner enquanto não há dados.
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
      final pendentes = await _service.listar(
        status: StatusEntrega.pendente.valor,
      );
      _itens = pendentes.toList()..sort((a, b) => b.id.compareTo(a.id));
      _erro = null;
    } on ApiException catch (e) {
      if (_itens.isEmpty) {
        _erro = e.message;
      }
    } finally {
      _emRequisicao = false;
      _carregando = false;
      _notificar();
    }
  }

  void _aoEvento(Map<String, dynamic> evento) {
    final tipo = evento['evento'];
    final dados = (evento['dados'] as Map?) ?? const <dynamic, dynamic>{};
    if (tipo == 'entrega.criada') {
      final descricao = (dados['descricao'] as String?)?.trim();
      _notificacoes.add(
        descricao == null || descricao.isEmpty
            ? 'Nova solicitação recebida'
            : 'Nova solicitação: $descricao',
      );
      _buscar(); // re-sincroniza para exibir a nova pendente na hora
    } else if (tipo == 'entrega.status_atualizado') {
      // Saiu de "pendente" (foi aceita/cancelada): refletir na lista.
      if (dados['status_novo'] != StatusEntrega.pendente.valor) {
        _buscar();
      }
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
    _stSub?.cancel();
    _notificacoes.close();
    super.dispose();
  }
}
