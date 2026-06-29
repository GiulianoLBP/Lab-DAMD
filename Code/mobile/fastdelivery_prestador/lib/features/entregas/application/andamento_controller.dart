import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/http/api_exception.dart';
import '../data/entrega_api_service.dart';
import '../data/eventos_realtime_service.dart';
import '../domain/entrega.dart';

/// Controlador do acompanhamento das solicitações EM ANDAMENTO.
///
/// "Em andamento" = entregas que o prestador já aceitou e ainda não finalizou
/// (`aceito` ou `em_transito`). Carga inicial via REST e atualizações ao vivo:
/// qualquer `entrega.status_atualizado` re-sincroniza (uma transição pode entrar
/// ou sair da lista). A volta da conexão também dispara re-sync.
class AndamentoController extends ChangeNotifier {
  AndamentoController(this._service, this._realtime);

  final EntregaApiService _service;
  final EventosRealtimeService _realtime;

  List<Entrega> _itens = const <Entrega>[];
  List<Entrega> get itens => _itens;

  bool _carregando = false;
  bool get carregando => _carregando;

  String? _erro;
  String? get erro => _erro;

  StreamSubscription<Map<String, dynamic>>? _evSub;
  StreamSubscription<RealtimeStatus>? _stSub;
  bool _emRequisicao = false;
  bool _descartado = false;

  void iniciar() {
    carregar();
    _evSub = _realtime.eventos.listen(_aoEvento);
    _stSub = _realtime.status.listen((s) {
      if (s == RealtimeStatus.conectado) {
        _buscar();
      }
    });
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
      // Uma única chamada e filtro local: o prestador vê todas as entregas e
      // mantém em tela apenas as sob sua responsabilidade ativa.
      final todas = await _service.listar();
      _itens =
          todas.where((e) => e.statusEnum?.emAndamento ?? false).toList()
            ..sort((a, b) => b.id.compareTo(a.id));
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
    // Só transições de status mexem no "em andamento"; novas pendentes não.
    if (evento['evento'] == 'entrega.status_atualizado') {
      _buscar();
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
    super.dispose();
  }
}
