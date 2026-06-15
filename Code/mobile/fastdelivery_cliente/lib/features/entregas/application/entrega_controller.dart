import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../../core/http/api_exception.dart';
import '../data/entrega_api_service.dart';
import '../domain/entrega.dart';

/// Controlador da lista de entregas do cliente.
///
/// Mantém estado de carregamento/erro, filtra pelo cliente de demonstração e
/// faz polling REST. Garante que não há requisições sobrepostas
/// ([_emRequisicao]) nem timers duplicados.
class EntregaListController extends ChangeNotifier {
  EntregaListController(
    this._service, {
    this.clienteId = ApiConfig.clienteIdDemo,
    this.intervaloPolling = ApiConfig.intervaloPolling,
  });

  final EntregaApiService _service;
  final String clienteId;
  final Duration intervaloPolling;

  List<Entrega> _entregas = const <Entrega>[];
  List<Entrega> get entregas => _entregas;

  bool _carregando = false;
  bool get carregando => _carregando;

  String? _erro;
  String? get erro => _erro;

  Timer? _timer;
  bool _emRequisicao = false;
  bool _descartado = false;

  /// Primeira carga (ou retry): mostra spinner enquanto não há dados.
  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    _notificar();
    await _buscar();
  }

  /// Liga o polling periódico. Idempotente: nunca cria timers duplicados.
  void iniciarPolling() {
    _timer ??= Timer.periodic(intervaloPolling, (_) => _buscar());
  }

  void pararPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _buscar() async {
    if (_emRequisicao || _descartado) {
      return;
    }
    _emRequisicao = true;
    try {
      final todas = await _service.listar();
      _entregas = todas.where((e) => e.clienteId == clienteId).toList()
        ..sort((a, b) => b.id.compareTo(a.id));
      _erro = null;
    } on ApiException catch (e) {
      // Erro durante o polling com dados já na tela: mantém a lista (discreto).
      if (_entregas.isEmpty) {
        _erro = e.message;
      }
    } finally {
      _emRequisicao = false;
      _carregando = false;
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
    pararPolling();
    super.dispose();
  }
}

/// Controlador da tela de detalhes de uma entrega.
///
/// Faz polling do `GET /entregas/<id>` (reflete mudanças de status sem ação
/// manual) e expõe o cancelamento pelo cliente.
class EntregaDetailController extends ChangeNotifier {
  EntregaDetailController(
    this._service, {
    required this.entregaId,
    this.intervaloPolling = ApiConfig.intervaloPolling,
  });

  final EntregaApiService _service;
  final int entregaId;
  final Duration intervaloPolling;

  Entrega? _entrega;
  Entrega? get entrega => _entrega;

  bool _carregando = false;
  bool get carregando => _carregando;

  String? _erro;
  String? get erro => _erro;

  bool _cancelando = false;
  bool get cancelando => _cancelando;

  String? _avisoPolling;
  String? get avisoPolling => _avisoPolling;

  Timer? _timer;
  bool _emRequisicao = false;
  bool _descartado = false;

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    _notificar();
    await _buscar();
  }

  void iniciarPolling() {
    _timer ??= Timer.periodic(intervaloPolling, (_) => _buscar());
  }

  void pararPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _buscar() async {
    if (_emRequisicao || _descartado) {
      return;
    }
    _emRequisicao = true;
    try {
      _entrega = await _service.buscarPorId(entregaId);
      _erro = null;
      _avisoPolling = null;
    } on ApiException catch (e) {
      // Sem dados ainda: erro de tela cheia. Com dados: aviso discreto.
      if (_entrega == null) {
        _erro = e.message;
      } else {
        _avisoPolling = 'Sem conexão no momento. Tentando novamente...';
      }
    } finally {
      _emRequisicao = false;
      _carregando = false;
      _notificar();
    }
  }

  /// Cancela a entrega (`PATCH status=cancelado`). Retorna `true` em sucesso.
  Future<bool> cancelar() async {
    if (_cancelando) {
      return false;
    }
    _cancelando = true;
    _notificar();
    try {
      _entrega = await _service.cancelar(entregaId);
      _erro = null;
      return true;
    } on ApiException catch (e) {
      _erro = e.message;
      return false;
    } finally {
      _cancelando = false;
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
    pararPolling();
    super.dispose();
  }
}
