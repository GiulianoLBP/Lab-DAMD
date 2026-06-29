import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/api_config.dart';

/// Estado da conexão em tempo real (para a UI sinalizar "ao vivo").
enum RealtimeStatus { conectando, conectado, desconectado }

/// Cliente WebSocket dos eventos do MOM (`/ws/eventos`).
///
/// É o coração da notificação assíncrona do prestador: o backend consome os
/// eventos do RabbitMQ (ponte) e os empurra por este WebSocket, então o app
/// reage SEM polling. Expõe:
///   - [eventos]: stream broadcast dos eventos de domínio (descarta `keepalive`);
///   - [status]: mudanças de conexão — os controllers usam a volta a
///     [RealtimeStatus.conectado] para re-sincronizar via REST (cobre o que
///     possa ter sido perdido enquanto a conexão esteve fora).
///
/// Reconecta sozinho após quedas, com intervalo [intervaloReconexao].
class EventosRealtimeService {
  EventosRealtimeService({
    String? wsUrl,
    this.intervaloReconexao = ApiConfig.intervaloReconexao,
  }) : _wsUrl = wsUrl ?? ApiConfig.wsUrl;

  final String _wsUrl;
  final Duration intervaloReconexao;

  final StreamController<Map<String, dynamic>> _eventos =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<RealtimeStatus> _status =
      StreamController<RealtimeStatus>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconexao;
  bool _ativo = false;

  /// Eventos de domínio recebidos (sem os pacotes de `keepalive`).
  Stream<Map<String, dynamic>> get eventos => _eventos.stream;

  /// Mudanças de estado da conexão (para indicador "ao vivo" e re-sync).
  Stream<RealtimeStatus> get status => _status.stream;

  /// Abre a conexão (idempotente). Mantém-se reconectando até [dispose].
  void conectar() {
    if (_ativo) {
      return;
    }
    _ativo = true;
    _abrir();
  }

  Future<void> _abrir() async {
    _emitirStatus(RealtimeStatus.conectando);
    try {
      final channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      // `ready` confirma o handshake; lança se a conexão falhar.
      await channel.ready;
      _channel = channel;
      _sub = channel.stream.listen(
        _aoReceber,
        onError: (_) => _agendarReconexao(),
        onDone: _agendarReconexao,
        cancelOnError: true,
      );
      _emitirStatus(RealtimeStatus.conectado);
    } catch (_) {
      _agendarReconexao();
    }
  }

  void _aoReceber(dynamic data) {
    if (data is! String) {
      return;
    }
    final dynamic decodificado;
    try {
      decodificado = jsonDecode(data);
    } catch (_) {
      return; // mensagem não-JSON: ignora
    }
    if (decodificado is! Map<String, dynamic>) {
      return;
    }
    if (decodificado['evento'] == 'keepalive') {
      return; // pacote de manutenção da conexão
    }
    _eventos.add(decodificado);
  }

  void _agendarReconexao() {
    _sub?.cancel();
    _sub = null;
    _channel = null;
    if (!_ativo) {
      return;
    }
    _emitirStatus(RealtimeStatus.desconectado);
    _reconexao ??= Timer(intervaloReconexao, () {
      _reconexao = null;
      if (_ativo) {
        _abrir();
      }
    });
  }

  void _emitirStatus(RealtimeStatus s) {
    if (!_status.isClosed) {
      _status.add(s);
    }
  }

  /// Encerra a conexão e libera os recursos.
  Future<void> dispose() async {
    _ativo = false;
    _reconexao?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close(ws_status.normalClosure);
    await _eventos.close();
    await _status.close();
  }
}
