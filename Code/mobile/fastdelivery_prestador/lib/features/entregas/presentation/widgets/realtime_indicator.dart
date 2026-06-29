import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/eventos_realtime_service.dart';

/// Indicador compacto do estado da conexão em tempo real ("ao vivo" /
/// "conectando" / "offline"), exibido na AppBar. Deixa visível que a notificação
/// do prestador chega pelo WebSocket — não por atualização manual.
class RealtimeIndicator extends StatefulWidget {
  const RealtimeIndicator({super.key, required this.realtime});

  final EventosRealtimeService realtime;

  @override
  State<RealtimeIndicator> createState() => _RealtimeIndicatorState();
}

class _RealtimeIndicatorState extends State<RealtimeIndicator> {
  RealtimeStatus _status = RealtimeStatus.conectando;
  StreamSubscription<RealtimeStatus>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.realtime.status.listen((s) {
      if (mounted) {
        setState(() => _status = s);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (Color cor, String rotulo) = switch (_status) {
      RealtimeStatus.conectado => (const Color(0xFF34D399), 'ao vivo'),
      RealtimeStatus.conectando => (const Color(0xFFFBBF24), 'conectando'),
      RealtimeStatus.desconectado => (const Color(0xFFF87171), 'offline'),
    };
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(rotulo, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
